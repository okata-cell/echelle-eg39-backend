const assert = require('node:assert/strict');
const http = require('node:http');
const express = require('express');
const jwt = require('jsonwebtoken');
const { after, before, test } = require('node:test');

process.env.JWT_SECRET = 'test-only-devis-secret';

const pool = require('../src/config/database');
const devisRouter = require('../src/routes/devis');

const app = express();
app.use(express.json());
app.use('/api/devis', devisRouter);

let server;
let originalQuery;
let baseUrl;

before(async () => {
  originalQuery = pool.query;
  server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}/api/devis`;
});

after(async () => {
  pool.query = originalQuery;
  if (server) await new Promise((resolve) => server.close(resolve));
  await pool.end();
});

function tokenFor(role, userId = 42) {
  return jwt.sign({ userId, role }, process.env.JWT_SECRET);
}

function devisRow(overrides = {}) {
  return {
    id: 5,
    user_id: 42,
    service_id: '1',
    service_name: 'Levée de détail',
    description: 'Relevé du terrain',
    nom: 'Afi Koffi',
    telephone: '+22890000000',
    email: 'afi@example.com',
    statut: 'en_attente',
    commentaire_admin: null,
    created_at: '2026-09-25T10:00:00.000Z',
    updated_at: '2026-09-25T10:00:00.000Z',
    client_email: 'afi@example.com',
    client_first_name: 'Afi',
    client_last_name: 'Koffi',
    ...overrides,
  };
}

function postDevis(body, token) {
  return fetch(baseUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });
}

const corpsValide = {
  serviceId: '1',
  serviceName: 'Levée de détail',
  description: 'Relevé du terrain',
  nom: 'Afi Koffi',
  telephone: '90 00 00 00',
  email: 'afi@example.com',
};

test('un devis anonyme reste accepté mais n’est rattaché à aucun compte', async () => {
  let capturedParams = null;
  pool.query = async (query, params) => {
    assert.match(query, /INSERT INTO devis/);
    capturedParams = params;
    return { rows: [devisRow({ user_id: null })] };
  };

  const response = await postDevis(corpsValide);
  const body = await response.json();

  assert.equal(response.status, 201);
  assert.equal(body.lieAuCompte, false);
  assert.equal(capturedParams[0], null);
  assert.equal(capturedParams[5], '+22890000000', 'le téléphone doit être normalisé');
});

test('un devis soumis avec un jeton est rattaché au compte connecté', async () => {
  let capturedParams = null;
  pool.query = async (query, params) => {
    assert.match(query, /INSERT INTO devis/);
    capturedParams = params;
    return { rows: [devisRow()] };
  };

  const response = await postDevis(corpsValide, tokenFor('client', 42));
  const body = await response.json();

  assert.equal(response.status, 201);
  assert.equal(body.lieAuCompte, true);
  assert.equal(capturedParams[0], 42);
  assert.equal(body.devis.clientEmail, 'afi@example.com');
});

test('un jeton invalide n’empêche pas la création du devis', async () => {
  pool.query = async () => ({ rows: [devisRow({ user_id: null })] });

  const response = await postDevis(corpsValide, 'jeton-perime');
  const body = await response.json();

  assert.equal(response.status, 201);
  assert.equal(body.lieAuCompte, false);
});

test('la liste admin reste réservée aux administrateurs', async () => {
  const sansSession = await fetch(baseUrl);
  assert.equal(sansSession.status, 401);

  const client = await fetch(baseUrl, {
    headers: { Authorization: `Bearer ${tokenFor('client')}` },
  });
  assert.equal(client.status, 403);
});

test('le suivi client ne renvoie que les devis du compte connecté', async () => {
  let capturedParams = null;
  pool.query = async (query, params) => {
    assert.match(query, /WHERE d\.user_id = \$1/);
    capturedParams = params;
    return { rows: [devisRow()] };
  };

  const response = await fetch(`${baseUrl}/me`, {
    headers: { Authorization: `Bearer ${tokenFor('client', 42)}` },
  });
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(capturedParams[0], 42);
  assert.equal(body.devis.length, 1);
  assert.equal(body.devis[0].clientNom, 'Afi Koffi');
});

test('la liste admin accepte plusieurs statuts et rejette un statut inconnu', async () => {
  let capturedParams = null;
  pool.query = async (query, params) => {
    assert.match(query, /d\.statut = ANY/);
    capturedParams = params;
    return { rows: [] };
  };

  const valide = await fetch(`${baseUrl}?statut=en_cours,envoye`, {
    headers: { Authorization: `Bearer ${tokenFor('admin')}` },
  });
  assert.equal(valide.status, 200);
  assert.deepEqual(capturedParams[0], ['en_cours', 'envoye']);

  const invalide = await fetch(`${baseUrl}?statut=nouveau`, {
    headers: { Authorization: `Bearer ${tokenFor('admin')}` },
  });
  assert.equal(invalide.status, 400);
});

test('un devis en attente peut être approuvé', async () => {
  pool.query = async (query) => {
    if (/SELECT id, statut/.test(query)) return { rows: [{ id: 5, statut: 'en_attente' }] };
    if (/UPDATE devis/.test(query)) return { rows: [{ id: 5 }] };
    return { rows: [devisRow({ statut: 'approuvee' })] };
  };

  const response = await fetch(`${baseUrl}/5/approuver`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${tokenFor('admin')}` },
  });
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.devis.statut, 'approuvee');
});

test('un devis rejeté est définitif : la route de suivi refuse de le relancer', async () => {
  pool.query = async (query) => {
    if (/SELECT id, statut/.test(query)) return { rows: [{ id: 5, statut: 'rejetee' }] };
    throw new Error('aucune écriture ne doit avoir lieu');
  };

  const response = await fetch(`${baseUrl}/5/statut`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${tokenFor('admin')}`,
    },
    body: JSON.stringify({ statut: 'en_cours' }),
  });
  const body = await response.json();

  assert.equal(response.status, 400);
  assert.match(body.error, /clôturé/);
});

test('un devis rejeté ne peut pas être approuvé', async () => {
  pool.query = async (query) => {
    assert.match(query, /SELECT id, statut/);
    return { rows: [{ id: 5, statut: 'rejetee' }] };
  };

  const response = await fetch(`${baseUrl}/5/approuver`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${tokenFor('admin')}` },
  });

  assert.equal(response.status, 400);
});

test('le motif de rejet est enregistré dans le commentaire admin', async () => {
  let capturedParams = null;
  pool.query = async (query, params) => {
    if (/SELECT id, statut/.test(query)) return { rows: [{ id: 5, statut: 'en_attente' }] };
    if (/UPDATE devis/.test(query)) {
      capturedParams = params;
      return { rows: [{ id: 5 }] };
    }
    return { rows: [devisRow({ statut: 'rejetee', commentaire_admin: 'Budget insuffisant' })] };
  };

  const response = await fetch(`${baseUrl}/5/rejeter`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${tokenFor('admin')}`,
    },
    body: JSON.stringify({ raison: 'Budget insuffisant' }),
  });
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(capturedParams[0], 'rejetee');
  assert.equal(capturedParams[1], 'Budget insuffisant');
  assert.equal(body.devis.commentaireAdmin, 'Budget insuffisant');
});

test('un devis inexistant renvoie une 404 sur les mutations', async () => {
  pool.query = async (query) => {
    assert.match(query, /SELECT id, statut/);
    return { rows: [] };
  };

  const response = await fetch(`${baseUrl}/999/approuver`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${tokenFor('admin')}` },
  });

  assert.equal(response.status, 404);
});

test('un changement de statut concurrent est refusé avec un 409', async () => {
  pool.query = async (query) => {
    if (/SELECT id, statut/.test(query)) return { rows: [{ id: 5, statut: 'en_attente' }] };
    if (/UPDATE devis/.test(query)) return { rows: [] };
    throw new Error('aucune relecture ne doit avoir lieu');
  };

  const response = await fetch(`${baseUrl}/5/statut`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${tokenFor('admin')}`,
    },
    body: JSON.stringify({ statut: 'approuvee' }),
  });
  const body = await response.json();

  assert.equal(response.status, 409);
  assert.match(body.error, /Actualisez/);
});
