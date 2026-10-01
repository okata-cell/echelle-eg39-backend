const assert = require('node:assert/strict');
const http = require('node:http');
const express = require('express');
const jwt = require('jsonwebtoken');
const { after, before, test } = require('node:test');

process.env.JWT_SECRET = 'test-only-appareils-secret';

const pool = require('../src/config/database');
const appareilsRouter = require('../src/routes/appareils');
const app = express();
app.use(express.json());
app.use('/api/appareils', appareilsRouter);

let server;
let baseUrl;
let originalQuery;
let activeLocationExists = false;
let updatedRow;

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

test('le catalogue garde disponible pour la vente et expose horsService pour la location', async () => {
  pool.query = async (query) => {
    assert.match(query, /SELECT \* FROM appareils/);
    return {
      rows: [{
        id: 2039,
        code: 'APP-2039',
        nom: 'GPS test',
        type: 'GPS',
        image_url: null,
        prix_location: 25000,
        prix_vente: 2500000,
        disponible: false,
        hors_service: false,
        created_at: '2026-09-30T10:00:00.000Z',
      }],
    };
  };

  const response = await fetch(baseUrl);
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.equal(body.appareils[0].disponible, false);
  assert.equal(body.appareils[0].horsService, false);
});

test('l’admin ne peut pas remettre en vente un appareil avant le retour confirmé', async () => {
  activeLocationExists = true;
  let updateAttempted = false;
  pool.query = async (query, params) => {
    if (/SELECT id FROM locations/.test(query)) {
      assert.deepEqual(params, ['2039']);
      return { rows: activeLocationExists ? [{ id: 44 }] : [] };
    }
    if (/UPDATE appareils/.test(query)) {
      updateAttempted = true;
      return { rows: [] };
    }
    throw new Error(`Requête DB inattendue: ${query}`);
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
  assert.equal(updateAttempted, false);
});

test('la bascule hors service persiste les deux états matériel sans toucher au calendrier', async () => {
  activeLocationExists = false;
  pool.query = async (query, params) => {
    assert.match(query, /hors_service = CASE/);
    assert.match(query, /disponible = COALESCE/);
    assert.deepEqual(params, [undefined, undefined, undefined, undefined, undefined, false, '2039']);
    updatedRow = {
      id: 2039,
      code: 'APP-2039',
      nom: 'GPS test',
      type: 'GPS',
      image_url: null,
      prix_location: 25000,
      prix_vente: 2500000,
      disponible: false,
      hors_service: true,
      created_at: '2026-09-30T10:00:00.000Z',
    };
    return { rows: [updatedRow] };
  };

  const response = await fetch(`${baseUrl}/2039`, {
    method: 'PUT',
    headers: {
      Authorization: `Bearer ${tokenFor()}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ disponible: false }),
  });
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.appareil.disponible, false);
  assert.equal(body.appareil.horsService, true);
});
