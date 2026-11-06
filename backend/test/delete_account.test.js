const assert = require('node:assert/strict');
const http = require('node:http');
const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { after, before, test } = require('node:test');

process.env.JWT_SECRET = 'test-only-delete-account-secret';

const pool = require('../src/config/database');
const authRouter = require('../src/routes/auth');

const app = express();
app.use(express.json());
app.use('/api/auth', authRouter);

let server;
let baseUrl;
let originalConnect;

before(async () => {
  originalConnect = pool.connect;
  server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}/api/auth/account`;
});

after(async () => {
  pool.connect = originalConnect;
  if (server) await new Promise((resolve) => server.close(resolve));
  await pool.end();
});

function installClient({ userRow = null } = {}) {
  const queries = [];
  const fake = {
    released: false,
    async query(sql, values) {
      queries.push({
        sql: String(sql).replace(/\s+/g, ' ').trim(),
        values,
      });
      if (/SELECT id, role, password_hash/.test(sql)) {
        return { rows: userRow ? [userRow] : [] };
      }
      return { rows: [] };
    },
    release() {
      fake.released = true;
    },
  };
  pool.connect = async () => fake;
  return { fake, queries };
}

function tokenFor(userId = 7, role = 'client') {
  return jwt.sign({ userId, role }, process.env.JWT_SECRET);
}

function deleteAccount(token, body = {}) {
  return fetch(baseUrl, {
    method: 'DELETE',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });
}

async function passwordHash(password) {
  return bcrypt.hash(password, 4);
}

test('la suppression exige une session', async () => {
  const response = await deleteAccount(null, { password: 'X' });
  assert.equal(response.status, 401);
});

test('le compte administrateur ne peut pas être supprimé depuis l’application', async () => {
  const { queries } = installClient({
    userRow: { id: 1, role: 'admin', password_hash: await passwordHash('secret') },
  });

  const response = await deleteAccount(tokenFor(1, 'admin'), {
    password: 'secret',
  });

  assert.equal(response.status, 403);
  assert.equal(queries.at(-1).sql, 'ROLLBACK');
});

test('un mot de passe incorrect annule la transaction', async () => {
  const { queries } = installClient({
    userRow: {
      id: 7,
      role: 'client',
      password_hash: await passwordHash('1234AZER'),
    },
  });

  const response = await deleteAccount(tokenFor(7), { password: 'MAUVAIS' });
  const payload = await response.json();

  assert.equal(response.status, 401);
  assert.equal(payload.code, 'INVALID_PASSWORD');
  assert.equal(
    queries.some((entry) => entry.sql.startsWith('UPDATE users')),
    false,
  );
  assert.equal(queries.at(-1).sql, 'ROLLBACK');
});

test('anonymise le compte et efface les contenus personnels', async () => {
  const { fake, queries } = installClient({
    userRow: {
      id: 7,
      role: 'client',
      password_hash: await passwordHash('1234AZER'),
    },
  });

  const response = await deleteAccount(tokenFor(7), { password: '1234AZER' });
  const payload = await response.json();

  assert.equal(response.status, 200);
  assert.equal(payload.success, true);

  const sql = queries.map((entry) => entry.sql);
  assert.ok(sql.some((entry) => entry.startsWith('DELETE FROM profile_support_messages')));
  assert.ok(sql.some((entry) => entry.startsWith('DELETE FROM profile_training_interests')));
  assert.ok(sql.some((entry) => entry.startsWith('DELETE FROM profile_app_ratings')));
  assert.ok(sql.some((entry) => entry.startsWith('DELETE FROM password_reset_codes')));
  assert.ok(sql.some((entry) => entry.startsWith('DELETE FROM clients')));

  const devis = queries.find((entry) => entry.sql.startsWith('UPDATE devis'));
  assert.ok(devis);
  assert.deepEqual(devis.values, [7]);

  const users = queries.find((entry) => entry.sql.startsWith('UPDATE users'));
  assert.ok(users);
  assert.equal(users.values[0], 7);
  assert.equal(users.values[1], 'supprime+7@echelle-eg39.invalid');
  assert.equal(users.values[2], '+000007');
  assert.match(users.values[3], /^\$2[aby]\$/);
  assert.equal(await bcrypt.compare('1234AZER', users.values[3]), false);

  assert.equal(sql.at(-1), 'COMMIT');
  assert.equal(fake.released, true);
});

test('une session qui ne correspond à aucun compte renvoie 404', async () => {
  const { queries } = installClient({ userRow: null });

  const response = await deleteAccount(tokenFor(99), { password: '1234AZER' });

  assert.equal(response.status, 404);
  assert.equal(queries.at(-1).sql, 'ROLLBACK');
});
