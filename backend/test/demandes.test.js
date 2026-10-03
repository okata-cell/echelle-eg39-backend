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
let baseUrl;
let originalQuery;

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

function tokenFor(role = 'client', userId = 42) {
  return jwt.sign({ userId, role }, process.env.JWT_SECRET);
}

test('la création d’une demande inclut l’image de l’appareil', async () => {
  const queries = [];
  pool.query = async (query, params) => {
    queries.push(query);
    if (/SELECT \* FROM appareils/.test(query)) {
      return { rows: [{
        id: 2039,
        code: 'APP-2039',
        nom: 'GPS de test',
        type: 'GPS',
        image_url: 'https://example.com/gps-2039.jpg',
        prix_vente: 250000,
      }] };
    }
    if (/INSERT INTO demandes_achat/.test(query)) {
      return { rows: [{
        id: 106,
        code: 'DA-TEST-106',
        appareil_id: 2039,
        appareil_nom: 'GPS de test',
        quantite: 1,
        total: 250000,
        statut: 'en_attente',
        created_at: '2026-10-03T10:00:00.000Z',
      }] };
    }
    throw new Error(`Requête inattendue: ${query}`);
  };

  const response = await fetch(baseUrl, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${tokenFor()}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ appareilId: 2039, quantite: 1 }),
  });
  const body = await response.json();

  assert.equal(response.status, 201);
  assert.equal(body.demande.appareilId, 2039);
  assert.equal(body.demande.appareilCode, 'APP-2039');
  assert.equal(body.demande.appareilType, 'GPS');
  assert.equal(body.demande.imageUrl, 'https://example.com/gps-2039.jpg');
  assert.equal(queries.length, 2);
});

test('la liste des demandes d’achat inclut l’image et les identifiants appareil', async () => {
  let capturedQuery = '';
  let capturedParams = null;
  pool.query = async (query, params) => {
    capturedQuery = query;
    capturedParams = params;
    return {
      rows: [{
        id: 105,
        code: 'DA-TEST-105',
        user_id: 42,
        appareil_id: 2039,
        appareil_nom: 'GPS de test',
        appareil_prix: 250000,
        quantite: 1,
        total: 250000,
        statut: 'en_attente',
        commentaire_admin: null,
        created_at: '2026-10-03T10:00:00.000Z',
        first_name: 'Afi',
        last_name: 'Koffi',
        email: 'afi@example.com',
        phone: '+22890000000',
        appareil_code: 'APP-2039',
        appareil_type: 'GPS',
        appareil_image_url: 'https://example.com/gps-2039.jpg',
      }],
    };
  };

  const response = await fetch(baseUrl, {
    headers: { Authorization: `Bearer ${tokenFor()}` },
  });
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.match(capturedQuery, /LEFT JOIN appareils a ON a\.id = d\.appareil_id/);
  assert.deepEqual(capturedParams, [42]);
  assert.equal(body.demandes[0].appareilId, 2039);
  assert.equal(body.demandes[0].appareilCode, 'APP-2039');
  assert.equal(body.demandes[0].appareilType, 'GPS');
  assert.equal(body.demandes[0].imageUrl, 'https://example.com/gps-2039.jpg');
});
