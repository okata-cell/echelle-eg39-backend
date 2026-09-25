const assert = require('node:assert/strict');
const http = require('node:http');
const express = require('express');
const jwt = require('jsonwebtoken');
const { after, before, test } = require('node:test');

process.env.JWT_SECRET = 'test-only-user-directory-secret';

const pool = require('../src/config/database');
const clientsRouter = require('../src/routes/admin_clients');
const authRouter = require('../src/routes/auth');
const { authMiddleware } = require('../src/middleware/auth');

const app = express();
app.use(express.json());
app.use('/api/users/clients', clientsRouter);
app.use('/api/auth', authRouter);
app.get('/protected', authMiddleware, (req, res) => res.sendStatus(204));
let server;
let originalQuery;
let baseUrl;

before(async () => {
  originalQuery = pool.query;
  server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}/api/users/clients`;
});

after(async () => {
  pool.query = originalQuery;
  if (server) await new Promise((resolve) => server.close(resolve));
  await pool.end();
});

function tokenFor(role, userId = 1) {
  return jwt.sign({ userId, role }, process.env.JWT_SECRET);
}

function clientRow(overrides = {}) {
  return {
    id: 7,
    first_name: 'Afi',
    last_name: 'Koffi',
    email: 'afi@example.com',
    phone: '+22890000000',
    role: 'client',
    created_at: '2026-09-25T10:00:00.000Z',
    is_active: true,
    ...overrides,
  };
}

test('la route clients refuse les requêtes sans session', async () => {
  const response = await fetch(baseUrl);
  assert.equal(response.status, 401);
});

test('la route clients est réservée aux administrateurs', async () => {
  pool.query = async () => ({ rows: [{ is_active: true }] });
  const response = await fetch(baseUrl, {
    headers: { Authorization: `Bearer ${tokenFor('client')}` },
  });
  assert.equal(response.status, 403);
});

test('la route admin renvoie le statut sans données secrètes', async () => {
  pool.query = async (query) => {
    assert.match(query, /WHERE role <> 'admin'/);
    assert.match(query, /first_name, last_name, email, phone, role, created_at, is_active/);
    return { rows: [clientRow()] };
  };

  const response = await fetch(baseUrl, {
    headers: { Authorization: `Bearer ${tokenFor('admin')}` },
  });
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('cache-control'), 'no-store');
  assert.deepEqual(await response.json(), {
    clients: [
      {
        id: 7,
        firstName: 'Afi',
        lastName: 'Koffi',
        email: 'afi@example.com',
        phone: '+22890000000',
        role: 'client',
        createdAt: '2026-09-25T10:00:00.000Z',
        isActive: true,
      },
    ],
  });
});

test('un admin peut modifier les coordonnées sans changer le rôle', async () => {
  pool.query = async (query, values) => {
    if (query.includes('SELECT id FROM users')) return { rows: [] };
    assert.match(query, /WHERE id = \$5 AND role <> 'admin'/);
    assert.deepEqual(values, [
      'Afi Marie',
      'Koffi',
      'afi.marie@example.com',
      '+22890000001',
      7,
    ]);
    return {
      rows: [
        clientRow({
          first_name: values[0],
          last_name: values[1],
          email: values[2],
          phone: values[3],
        }),
      ],
    };
  };

  const response = await fetch(`${baseUrl}/7`, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${tokenFor('admin')}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      firstName: ' Afi Marie ',
      lastName: ' Koffi ',
      email: 'afi.marie@example.com',
      phone: '+22890000001',
      role: 'admin',
    }),
  });
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.client.firstName, 'Afi Marie');
  assert.equal(body.client.role, 'client');
});

test('la modification refuse un e-mail déjà utilisé', async () => {
  pool.query = async () => ({ rows: [{ id: 8 }] });
  const response = await fetch(`${baseUrl}/7`, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${tokenFor('admin')}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      firstName: 'Afi',
      lastName: 'Koffi',
      email: 'other@example.com',
      phone: '+22890000001',
    }),
  });
  assert.equal(response.status, 409);
});

test('la désactivation conserve le compte et renvoie son statut', async () => {
  pool.query = async (query, values) => {
    assert.match(query, /SET is_active = \$1/);
    assert.match(query, /WHERE id = \$2 AND role <> 'admin'/);
    assert.deepEqual(values, [false, 7]);
    return { rows: [clientRow({ is_active: false })] };
  };

  const response = await fetch(`${baseUrl}/7/status`, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${tokenFor('admin')}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ isActive: false }),
  });
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.client.isActive, false);
});

test('un statut invalide et un identifiant invalide sont rejetés', async () => {
  pool.query = async () => {
    throw new Error('La base ne doit pas être appelée');
  };
  const invalidStatus = await fetch(`${baseUrl}/7/status`, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${tokenFor('admin')}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ isActive: 'false' }),
  });
  assert.equal(invalidStatus.status, 400);

  const invalidId = await fetch(`${baseUrl}/bad/status`, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${tokenFor('admin')}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ isActive: false }),
  });
  assert.equal(invalidId.status, 400);
});

test('un client désactivé ne peut plus utiliser une session existante', async () => {
  pool.query = async () => ({ rows: [{ is_active: false }] });
  const response = await fetch(
    `http://127.0.0.1:${server.address().port}/protected`,
    { headers: { Authorization: `Bearer ${tokenFor('client')}` } },
  );
  assert.equal(response.status, 401);
});

test('un client désactivé ne peut pas se reconnecter', async () => {
  pool.query = async () => ({
    rows: [
      {
        ...clientRow({ is_active: false }),
        password_hash: '$2a$10$not-a-real-password-hash',
      },
    ],
  });
  const response = await fetch(
    `http://127.0.0.1:${server.address().port}/api/auth/login`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        identifier: 'afi@example.com',
        password: 'Password123',
      }),
    },
  );
  assert.equal(response.status, 403);
});
