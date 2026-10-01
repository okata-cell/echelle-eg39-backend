const assert = require('node:assert/strict');
const http = require('node:http');
const express = require('express');
const jwt = require('jsonwebtoken');
const { after, before, test } = require('node:test');

process.env.JWT_SECRET = 'test-only-extension-secret';

const pool = require('../src/config/database');
const { businessToday } = require('../src/utils/rental_dates');
const prolongationsRouter = require('../src/routes/prolongations');

const app = express();
app.use(express.json());
app.use('/api/prolongations', prolongationsRouter);
let server;
let baseUrl;
let originalConnect;

function tokenFor(userId = 42) {
  return jwt.sign({ userId, role: 'client' }, process.env.JWT_SECRET);
}

function fakeDatabase({ hasConflict = false } = {}) {
  const state = { queries: [], inserted: false, released: 0 };
  state.connect = async () => ({
    async query(sql, values = []) {
      const normalized = sql.trim().replace(/\s+/g, ' ');
      state.queries.push({ sql: normalized, values });
      if (['BEGIN', 'COMMIT', 'ROLLBACK'].includes(normalized)) return { rows: [] };
      if (/SELECT \* FROM locations/.test(normalized)) {
        return { rows: [{
          id: 77,
          user_id: 42,
          appareil_id: 2039,
          appareil_nom: 'GPS de test',
          date_debut: businessToday(),
          date_fin: businessToday(),
          prix_journalier: 25000,
          montant_total: 25000,
          statut: 'en_cours',
        }] };
      }
      if (/SELECT id FROM appareils/.test(normalized)) return { rows: [{ id: 2039 }] };
      if (/SELECT id, code, statut, date_debut, date_fin FROM locations/.test(normalized)) {
        return { rows: hasConflict ? [{ id: 88, statut: 'en_attente' }] : [] };
      }
      if (/SELECT COUNT\(\*\) AS count FROM prolongations/.test(normalized)) {
        return { rows: [{ count: '0' }] };
      }
      if (/INSERT INTO prolongations/.test(normalized)) {
        state.inserted = true;
        return { rows: [{
          id: 9,
          code: values[0],
          jours_supplementaires: values[4],
          cout_supplementaire: values[5],
          nouvelle_date_fin: values[3],
          facture_numero: values[6],
        }] };
      }
      if (/UPDATE locations/.test(normalized)) return { rows: [] };
      throw new Error(`Unexpected database query: ${normalized}`);
    },
    release() { state.released++; },
  });
  return state;
}

before(async () => {
  originalConnect = pool.connect;
  server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}/api/prolongations`;
});

after(async () => {
  pool.connect = originalConnect;
  if (server) await new Promise((resolve) => server.close(resolve));
  await pool.end();
});

test('refuse atomiquement une prolongation qui chevauche une autre location', async () => {
  const database = fakeDatabase({ hasConflict: true });
  pool.connect = database.connect;
  const end = new Date(`${businessToday()}T00:00:00.000Z`);
  end.setUTCDate(end.getUTCDate() + 3);
  const response = await fetch(baseUrl, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${tokenFor()}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ locationId: 77, nouvelleDateFin: end.toISOString().slice(0, 10) }),
  });
  const body = await response.json();

  assert.equal(response.status, 409);
  assert.equal(body.code, 'PERIODE_INDISPONIBLE');
  assert.equal(database.inserted, false);
  assert(database.queries.some(({ sql }) => sql === 'ROLLBACK'));
  assert.equal(database.released, 1);
});

test('crée une prolongation libre et met à jour la location dans la transaction', async () => {
  const database = fakeDatabase();
  pool.connect = database.connect;
  const end = new Date(`${businessToday()}T00:00:00.000Z`);
  end.setUTCDate(end.getUTCDate() + 3);
  const nouvelleDateFin = end.toISOString().slice(0, 10);
  const response = await fetch(baseUrl, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${tokenFor()}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ locationId: 77, nouvelleDateFin }),
  });
  const body = await response.json();

  assert.equal(response.status, 201);
  assert.equal(body.prolongation.joursSupplementaires, 3);
  assert.equal(body.prolongation.coutSupplementaire, 75000);
  assert(database.inserted);
  assert(database.queries.some(({ sql }) => sql === 'COMMIT'));
  assert.equal(database.released, 1);
});
