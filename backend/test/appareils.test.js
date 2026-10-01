const assert = require('node:assert/strict');
const http = require('node:http');
const express = require('express');
const jwt = require('jsonwebtoken');
const { after, before, test } = require('node:test');

process.env.JWT_SECRET = 'test-only-equipment-serviceability-secret';

const pool = require('../src/config/database');
const appareilsRouter = require('../src/routes/appareils');
const app = express();
app.use(express.json());
app.use('/api/appareils', appareilsRouter);
let server;
let baseUrl;
let originalQuery;

function tokenFor(role = 'admin') {
  return jwt.sign({ userId: 7, role }, process.env.JWT_SECRET);
}

before(async () => {
  originalQuery = pool.query;
  server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}/api/appareils`;
});

after(async () => {
  pool.query = originalQuery;
  if (server) await new Promise((resolve) => server.close(resolve));
  await pool.end();
});

test('le catalogue expose horsService sans changer le filtre de vente', async () => {
  let capturedQuery;
  pool.query = async (query, params) => {
    capturedQuery = { query, params };
    return { rows: [{
      id: 2039,
      code: 'APP-2039',
      nom: 'GPS test',
      type: 'GPS',
      image_url: null,
      prix_location: 25000,
      prix_vente: 250000,
      disponible: true,
      hors_service: true,
    }] };
  };

  const response = await fetch(`${baseUrl}?disponible=true`);
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.deepEqual(capturedQuery.params, [true]);
  assert.equal(body.appareils[0].disponible, true);
  assert.equal(body.appareils[0].horsService, true);
});

test('empêche de remettre en vente un appareil dont le retour physique n’est pas confirmé', async () => {
  const queries = [];
  pool.query = async (query, values) => {
    queries.push(query);
    assert.deepEqual(values, ['2039']);
    return { rows: [{ id: 77 }] };
  };

  const response = await fetch(`${baseUrl}/2039`, {
    method: 'PUT',
    headers: {
      Authorization: `Bearer ${tokenFor()}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ disponible: true }),
  });
  const body = await response.json();

  assert.equal(response.status, 409);
  assert.match(body.error, /retour physique/);
  assert.equal(queries.length, 1, 'aucune écriture d’appareil ne doit suivre le conflit');
});
