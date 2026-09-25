const assert = require('node:assert/strict');
const http = require('node:http');
const express = require('express');
const jwt = require('jsonwebtoken');
const { after, before, test } = require('node:test');

process.env.JWT_SECRET = 'test-only-location-route-secret';

const pool = require('../src/config/database');
const notificationPath = require.resolve('../src/services/email_sms_service');
require.cache[notificationPath] = {
  id: notificationPath,
  filename: notificationPath,
  loaded: true,
  exports: {
    sendLocationApprovedEmail: async () => {},
    sendLocationRejectedEmail: async () => {},
  },
};
const locationsRouter = require('../src/routes/locations');

const app = express();
app.use(express.json());
app.use('/api/locations', locationsRouter);

let server;
let originalQuery;
let baseUrl;
let insertedLocation;

before(async () => {
  originalQuery = pool.query;
  server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}/api/locations`;
});

after(async () => {
  pool.query = originalQuery;
  if (server) await new Promise((resolve) => server.close(resolve));
  await pool.end();
});

function tokenFor(role, userId = 1) {
  return jwt.sign({ userId, role }, process.env.JWT_SECRET);
}

function persistedLocation(overrides = {}) {
  return {
    id: 901,
    code: 'LOC-TEST-901',
    user_id: 42,
    appareil_id: 2039,
    appareil_nom: 'GPS de test',
    date_debut: '2026-10-01',
    date_fin: '2026-10-03',
    prix_journalier: 25000,
    montant_total: 75000,
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

test('une demande client est visible dans le répertoire admin', async () => {
  insertedLocation = null;
  pool.query = async (query, values) => {
    if (query.includes('FROM appareils WHERE id = $1')) {
      assert.deepEqual(values, [2039]);
      return {
        rows: [
          {
            id: 2039,
            nom: 'GPS de test',
            prix_location: 25000,
            disponible: true,
          },
        ],
      };
    }

    if (query.includes('INSERT INTO locations')) {
      assert.equal(values[1], 42, 'la demande doit appartenir au JWT client');
      insertedLocation = persistedLocation({ user_id: values[1] });
      return { rows: [insertedLocation] };
    }

    if (query.includes("UPDATE locations SET statut = 'en_attente'")) {
      return { rows: [] };
    }

    if (query.includes('SELECT * FROM locations WHERE id = $1')) {
      return { rows: insertedLocation ? [insertedLocation] : [] };
    }

    if (query.includes('FROM locations l')) {
      assert.match(query, /JOIN users u ON l\.user_id = u\.id/);
      assert.match(query, /LEFT JOIN appareils a ON l\.appareil_id = a\.id/);
      assert.doesNotMatch(query, /WHERE l\.user_id/);
      return { rows: insertedLocation ? [insertedLocation] : [] };
    }

    throw new Error(`Requête DB inattendue: ${query}`);
  };

  const clientToken = tokenFor('client', 42);
  const created = await fetch(baseUrl, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${clientToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      appareilId: 2039,
      dateDebut: '2026-10-01',
      dateFin: '2026-10-03',
    }),
  });

  assert.equal(created.status, 201);
  const createdBody = await created.json();
  assert.equal(createdBody.location.statut, 'en_attente');

  const adminResponse = await fetch(`${baseUrl}/admin`, {
    headers: { Authorization: `Bearer ${tokenFor('admin', 7)}` },
  });
  assert.equal(adminResponse.status, 200);
  assert.equal(adminResponse.headers.get('cache-control'), 'no-store');
  assert.deepEqual(await adminResponse.json(), {
    locations: [
      {
        id: 901,
        code: 'LOC-TEST-901',
        clientNom: 'Afi Koffi',
        clientEmail: 'afi@example.com',
        clientPhone: '+22890000000',
        clientTelephone: '+22890000000',
        appareilId: 2039,
        appareilNom: 'GPS de test',
        appareilType: 'GPS',
        imageUrl: 'https://example.com/gps.jpg',
        dateDebut: '2026-10-01',
        dateFin: '2026-10-03',
        prixJournalier: 25000,
        montantTotal: 75000,
        statut: 'en_attente',
        commentaireAdmin: null,
        createdAt: '2026-09-25T10:00:00.000Z',
      },
    ],
  });
});

test('le répertoire complet est réservé aux administrateurs', async () => {
  pool.query = async () => {
    throw new Error('La base ne doit pas être appelée');
  };

  const response = await fetch(`${baseUrl}/admin`, {
    headers: { Authorization: `Bearer ${tokenFor('client', 42)}` },
  });
  assert.equal(response.status, 403);
});

test('la vérification des expirations ne peut pas être appelée par un client', async () => {
  pool.query = async () => {
    throw new Error('La base ne doit pas être appelée');
  };

  const response = await fetch(`${baseUrl}/check-expired`, {
    headers: { Authorization: `Bearer ${tokenFor('client', 42)}` },
  });
  assert.equal(response.status, 403);
});
