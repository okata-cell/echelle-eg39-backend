const assert = require('node:assert/strict');
const http = require('node:http');
const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { after, before, test } = require('node:test');

process.env.JWT_SECRET = 'test-only-delete-secret';

const pool = require('../src/config/database');
const authRouter = require('../src/routes/auth');

const app = express();
app.use(express.json({ limit: '4mb' }));
app.use('/api/auth', authRouter);

let server;
let originalQuery;
let originalConnect;
let baseUrl;

before(async () => {
  originalQuery = pool.query;
  originalConnect = pool.connect;
  server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}/api/auth`;
});

after(async () => {
  pool.query = originalQuery;
  pool.connect = originalConnect;
  if (server) await new Promise((resolve) => server.close(resolve));
  await pool.end();
});

function tokenFor(role = 'client', userId = 42) {
  return jwt.sign({ userId, role }, process.env.JWT_SECRET);
}

function request({ token = tokenFor(), body } = {}) {
  return fetch(`${baseUrl}/account`, {
    method: 'DELETE',
    headers: {
      ...(body ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
}

function fakeTransactionClient(handler) {
  const calls = [];
  return {
    calls,
    client: {
      async query(query, params = []) {
        calls.push({ query: query.trim(), params });
        return handler(query, params);
      },
      release() {},
    },
  };
}

test('la suppression de compte exige une session', async () => {
  const response = await request({ token: null, body: { password: 'Current123' } });
  assert.equal(response.status, 401);
});

test('un mot de passe incorrect n’efface rien', async () => {
  const passwordHash = await bcrypt.hash('Current123', 4);
  const fake = fakeTransactionClient((query) => {
    if (/^(BEGIN|ROLLBACK|COMMIT)$/.test(query.trim())) return { rows: [] };
    if (/SELECT id, role, password_hash FROM users/.test(query)) {
      return { rows: [{ id: 42, role: 'client', password_hash: passwordHash }] };
    }
    throw new Error(`Aucune écriture attendue: ${query}`);
  });
  pool.connect = async () => fake.client;

  const response = await request({ body: { password: 'Mauvais123' } });
  const body = await response.json();

  assert.equal(response.status, 401);
  assert.equal(body.code, 'INVALID_PASSWORD');
  assert.equal(fake.calls.some((call) => /^(DELETE|UPDATE)/.test(call.query)), false);
});

test('le compte administrateur ne peut pas être supprimé depuis l’application', async () => {
  const passwordHash = await bcrypt.hash('Admin123', 4);
  const fake = fakeTransactionClient((query) => {
    if (/^(BEGIN|ROLLBACK|COMMIT)$/.test(query.trim())) return { rows: [] };
    if (/SELECT id, role, password_hash FROM users/.test(query)) {
      return { rows: [{ id: 1, role: 'admin', password_hash: passwordHash }] };
    }
    throw new Error(`Aucune écriture attendue: ${query}`);
  });
  pool.connect = async () => fake.client;

  const response = await request({ token: tokenFor('admin', 1), body: { password: 'Admin123' } });
  const body = await response.json();

  assert.equal(response.status, 403);
  assert.match(body.error, /administrateur/);
});

test('la suppression efface les contenus personnels et anonymise le compte', async () => {
  const passwordHash = await bcrypt.hash('Current123', 4);
  const fake = fakeTransactionClient((query) => {
    if (/^(BEGIN|COMMIT|ROLLBACK)$/.test(query.trim())) return { rows: [] };
    if (/SELECT id, role, password_hash FROM users/.test(query)) {
      return { rows: [{ id: 42, role: 'client', password_hash: passwordHash }] };
    }
    return { rows: [] };
  });
  pool.connect = async () => fake.client;

  const response = await request({ body: { password: 'Current123' } });
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.success, true);

  const statements = fake.calls.map((call) => call.query.replace(/\s+/g, ' '));

  // Les contenus propres au compte disparaissent réellement.
  for (const table of [
    'profile_support_messages',
    'profile_training_interests',
    'profile_app_ratings',
    'password_reset_codes',
    'clients',
  ]) {
    assert.ok(
      statements.some((query) => query === `DELETE FROM ${table} WHERE user_id = $1`),
      `effacement de ${table} attendu`,
    );
  }

  // Les devis restent, mais sans les coordonnées du titulaire.
  const devisUpdate = fake.calls.find((call) => call.query.startsWith('UPDATE devis'));
  assert.ok(devisUpdate, 'les devis doivent être anonymisés');
  assert.match(devisUpdate.query, /telephone = NULL/);
  assert.match(devisUpdate.query, /email = NULL/);

  // Le compte devient neutre et le mot de passe inutilisable.
  const userUpdate = fake.calls.find((call) => call.query.startsWith('UPDATE users'));
  assert.ok(userUpdate, 'le compte doit être anonymisé');
  assert.match(userUpdate.query, /is_active = FALSE/);
  assert.match(userUpdate.query, /avatar_data = NULL/);
  assert.equal(userUpdate.params[0], 42);
  assert.equal(userUpdate.params[1], 'supprime+42@echelle-eg39.invalid');
  assert.equal(userUpdate.params[2], '+0000042');

  assert.equal(statements[0], 'BEGIN');
  assert.equal(statements[statements.length - 1], 'COMMIT');
});
