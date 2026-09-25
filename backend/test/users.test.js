const assert = require('node:assert/strict');
const http = require('node:http');
const express = require('express');
const jwt = require('jsonwebtoken');
const { after, before, test } = require('node:test');

process.env.JWT_SECRET = 'test-only-user-directory-secret';

const pool = require('../src/config/database');
const clientsRouter = require('../src/routes/admin_clients');

const app = express();
app.use('/api/users/clients', clientsRouter);
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

function tokenFor(role) {
  return jwt.sign({ userId: 1, role }, process.env.JWT_SECRET);
}

test('la route clients refuse les requêtes sans session', async () => {
  const response = await fetch(baseUrl);
  assert.equal(response.status, 401);
});

test('la route clients est réservée aux administrateurs', async () => {
  const response = await fetch(baseUrl, {
    headers: { Authorization: `Bearer ${tokenFor('client')}` },
  });
  assert.equal(response.status, 403);
});

test('la route admin renvoie les coordonnées clients sans données secrètes', async () => {
  pool.query = async (query) => {
    assert.match(query, /WHERE role <> 'admin'/);
    assert.match(query, /first_name, last_name, email, phone, role, created_at/);
    return {
      rows: [
        {
          id: 7,
          first_name: 'Afi',
          last_name: 'Koffi',
          email: 'afi@example.com',
          phone: '+22890000000',
          role: 'client',
          created_at: '2026-09-25T10:00:00.000Z',
        },
      ],
    };
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
      },
    ],
  });
});
