const assert = require('node:assert/strict');
const http = require('node:http');
const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { after, before, test } = require('node:test');

process.env.JWT_SECRET = 'test-engine-only-recovery-secret';

const pool = require('../src/config/database');
const authRouter = require('../src/routes/auth');
const adminClientsRouter = require('../src/routes/admin_clients');
const {
  generateTemporaryPassword,
  isTemporaryPasswordFormat,
} = require('../src/utils/temporary_password');
const {
  generateRecoveryCode,
  hashRecoveryCode,
  matchesRecoveryCodeHash,
  normalizeRecoveryCode,
} = require('../src/utils/recovery_code');
const { verifierMotDePasse } = require('../src/utils/password_hash');

const authApp = express();
authApp.use(express.json());
authApp.use('/api/auth', authRouter);

const adminApp = express();
adminApp.use(express.json());
adminApp.use('/api/users/clients', adminClientsRouter);

let authServer;
let adminServer;
let authUrl;
let adminUrl;
let originalQuery;

function listen(app) {
  const server = http.createServer(app);
  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => {
      resolve({ server, url: `http://127.0.0.1:${server.address().port}` });
    });
  });
}

before(async () => {
  originalQuery = pool.query;
  const auth = await listen(authApp);
  const admin = await listen(adminApp);
  authServer = auth.server;
  authUrl = `${auth.url}/api/auth`;
  adminServer = admin.server;
  adminUrl = `${admin.url}/api/users/clients`;
});

after(async () => {
  pool.query = originalQuery;
  await new Promise((resolve) => authServer.close(resolve));
  await new Promise((resolve) => adminServer.close(resolve));
  await pool.end();
});

function post(url, body, token) {
  return fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });
}

function adminToken() {
  return jwt.sign({ userId: 1, role: 'admin' }, process.env.JWT_SECRET);
}

test('le mot de passe temporaire suit la règle de l’application', () => {
  const values = new Set();
  for (let index = 0; index < 50; index += 1) {
    const password = generateTemporaryPassword();
    assert.equal(isTemporaryPasswordFormat(password), true, password);
    values.add(password);
  }
  assert.ok(values.size > 40);
});

test('le code de récupération est lisible, normalisable et haché', () => {
  const code = generateRecoveryCode();
  assert.match(code, /^EG39-[A-Z2-9]{4}-[A-Z2-9]{4}$/);

  const canonical = normalizeRecoveryCode(code);
  assert.equal(canonical.length, 8);
  // Recopié au téléphone : « eg39 abcd efgh » reste accepté.
  assert.equal(normalizeRecoveryCode(` ${code.toLowerCase()} `), canonical);
  assert.equal(
    normalizeRecoveryCode(`${canonical.slice(0, 4)} ${canonical.slice(4)}`),
    canonical,
  );

  const hash = hashRecoveryCode(code);
  assert.equal(hash.length, 64);
  assert.equal(matchesRecoveryCodeHash(code, hash), true);
  assert.equal(matchesRecoveryCodeHash(generateRecoveryCode(), hash), false);
  assert.equal(matchesRecoveryCodeHash('ABC', hash), false);
  assert.equal(matchesRecoveryCodeHash(code, null), false);
});

test('l’inscription renvoie le code de récupération et n’en garde que l’empreinte', async () => {
  let storedHash = null;

  pool.query = async (query, params) => {
    if (/LOWER\(email\) = \$1/.test(query)) {
      return { rows: [] };
    }
    if (/phone = ANY\(\$1::text\[\]\)/.test(query)) {
      return { rows: [] };
    }
    if (/INSERT INTO users/.test(query)) {
      storedHash = params[4];
      assert.match(query, /recovery_code_hash/);
      return {
        rows: [
          {
            id: 9,
            first_name: params[0],
            last_name: params[1],
            email: null,
            phone: null,
            role: 'client',
            created_at: '2026-11-07T00:00:00.000Z',
          },
        ],
      };
    }
    throw new Error(`Requête inattendue : ${query}`);
  };

  const response = await post(`${authUrl}/register`, {
    firstName: 'Afi',
    lastName: 'Koffi',
    email: 'afi@example.com',
    phone: '+22890000000',
    password: 'Chantier#2026',
  });
  const payload = await response.json();

  assert.equal(response.status, 201);
  assert.match(payload.recoveryCode, /^EG39-[A-Z2-9]{4}-[A-Z2-9]{4}$/);
  assert.equal(storedHash, hashRecoveryCode(payload.recoveryCode));
  // Le code en clair ne doit jamais être stocké.
  assert.notEqual(storedHash, payload.recoveryCode);
});

test('la récupération exige le code remis à l’inscription', async () => {
  const recoveryCode = 'ABCD2345';
  let storedHash = null;

  pool.query = async (query, params) => {
    if (/SELECT id, recovery_code_hash/.test(query)) {
      return {
        rows: [
          {
            id: 7,
            email: 'afi@example.com',
            phone: '+22890000000',
            recovery_code_hash: hashRecoveryCode(recoveryCode),
          },
        ],
      };
    }
    if (/UPDATE users[\s\S]*must_change_password = TRUE/.test(query)) {
      storedHash = params[0];
      return { rows: [] };
    }
    throw new Error(`Requête inattendue : ${query}`);
  };

  const response = await post(`${authUrl}/forgot-password`, {
    contact: 'afi@example.com',
    contactType: 'email',
    recoveryCode: 'eg39-abcd-2345',
  });
  const payload = await response.json();

  assert.equal(response.status, 200);
  assert.match(payload.temporaryPassword, /^\d{4}[A-Z]{4}$/);
  assert.equal(payload.displaySeconds, 120);
  assert.ok(payload.tempToken);
  // Le mot de passe temporaire est haché au format courant, jamais stocké en
  // clair : il doit être vérifiable mais rester court (affiché 2 minutes).
  assert.equal(
    await verifierMotDePasse(payload.temporaryPassword, storedHash),
    true,
  );
  assert.notEqual(storedHash, payload.temporaryPassword);
});

test('un code erroné est refusé sans toucher au mot de passe', async () => {
  let passwordUpdated = false;

  pool.query = async (query) => {
    if (/SELECT id, recovery_code_hash/.test(query)) {
      return {
        rows: [
          {
            id: 7,
            email: 'afi@example.com',
            phone: '+22890000000',
            recovery_code_hash: hashRecoveryCode('ZZZZ9999'),
          },
        ],
      };
    }
    if (/UPDATE users/.test(query)) {
      passwordUpdated = true;
      return { rows: [] };
    }
    throw new Error(`Requête inattendue : ${query}`);
  };

  const response = await post(`${authUrl}/forgot-password`, {
    contact: 'afi@example.com',
    contactType: 'email',
    recoveryCode: 'ABCD2345',
  });
  const payload = await response.json();

  assert.equal(response.status, 400);
  assert.equal(payload.code, 'RECOVERY_DENIED');
  assert.equal(payload.error, 'Identifiant ou code de récupération incorrect.');
  assert.equal(passwordUpdated, false);
});

test('un compte inconnu reçoit le même refus qu’un code faux', async () => {
  pool.query = async () => ({ rows: [] });

  const response = await post(`${authUrl}/forgot-password`, {
    contact: 'inconnu@example.com',
    contactType: 'email',
    recoveryCode: 'ABCD2345',
  });
  const payload = await response.json();

  assert.equal(response.status, 400);
  assert.equal(payload.error, 'Identifiant ou code de récupération incorrect.');
});

test('un code incomplet est refusé avant toute recherche', async () => {
  pool.query = async () => {
    throw new Error('La base ne doit pas être interrogée');
  };

  const response = await post(`${authUrl}/forgot-password`, {
    contact: 'afi@example.com',
    contactType: 'email',
    recoveryCode: 'ABCD',
  });
  const payload = await response.json();

  assert.equal(response.status, 400);
  assert.equal(payload.code, 'RECOVERY_CODE_INVALID');
});

test('six essais erronés bloquent temporairement les suivants', async () => {
  pool.query = async () => ({
    rows: [
      {
        id: 8,
        email: 'brute@example.com',
        phone: '+22890000008',
        recovery_code_hash: hashRecoveryCode('ZZZZ9999'),
      },
    ],
  });

  for (let attempt = 0; attempt < 6; attempt += 1) {
    const response = await post(`${authUrl}/forgot-password`, {
      contact: 'brute@example.com',
      contactType: 'email',
      recoveryCode: 'ABCD2345',
    });
    assert.equal(response.status, 400);
  }

  const blocked = await post(`${authUrl}/forgot-password`, {
    contact: 'brute@example.com',
    contactType: 'email',
    recoveryCode: 'ABCD2345',
  });
  const payload = await blocked.json();

  assert.equal(blocked.status, 429);
  assert.equal(payload.code, 'TOO_MANY_ATTEMPTS');
});

test('l’ancienne étape par e-mail ou SMS répond 410', async () => {
  const response = await post(`${authUrl}/verify-code`, {
    code: '123456',
    contact: 'afi@example.com',
  });
  const payload = await response.json();

  assert.equal(response.status, 410);
  assert.equal(payload.code, 'CODE_CHANNEL_REMOVED');
});

test('la connexion signale qu’un mot de passe temporaire doit être remplacé', async () => {
  const hash = await bcrypt.hash('4821KLMN', 4);

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

  const response = await post(`${authUrl}/login`, {
    identifier: 'afi@example.com',
    password: '4821KLMN',
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
    // Identité lue pour vérifier que le mot de passe ne reprend pas le nom,
    // l'e-mail ou le téléphone du titulaire.
    if (/SELECT first_name, last_name, email, phone,/.test(query)) {
      return {
        rows: [
          {
            first_name: 'Afi',
            last_name: 'Koffi',
            email: 'afi@example.com',
            phone: '+22890000000',
          },
        ],
      };
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
    (await post(`${authUrl}/change-temporary-password`, { newPassword: '1234AZER' }))
      .status,
    401,
  );

  const response = await post(
    `${authUrl}/change-temporary-password`,
    { newPassword: 'Chantier#2026' },
    token,
  );

  assert.equal(response.status, 200);
  assert.equal(clearedFlag, true);
  assert.equal(await verifierMotDePasse('Chantier#2026', storedHash), true);
});

test('un mot de passe trop facile à deviner est refusé', async () => {
  pool.query = async (query) => {
    if (/SELECT id, must_change_password FROM users/.test(query)) {
      return { rows: [{ id: 7, must_change_password: true }] };
    }
    if (/SELECT first_name, last_name, email, phone,/.test(query)) {
      return {
        rows: [
          {
            first_name: 'Afi',
            last_name: 'Koffi',
            email: 'afi@example.com',
            phone: '+22890000000',
          },
        ],
      };
    }
    throw new Error(`Requête inattendue : ${query}`);
  };

  const token = jwt.sign({ userId: 7, role: 'client' }, process.env.JWT_SECRET);
  const response = await post(
    `${authUrl}/change-temporary-password`,
    { newPassword: 'azerty1234' },
    token,
  );
  const payload = await response.json();

  assert.equal(response.status, 400);
  assert.equal(payload.code, 'PASSWORD_TOO_WEAK');
  assert.match(payload.rules, /10 caractères minimum/);
});

test('aucun mot de passe temporaire à remplacer renvoie 409', async () => {
  pool.query = async () => ({
    rows: [{ id: 7, must_change_password: false }],
  });

  const token = jwt.sign({ userId: 7, role: 'client' }, process.env.JWT_SECRET);
  const response = await post(
    `${authUrl}/change-temporary-password`,
    { newPassword: '1234AZER' },
    token,
  );

  assert.equal(response.status, 409);
});

test('choisir soi-même son mot de passe lève aussi le drapeau', async () => {
  let clearedFlag = false;

  pool.query = async (query) => {
    if (/SELECT first_name, last_name, email, phone,/.test(query)) {
      return {
        rows: [
          {
            first_name: 'Afi',
            last_name: 'Koffi',
            email: 'afi@example.com',
            phone: '+22890000000',
          },
        ],
      };
    }
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

  const response = await post(`${authUrl}/reset-password`, {
    tempToken,
    newPassword: 'Chantier#2026',
  });

  assert.equal(response.status, 200);
  assert.equal(clearedFlag, true);
});

test('l’administration régénère un code de récupération', async () => {
  let storedHash = null;

  pool.query = async (query, params) => {
    if (/UPDATE users[\s\S]*recovery_code_hash = \$1/.test(query)) {
      storedHash = params[0];
      return {
        rows: [
          {
            id: 7,
            first_name: 'Afi',
            last_name: 'Koffi',
            phone: '+22890000000',
            email: 'afi@example.com',
          },
        ],
      };
    }
    throw new Error(`Requête inattendue : ${query}`);
  };

  assert.equal((await post(`${adminUrl}/7/recovery-code`)).status, 401);

  const response = await post(`${adminUrl}/7/recovery-code`, {}, adminToken());
  const payload = await response.json();

  assert.equal(response.status, 200);
  assert.match(payload.recoveryCode, /^EG39-[A-Z2-9]{4}-[A-Z2-9]{4}$/);
  assert.equal(storedHash, hashRecoveryCode(payload.recoveryCode));
  assert.equal(payload.client.id, 7);
});
