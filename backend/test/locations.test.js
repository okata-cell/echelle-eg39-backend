const assert = require('node:assert/strict');
const http = require('node:http');
const express = require('express');
const jwt = require('jsonwebtoken');
const { after, before, test } = require('node:test');

process.env.JWT_SECRET = 'test-only-location-route-secret';

const pool = require('../src/config/database');
const { businessToday } = require('../src/utils/rental_dates');
const locationsRouter = require('../src/routes/locations');

const app = express();
app.use(express.json());
app.use('/api/locations', locationsRouter);

let server;
let baseUrl;
let originalQuery;
let originalConnect;

function makeLocation(overrides = {}) {
  return {
    id: 901,
    code: 'LOC-TEST-901',
    user_id: 42,
    appareil_id: 2039,
    appareil_nom: 'GPS de test',
    date_debut: businessToday(),
    date_fin: businessToday(),
    prix_journalier: 25000,
    montant_total: 25000,
    statut: 'en_attente',
    commentaire_admin: null,
    created_at: '2026-09-25T10:00:00.000Z',
    first_name: 'Afi',
    last_name: 'Koffi',
    email: 'afi@example.com',
    phone: '+22890000000',
    appareil_type: 'GPS',
    appareil_image_url: 'https://example.com/gps.jpg',
    ...overrides,
  };
}

function newDatabase({ device = {}, locations = [] } = {}) {
  const state = {
    locations: locations.map((location) => makeLocation(location)),
    devices: new Map([[2039, {
      id: 2039,
      nom: 'GPS de test',
      prix_location: 25000,
      disponible: true,
      hors_service: false,
      ...device,
    }]]),
    queryLog: [],
    insertCount: 0,
    releaseCount: 0,
    lockTail: Promise.resolve(),
  };

  state.connect = async () => {
    let releaseLock;
    let lockAcquired = false;
    let active = true;
    const client = {
      async query(sql, values = []) {
        state.queryLog.push({ sql, values });
        const normalized = sql.trim().replace(/\s+/g, ' ');
        if (['BEGIN', 'COMMIT', 'ROLLBACK'].includes(normalized)) {
          return { rows: [] };
        }

        if (/SELECT id, nom, prix_location, hors_service FROM appareils/.test(normalized)) {
          const queued = state.lockTail;
          let unlock;
          state.lockTail = new Promise((resolve) => { unlock = resolve; });
          await queued;
          releaseLock = unlock;
          lockAcquired = true;
          const deviceRow = state.devices.get(Number(values[0]));
          return { rows: deviceRow ? [{ ...deviceRow }] : [] };
        }

        if (/SELECT id, code, statut, date_debut, date_fin FROM locations/.test(normalized)) {
          const [appareilId, statuses, excludeId, requestedEnd, requestedStart, openStatuses, today] = values;
          const conflict = state.locations.find((location) => {
            const start = String(location.date_debut).slice(0, 10);
            const end = String(location.date_fin).slice(0, 10);
            const rangeStart = String(requestedStart).slice(0, 10);
            const rangeEnd = String(requestedEnd).slice(0, 10);
            const intersects = start <= rangeEnd && end >= rangeStart;
            const stillOut = openStatuses.includes(location.statut) && end < today && start <= rangeEnd;
            return Number(location.appareil_id) === Number(appareilId) &&
              statuses.includes(location.statut) &&
              Number(location.id) !== Number(excludeId) &&
              (intersects || stillOut);
          });
          return { rows: conflict ? [{ ...conflict }] : [] };
        }

        if (/INSERT INTO locations/.test(normalized)) {
          state.insertCount++;
          const [code, userId, appareilId, appareilNom, dateDebut, dateFin, price, total] = values;
          const location = makeLocation({
            id: 1000 + state.insertCount,
            code,
            user_id: userId,
            appareil_id: appareilId,
            appareil_nom: appareilNom,
            date_debut: dateDebut,
            date_fin: dateFin,
            prix_journalier: price,
            montant_total: total,
            statut: 'en_attente',
          });
          state.locations.push(location);
          return { rows: [{
            id: location.id,
            code: location.code,
            appareil_nom: location.appareil_nom,
            date_debut: location.date_debut,
            date_fin: location.date_fin,
            montant_total: location.montant_total,
            statut: location.statut,
          }] };
        }

        if (/UPDATE locations SET statut = 'en_retard'/.test(normalized)) {
          const [id, today] = values;
          const location = state.locations.find((item) =>
            String(item.id) === String(id) && item.statut === 'en_cours' &&
            String(item.date_fin).slice(0, 10) < today,
          );
          if (!location) return { rows: [] };
          location.statut = 'en_retard';
          return { rows: [{ id: location.id, statut: location.statut, date_fin: location.date_fin }] };
        }

        if (/SELECT id, statut, date_fin FROM locations WHERE id/.test(normalized)) {
          const location = state.locations.find((item) => String(item.id) === String(values[0]));
          return { rows: location ? [{ id: location.id, statut: location.statut, date_fin: location.date_fin }] : [] };
        }

        if (/UPDATE locations SET statut = 'termine'/.test(normalized)) {
          const location = state.locations.find((item) =>
            String(item.id) === String(values[0]) && ['en_cours', 'en_retard'].includes(item.statut),
          );
          if (!location) return { rows: [] };
          location.statut = 'termine';
          return { rows: [{ id: location.id, appareil_id: location.appareil_id, statut: location.statut }] };
        }

        if (/SELECT id FROM locations WHERE id/.test(normalized)) {
          const location = state.locations.find((item) => String(item.id) === String(values[0]));
          return { rows: location ? [{ id: location.id }] : [] };
        }

        if (/SELECT l\.\*, u\.first_name, u\.last_name, u\.email FROM locations/.test(normalized)) {
          const location = state.locations.find((item) => String(item.id) === String(values[0]));
          return { rows: location ? [{ ...location }] : [] };
        }

        if (/UPDATE locations SET statut = 'en_cours'/.test(normalized)) {
          const location = state.locations.find((item) => String(item.id) === String(values[0]));
          if (!location || !['en_attente', 'approuvee'].includes(location.statut)) return { rows: [] };
          location.statut = 'en_cours';
          return { rows: [{ ...location }] };
        }

        if (/SELECT id, hors_service FROM appareils/.test(normalized)) {
          const deviceRow = state.devices.get(Number(values[0]));
          return { rows: deviceRow ? [{ id: deviceRow.id, hors_service: deviceRow.hors_service }] : [] };
        }

        if (/UPDATE appareils/.test(normalized)) {
          const deviceRow = state.devices.get(Number(values[0]));
          if (deviceRow && /SET disponible = false/.test(normalized)) deviceRow.disponible = false;
          if (deviceRow && /SET disponible = NOT hors_service/.test(normalized)) {
            deviceRow.disponible = !deviceRow.hors_service;
          }
          return { rows: [] };
        }

        throw new Error(`Requête DB inattendue: ${normalized}`);
      },
      release() {
        if (!active) return;
        active = false;
        state.releaseCount++;
        if (lockAcquired) releaseLock();
      },
    };
    return client;
  };

  state.query = async (sql, values = []) => {
    const client = await state.connect();
    try {
      return await client.query(sql, values);
    } finally {
      client.release();
    }
  };
  return state;
}

function tokenFor(role, userId = 1) {
  return jwt.sign({ userId, role }, process.env.JWT_SECRET);
}

function addDays(date, amount) {
  const value = new Date(`${date}T00:00:00.000Z`);
  value.setUTCDate(value.getUTCDate() + amount);
  return value.toISOString().slice(0, 10);
}

function postLocation(body, role = 'client', userId = 42) {
  return fetch(baseUrl, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${tokenFor(role, userId)}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
}

before(async () => {
  originalQuery = pool.query;
  originalConnect = pool.connect;
  server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}/api/locations`;
});

after(async () => {
  pool.query = originalQuery;
  pool.connect = originalConnect;
  if (server) await new Promise((resolve) => server.close(resolve));
  await pool.end();
});

test('la route de disponibilité accepte une plage future et renvoie son état', async () => {
  const today = businessToday();
  const start = addDays(today, 2);
  const end = addDays(start, 2);
  const database = newDatabase();
  pool.query = database.query;

  const query = new URLSearchParams({ appareilId: '2039', dateDebut: start, dateFin: end });
  const response = await fetch(`${baseUrl}/disponibilite?${query}`);

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { disponible: true, raison: null });
});

test('une réservation future est créée avec un coût inclusif', async () => {
  const database = newDatabase();
  pool.connect = database.connect;
  const start = addDays(businessToday(), 2);
  const end = addDays(start, 2);

  const response = await postLocation({ appareilId: 2039, dateDebut: start, dateFin: end });
  const body = await response.json();

  assert.equal(response.status, 201);
  assert.equal(body.location.dateDebut, start);
  assert.equal(body.location.dateFin, end);
  assert.equal(body.location.montantTotal, 75000);
  assert.equal(database.insertCount, 1);
  assert.equal(database.releaseCount, 1);
  assert(database.queryLog.some(({ sql }) => sql.trim() === 'COMMIT'));
});

test('une date de début passée est refusée avant écriture', async () => {
  const database = newDatabase();
  pool.connect = database.connect;
  const yesterday = addDays(businessToday(), -1);
  const response = await postLocation({ appareilId: 2039, dateDebut: yesterday, dateFin: yesterday });

  assert.equal(response.status, 400);
  assert.equal(database.insertCount, 0);
  assert.equal(database.releaseCount, 0);
});

test('un chevauchement inclusif est refusé et annule la transaction', async () => {
  const today = businessToday();
  const database = newDatabase({
    locations: [makeLocation({ date_debut: today, date_fin: addDays(today, 2), statut: 'en_attente' })],
  });
  pool.connect = database.connect;

  const response = await postLocation({ appareilId: 2039, dateDebut: addDays(today, 2), dateFin: addDays(today, 3) });
  const body = await response.json();

  assert.equal(response.status, 409);
  assert.equal(body.code, 'PERIODE_INDISPONIBLE');
  assert.equal(database.insertCount, 0);
  assert(database.queryLog.some(({ sql }) => sql.trim() === 'ROLLBACK'));
});

test('deux réservations concurrentes sur le même appareil sont sérialisées', async () => {
  const database = newDatabase();
  pool.connect = database.connect;
  const today = businessToday();
  const body = { appareilId: 2039, dateDebut: today, dateFin: today };

  const responses = await Promise.all([
    postLocation(body, 'client', 42),
    postLocation(body, 'client', 84),
  ]);

  assert.deepEqual(responses.map((response) => response.status).sort(), [201, 409]);
  assert.equal(database.insertCount, 1);
  assert.equal(database.releaseCount, 2);
});

test('un appareil hors service ne peut pas être réservé', async () => {
  const database = newDatabase({ device: { hors_service: true } });
  pool.connect = database.connect;
  const today = businessToday();

  const response = await postLocation({ appareilId: 2039, dateDebut: today, dateFin: today });
  const body = await response.json();
  assert.equal(response.status, 409);
  assert.equal(body.code, 'APPAREIL_HORS_SERVICE');
  assert.equal(database.insertCount, 0);
});

test('une location marquée en retard reste occupée jusqu’au retour physique', async () => {
  const today = businessToday();
  const yesterday = addDays(today, -1);
  const database = newDatabase({
    locations: [makeLocation({ id: 902, date_debut: yesterday, date_fin: yesterday, statut: 'en_cours' })],
  });
  pool.query = database.query;
  const overdue = await fetch(`${baseUrl}/902/retard`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${tokenFor('admin', 7)}` },
  });
  assert.equal(overdue.status, 200);
  assert.equal(database.locations[0].statut, 'en_retard');
  assert.equal(database.queryLog.some(({ sql }) => /UPDATE appareils/.test(sql)), false);

  const clientResponse = await postLocation({ appareilId: 2039, dateDebut: today, dateFin: today });
  assert.equal(clientResponse.status, 409);
  assert.equal(database.insertCount, 0);
});

test('l’ancien endpoint d’expiration ne clôture plus de location automatiquement', async () => {
  const response = await fetch(`${baseUrl}/check-expired`, {
    headers: { Authorization: `Bearer ${tokenFor('admin', 7)}` },
  });
  assert.equal(response.status, 410);
});

test('seul le retour physique confirmé termine une location active', async () => {
  const today = businessToday();
  const database = newDatabase({
    locations: [makeLocation({ id: 903, date_debut: today, date_fin: today, statut: 'en_retard' })],
  });
  pool.connect = database.connect;
  const response = await fetch(`${baseUrl}/903/terminer`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${tokenFor('admin', 7)}` },
  });

  assert.equal(response.status, 200);
  assert.equal(database.locations[0].statut, 'termine');
  assert.equal(database.devices.get(2039).disponible, true);
  assert(database.queryLog.some(({ sql }) => /SET disponible = NOT hors_service/.test(sql)));
});

test('l’approbation revalide les chevauchements et refuse les demandes concurrentes', async () => {
  const today = businessToday();
  const database = newDatabase({
    locations: [
      makeLocation({ id: 904, date_debut: today, date_fin: today, statut: 'en_attente' }),
      makeLocation({ id: 905, date_debut: today, date_fin: today, statut: 'en_attente' }),
    ],
  });
  pool.connect = database.connect;

  const response = await fetch(`${baseUrl}/904/approuver`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${tokenFor('admin', 7)}` },
  });
  const body = await response.json();
  assert.equal(response.status, 409);
  assert.equal(body.code, 'PERIODE_INDISPONIBLE');
  assert.equal(database.locations[0].statut, 'en_attente');
});

test('approuve une location quand PostgreSQL renvoie ses dates en objets Date', async () => {
  const today = businessToday();
  const postgresDate = new Date(`${today}T00:00:00`);
  const database = newDatabase({
    locations: [makeLocation({
      id: 906,
      date_debut: postgresDate,
      date_fin: postgresDate,
      statut: 'en_attente',
    })],
  });
  pool.connect = database.connect;

  const response = await fetch(`${baseUrl}/906/approuver`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${tokenFor('admin', 7)}` },
  });
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.location.statut, 'en_cours');
  assert.equal(database.releaseCount, 1);
});

test('le répertoire admin des locations reste inaccessible à un client', async () => {
  pool.query = async () => { throw new Error('La base ne doit pas être appelée'); };
  const response = await fetch(`${baseUrl}/admin`, {
    headers: { Authorization: `Bearer ${tokenFor('client', 42)}` },
  });
  assert.equal(response.status, 403);
});
