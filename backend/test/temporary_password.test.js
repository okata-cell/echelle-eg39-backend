const assert = require('node:assert/strict');
const http = require('node:http');
const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { after, before, test } = require('node:test');

process.env.JWT_SECRET = 'test-engine-only-temporary-password-secret';

const pool = require('../src/config/database');
const authRouter = require('../src/routes/auth');
const {
  generateTemporaryPassword,
  isTemporaryPasswordFormat,
} = require('../src/utils/temporary_password');

const app = express();
app.use(express.json());
app.use('/api/auth', authRouter);

let server;
let baseUrl;
let originalQuery;

before(async () => {
  originalQuery = pool.query;
  server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}/api/auth`;
});

after(async () => {
  pool.query = originalQuery;
  if (server) await new Promise((resolve) => server.close(resolve));
  await pool.end();
});

function post(path, body, token) {
  return fetch(`${baseUrl}${path}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });
}

test('le mot de passe généré suit la règle de l’application', () => {
  const values = new Set();
  for (let index = 0; index < 50; index += 1) {
    const password = generateTemporaryPassword();
    assert.equal(isTemporaryPasswordFormat(password), true, password);
    assert.match(password, /^\d{4}[A-Z]{4}$/);
    values.add(password);
  }
  // 50 tirages ne doivent pas produire une seule valeur répétée en boucle.
  assert.ok(values.size > 40);
});

test('la vérification du code crée un mot de passe temporaire haché', async () => {
  let storedHash = null;

  pool.query = async (query, params) => {
    if (/FROM password_reset_codes prc/.test(query)) {
      return { rows: [{ id: 5, user_id: 7 }] };
    }
    if (/UPDATE password_reset_codes SET used = TRUE/.test(query)) {
      return { rows: [] };
    }
    if (/UPDATE users[\s\S]*must_change_password = TRUE/.test(query)) {
      storedHash = params[0];
      return { rows: [] };
    }
    throw new Error(`Requête inattendue : ${query}`);
  };

  const response = await post('/verify-code', {
    code: '123456',
    contact: 'afi@example.com',
  });
  const payload = await response.json();

  assert.equal(response.status, 200);
  assert.match(payload.temporaryPassword, /^\d{4}[A-Z]{4}$/);
  assert.equal(payload.displaySeconds, 120);
  assert.ok(payload.tempToken);

  // Le mot de passe n'est stocké que sous forme de hachage.
  assert.notEqual(storedHash, payload.temporaryPassword);
  assert.equal(
    await bcrypt.compare(payload.temporaryPassword, storedHash),
    true,
  );
});

test('la connexion signale qu’un mot de passe temporaire doit être remplacé', async () => {
  const temporaryPassword = '4821KLMN';
  const hash = await bcrypt.hash(temporaryPassword, 4);

  pool.query = async () => ({
    rows: [
      {
        id: 7,
        first_name: 'Afi',
        last_name: 'Koffi',
        email: 'afi@example.com',
        phone: '+22890000000',
        role: 'client',
        password_hash: hash,
        deleted_at: null,
        must_change_password: true,
      },
    ],
  });

  const response = await post('/login', {
    identifier: 'afi@example.com',
    password: temporaryPassword,
  });
  const payload = await response.json();

  assert.equal(response.status, 200);
  assert.equal(payload.user.mustChangePassword, true);
});

test('le changement obligatoire remplace le mot de passe et lève le drapeau', async () => {
  let storedHash = null;
  let clearedFlag = false;

  pool.query = async (query, params) => {
    if (/SELECT id, must_change_password FROM users/.test(query)) {
      return { rows: [{ id: 7, must_change_password: true }] };
    }
    if (/UPDATE users[\s\S]*must_change_password = FALSE/.test(query)) {
      storedHash = params[0];
      clearedFlag = true;
      return { rows: [] };
    }
    throw new Error(`Requête inattendue : ${query}`);
  };

  const token = jwt.sign({ userId: 7, role: 'client' }, process.env.JWT_SECRET);

  assert.equal(
    (await post('/change-temporary-password', { newPassword: '1234AZER' }))
      .status,
    401,
  );

  const response = await post(
    '/change-temporary-password',
    { newPassword: '5678QWER' },
    token,
  );
  const payload = await response.json();

  assert.equal(response.status, 200);
  assert.equal(payload.success, true);
  assert.equal(clearedFlag, true);
  assert.equal(await bcrypt.compare('5678QWER', storedHash), true);
});

test('aucun mot de passe temporaire à remplacer renvoie 409', async () => {
  pool.query = async () => ({
    rows: [{ id: 7, must_change_password: false }],
  });

  const token = jwt.sign({ userId: 7, role: 'client' }, process.env.JWT_SECRET);
  const response = await post(
    '/change-temporary-password',
    { newPassword: '1234AZER' },
    token,
  );
  const payload = await response.json();

  assert.equal(response.status, 409);
  assert.equal(payload.code, 'NO_TEMPORARY_PASSWORD');
});

test('choisir soi-même son mot de passe lève aussi le drapeau', async () => {
  let clearedFlag = false;

  pool.query = async (query) => {
    if (/UPDATE users[\s\S]*must_change_password = FALSE/.test(query)) {
      clearedFlag = true;
      return { rows: [{ id: 7 }] };
    }
    if (/DELETE FROM password_reset_codes/.test(query)) return { rows: [] };
    throw new Error(`Requête inattendue : ${query}`);
  };

  const tempToken = jwt.sign(
    { userId: 7, type: 'password_reset' },
    process.env.JWT_SECRET,
  );

  const response = await post('/reset-password', {
    tempToken,
    newPassword: '5678QWER',
  });

  assert.equal(response.status, 200);
  assert.equal(clearedFlag, true);
});
