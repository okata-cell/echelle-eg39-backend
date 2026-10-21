const assert = require('node:assert/strict');
const http = require('node:http');
const express = require('express');
const jwt = require('jsonwebtoken');
const { after, before, test } = require('node:test');

process.env.JWT_SECRET = 'test-only-purchase-request-secret';

const pool = require('../src/config/database');
const demandesRouter = require('../src/routes/demandes');

const app = express();
app.use(express.json());
app.use('/api/demandes', demandesRouter);

let server;
let originalQuery;
let baseUrl;

before(async () => {
  originalQuery = pool.query;
  server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}/api/demandes`;
});

after(async () => {
  pool.query = originalQuery;
  if (server) await new Promise((resolve) => server.close(resolve));
  await pool.end();
});

function tokenFor(role, userId = 42) {
  return jwt.sign({ userId, role }, process.env.JWT_SECRET);
}

function deleteDemande(id, token) {
  return fetch(`${baseUrl}/${id}`, {
    method: 'DELETE',
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
}

test('un administrateur peut supprimer une demande approuvée', async () => {
  let deleted = false;
  pool.query = async (query, params) => {
    if (/SELECT id, user_id, statut/.test(query)) {
      assert.deepEqual(params, ['91']);
      return { rows: [{ id: 91, user_id: 42, statut: 'approuvee' }] };
    }
    if (/DELETE FROM demandes_achat/.test(query)) {
      deleted = true;
      assert.deepEqual(params, ['91']);
      return { rows: [] };
    }
    throw new Error(`Requête inattendue: ${query}`);
  };

  const response = await deleteDemande(91, tokenFor('admin', 7));
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.message, 'Demande supprimée');
  assert.equal(deleted, true);
});

test('un client ne peut pas supprimer sa demande approuvée', async () => {
  let deleted = false;
  pool.query = async (query) => {
    if (/SELECT id, user_id, statut/.test(query)) {
      return { rows: [{ id: 91, user_id: 42, statut: 'approuvee' }] };
    }
    if (/DELETE FROM demandes_achat/.test(query)) deleted = true;
    throw new Error('Une demande approuvée ne doit pas être supprimée par un client');
  };

  const response = await deleteDemande(91, tokenFor('client', 42));
  const body = await response.json();

  assert.equal(response.status, 400);
  assert.match(body.error, /Impossible de supprimer/);
  assert.equal(deleted, false);
});

test('un administrateur ne peut pas supprimer une demande en attente', async () => {
  let deleted = false;
  pool.query = async (query) => {
    if (/SELECT id, user_id, statut/.test(query)) {
      return { rows: [{ id: 92, user_id: 42, statut: 'en_attente' }] };
    }
    if (/DELETE FROM demandes_achat/.test(query)) deleted = true;
    throw new Error('Une demande en attente ne doit pas être supprimée');
  };

  const response = await deleteDemande(92, tokenFor('admin', 7));
  const body = await response.json();

  assert.equal(response.status, 400);
  assert.match(body.error, /Impossible de supprimer/);
  assert.equal(deleted, false);
});
