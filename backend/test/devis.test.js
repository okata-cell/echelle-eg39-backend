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
    montant: null,
    created_at: '2026-10-08T10:00:00.000Z',
    updated_at: '2026-10-08T10:00:00.000Z',
    client_email: 'afi@example.com',
    client_first_name: 'Afi',
    client_last_name: 'Koffi',
    ...overrides,
  };
}

const requestBody = {
  serviceId: '1',
  serviceName: 'Levée de détail',
  description: 'Relevé du terrain',
  nom: 'Afi Koffi',
  telephone: '90 00 00 00',
  email: 'afi@example.com',
};

function request(path = '', { method = 'GET', token, body } = {}) {
  return fetch(`${baseUrl}${path}`, {
    method,
    headers: {
      ...(body ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
}

test('refuse une demande client sans session avant tout accès à la base', async () => {
  let queried = false;
  pool.query = async () => {
    queried = true;
    throw new Error('aucune écriture ne doit avoir lieu');
  };

  const response = await request('', { method: 'POST', body: requestBody });
  assert.equal(response.status, 401);
  assert.equal(queried, false);
});

test('le bouton Envoyer crée une demande rattachée au client connecté', async () => {
  let capturedParams;
  pool.query = async (query, params) => {
    assert.match(query, /INSERT INTO devis/);
    capturedParams = params;
    return { rows: [devisRow()] };
  };

  const response = await request('', {
    method: 'POST',
    token: tokenFor('client', 42),
    body: requestBody,
  });
  const body = await response.json();

  assert.equal(response.status, 201);
  assert.equal(body.lieAuCompte, true);
  assert.equal(capturedParams[0], 42);
  assert.equal(body.devis.statut, 'en_attente');
});

test('un administrateur ne peut pas créer une demande client', async () => {
  let queried = false;
  pool.query = async () => {
    queried = true;
    throw new Error('aucune écriture ne doit avoir lieu');
  };

  const response = await request('', {
    method: 'POST',
    token: tokenFor('admin'),
    body: requestBody,
  });
  assert.equal(response.status, 403);
  assert.equal(queried, false);
});

test('la liste admin est réservée aux administrateurs', async () => {
  let queried = false;
  pool.query = async () => {
    queried = true;
    return { rows: [] };
  };

  assert.equal((await request()).status, 401);
  assert.equal((await request('', { token: tokenFor('client') })).status, 403);
  assert.equal(queried, false);
});

test('le client ne consulte que les demandes liées à son compte', async () => {
  let capturedParams;
  pool.query = async (query, params) => {
    assert.match(query, /WHERE d\.user_id = \$1/);
    capturedParams = params;
    return { rows: [devisRow()] };
  };

  const response = await request('/me', { token: tokenFor('client', 42) });
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.deepEqual(capturedParams, [42]);
  assert.equal(body.devis[0].clientNom, 'Afi Koffi');
  assert.equal(body.devis[0].statut, 'en_attente');
  assert.equal('documentUrl' in body.devis[0], false);
  assert.equal('dateValidite' in body.devis[0], false);
  assert.equal(response.headers.get('cache-control'), 'private, no-store');
});

test('GET /api/devis renvoie une liste sans signature de document', async () => {
  pool.query = async () => ({ rows: [devisRow()] });
  const response = await request('', { token: tokenFor('admin') });
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.equal(body.devis[0].statut, 'en_attente');
  assert.equal('documentUrl' in body.devis[0], false);
});

test('l’administrateur peut démarrer l’examen d’une demande en attente', async () => {
  let calls = 0;
  pool.query = async (query, params) => {
    calls += 1;
    if (/SELECT id, statut/.test(query)) {
      return { rows: [{ id: 5, statut: 'en_attente' }] };
    }
    if (/UPDATE devis/.test(query)) {
      assert.deepEqual(params, ['en_traitement', '', '5', 'en_attente']);
      return { rows: [devisRow({ statut: 'en_traitement' })] };
    }
    throw new Error(`Requête inattendue: ${query}`);
  };

  const response = await request('/5/statut', {
    method: 'PATCH',
    token: tokenFor('admin'),
    body: { statut: 'en_traitement' },
  });
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.devis.statut, 'en_traitement');
  assert.equal(calls, 2);
});

test('le filtre admin accepte le statut en_traitement', async () => {
  let capturedQuery;
  let capturedParams;
  pool.query = async (query, params) => {
    capturedQuery = query;
    capturedParams = params;
    return { rows: [devisRow({ statut: 'en_traitement' })] };
  };

  const response = await request('?statut=en_traitement', {
    token: tokenFor('admin'),
  });
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.match(capturedQuery, /d\.statut = ANY/);
  assert.deepEqual(capturedParams, [['en_traitement']]);
  assert.equal(body.devis[0].statut, 'en_traitement');
});

test('une décision est refusée tant que l’examen de la demande n’a pas commencé', async () => {
  pool.query = async (query) => {
    if (/^UPDATE devis/.test(query)) return { rows: [] };
    if (/SELECT id, user_id, statut/.test(query)) {
      return { rows: [devisRow({ statut: 'en_attente' })] };
    }
    throw new Error(`Requête inattendue: ${query}`);
  };

  const approval = await request('/5/approuver', {
    method: 'PATCH',
    token: tokenFor('admin'),
    body: { montant: 125000 },
  });
  const rejection = await request('/5/rejeter', {
    method: 'PATCH',
    token: tokenFor('admin'),
    body: { raison: 'Motif obligatoire' },
  });

  assert.equal(approval.status, 409);
  assert.match((await approval.json()).error, /en examen/);
  assert.equal(rejection.status, 409);
  assert.match((await rejection.json()).error, /en examen/);
});

test('approuver enregistre le montant positif et notifie l’état côté client', async () => {
  let capturedQuery;
  let capturedParams;
  pool.query = async (query, params) => {
    capturedQuery = query;
    capturedParams = params;
    return {
      rows: [devisRow({ statut: 'approuvee', montant: '125000' })],
    };
  };

  const response = await request('/5/approuver', {
    method: 'PATCH',
    token: tokenFor('admin'),
    body: { montant: 125000 },
  });
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.match(capturedQuery, /statut = 'approuvee'/);
  assert.match(capturedQuery, /WHERE id = \$2 AND statut = 'en_traitement'/);
  assert.doesNotMatch(capturedQuery, /document_storage_key|document_url|date_validite/);
  assert.deepEqual(capturedParams, [125000, '5']);
  assert.equal(body.devis.statut, 'approuvee');
  assert.equal(body.devis.montant, '125000');
  assert.equal(response.headers.get('cache-control'), 'private, no-store');
});

test('l’approbation refuse tout montant absent, nul, décimal ou trop grand', async () => {
  let queried = false;
  pool.query = async () => {
    queried = true;
    throw new Error('la validation doit arrêter la requête');
  };

  for (const body of [{}, { montant: 0 }, { montant: 250.5 }, { montant: '9007199254740992' }]) {
    const response = await request('/5/approuver', {
      method: 'PATCH',
      token: tokenFor('admin'),
      body,
    });
    assert.equal(response.status, 400);
  }
  assert.equal(queried, false);
});

test('un client ne peut pas approuver un devis même avec un montant valide', async () => {
  let queried = false;
  pool.query = async () => {
    queried = true;
    throw new Error('aucune écriture ne doit avoir lieu');
  };
  const response = await request('/5/approuver', {
    method: 'PATCH',
    token: tokenFor('client'),
    body: { montant: 1000 },
  });
  assert.equal(response.status, 403);
  assert.equal(queried, false);
});

test('un conflit concurrent pendant l’approbation retourne 409', async () => {
  pool.query = async (query) => {
    if (/UPDATE devis/.test(query)) return { rows: [] };
    if (/SELECT id, user_id, statut/.test(query)) {
      return { rows: [devisRow({ statut: 'rejetee' })] };
    }
    throw new Error(`Requête inattendue: ${query}`);
  };

  const response = await request('/5/approuver', {
    method: 'PATCH',
    token: tokenFor('admin'),
    body: { montant: 50000 },
  });
  assert.equal(response.status, 409);
});

test('une demande sans compte client ne peut pas être approuvée', async () => {
  pool.query = async (query) => {
    if (/UPDATE devis/.test(query)) return { rows: [] };
    if (/SELECT id, user_id, statut/.test(query)) {
      return { rows: [devisRow({ user_id: null })] };
    }
    throw new Error(`Requête inattendue: ${query}`);
  };

  const response = await request('/5/approuver', {
    method: 'PATCH',
    token: tokenFor('admin'),
    body: { montant: 50000 },
  });
  assert.equal(response.status, 409);
});

test('le motif de rejet est obligatoire, non vide et limité à 1000 caractères', async () => {
  let queried = false;
  pool.query = async () => {
    queried = true;
    throw new Error('la validation doit arrêter la requête');
  };

  for (const body of [{}, { raison: '' }, { raison: '   ' }, { raison: 123 }, { raison: 'x'.repeat(1001) }]) {
    const response = await request('/5/rejeter', {
      method: 'PATCH',
      token: tokenFor('admin'),
      body,
    });
    assert.equal(response.status, 400);
  }
  assert.equal(queried, false);
});

test('rejeter enregistre le motif qui sera affiché au client', async () => {
  let capturedQuery;
  let capturedParams;
  pool.query = async (query, params) => {
    capturedQuery = query;
    capturedParams = params;
    return {
      rows: [devisRow({ statut: 'rejetee', commentaire_admin: 'Budget insuffisant' })],
    };
  };

  const response = await request('/5/rejeter', {
    method: 'PATCH',
    token: tokenFor('admin'),
    body: { raison: '  Budget insuffisant  ' },
  });
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.match(capturedQuery, /statut = 'rejetee'/);
  assert.match(capturedQuery, /commentaire_admin = \$1/);
  assert.match(capturedQuery, /WHERE id = \$2 AND statut = 'en_traitement'/);
  assert.deepEqual(capturedParams, ['Budget insuffisant', '5']);
  assert.equal(body.devis.statut, 'rejetee');
  assert.equal(body.devis.commentaireAdmin, 'Budget insuffisant');
});

test('un client ne peut pas rejeter la demande à la place de l’admin', async () => {
  let queried = false;
  pool.query = async () => {
    queried = true;
    throw new Error('aucune écriture ne doit avoir lieu');
  };
  const response = await request('/5/rejeter', {
    method: 'PATCH',
    token: tokenFor('client'),
    body: { raison: 'Motif' },
  });
  assert.equal(response.status, 403);
  assert.equal(queried, false);
});

test('les routes PDF/R2 et la décision du client ne sont plus disponibles', async () => {
  let queried = false;
  pool.query = async () => {
    queried = true;
    throw new Error('les anciennes routes doivent répondre 404');
  };

  const routeReponse = await request('/5/reponse', {
    method: 'PATCH',
    token: tokenFor('client'),
    body: { decision: 'acceptee' },
  });
  const routeDocument = await request('/5/document-url', {
    token: tokenFor('client'),
  });
  const routeEmission = await request('/5/offre', {
    method: 'PATCH',
    token: tokenFor('admin'),
    body: { montant: 1000 },
  });

  assert.equal(routeReponse.status, 404);
  assert.equal(routeDocument.status, 404);
  assert.equal(routeEmission.status, 404);
  assert.equal(queried, false);
});

test('le suivi ne peut pas contourner l’approbation tarifée ou le rejet motivé', async () => {
  let queried = false;
  pool.query = async () => {
    queried = true;
    throw new Error('validation attendue');
  };

  for (const statut of ['en_attente', 'approuvee', 'rejetee', 'envoye', 'acceptee', 'refusee']) {
    const response = await request('/5/statut', {
      method: 'PATCH',
      token: tokenFor('admin'),
      body: { statut },
    });
    assert.equal(response.status, 400);
  }
  assert.equal(queried, false);
});

test('une demande approuvée peut entrer en suivi, mais ne peut pas être re-traitée', async () => {
  let calls = 0;
  pool.query = async (query, params) => {
    calls += 1;
    if (/SELECT id, statut/.test(query)) {
      return { rows: [{ id: 5, statut: 'approuvee' }] };
    }
    if (/UPDATE devis/.test(query)) {
      assert.deepEqual(params, ['en_cours', '', '5', 'approuvee']);
      return { rows: [{ ...devisRow(), statut: 'en_cours' }] };
    }
    throw new Error(`Requête inattendue: ${query}`);
  };

  const response = await request('/5/statut', {
    method: 'PATCH',
    token: tokenFor('admin'),
    body: { statut: 'en_cours' },
  });
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.equal(body.devis.statut, 'en_cours');
  assert.equal(calls, 2);
});

test('une erreur PostgreSQL pendant approbation renvoie une erreur contrôlée', async () => {
  pool.query = async () => {
    throw new Error('secret database details');
  };
  const response = await request('/5/approuver', {
    method: 'PATCH',
    token: tokenFor('admin'),
    body: { montant: 25000 },
  });
  const body = await response.json();
  assert.equal(response.status, 500);
  assert.equal(JSON.stringify(body).includes('secret database details'), false);
});

test('la suppression admin ne tente plus de supprimer un objet R2', async () => {
  let query;
  pool.query = async (sql) => {
    query = sql;
    return { rows: [{ id: 5 }] };
  };
  const response = await request('/5', {
    method: 'DELETE',
    token: tokenFor('admin'),
  });
  assert.equal(response.status, 200);
  assert.match(query, /DELETE FROM devis/);
  assert.doesNotMatch(query, /document_storage_key/);
});

test('un client peut supprimer uniquement ses devis rejetés ou terminés', async () => {
  let capturedParams;
  let capturedQuery;
  pool.query = async (query, params) => {
    capturedQuery = query;
    capturedParams = params;
    return { rows: [{ id: Number(params[0]) }] };
  };

  for (const id of [5, 6]) {
    const response = await request(`/me/${id}`, {
      method: 'DELETE',
      token: tokenFor('client', 42),
    });
    const body = await response.json();
    assert.equal(response.status, 200);
    assert.equal(body.message, 'Demande de devis supprimée.');
    assert.match(capturedQuery, /user_id = \$2/);
    assert.match(capturedQuery, /statut IN \('rejetee', 'termine'\)/);
    assert.deepEqual(capturedParams, [String(id), 42]);
  }
});

test('un client ne peut pas supprimer un devis en attente, approuvé ou en cours', async () => {
  let currentStatus;
  let deleteAttempted = false;
  pool.query = async (query) => {
    if (/^DELETE FROM devis/.test(query)) {
      deleteAttempted = true;
      return { rows: [] };
    }
    if (/SELECT statut FROM devis/.test(query)) {
      return { rows: [{ statut: currentStatus }] };
    }
    throw new Error(`Requête inattendue: ${query}`);
  };

  for (const statut of ['en_attente', 'approuvee', 'en_cours']) {
    currentStatus = statut;
    const response = await request('/me/5', {
      method: 'DELETE',
      token: tokenFor('client', 42),
    });
    const body = await response.json();
    assert.equal(response.status, 409);
    assert.match(body.error, /après un refus ou la fin du suivi/);
  }
  assert.equal(deleteAttempted, true);
});

test('la suppression client ne révèle pas les devis inexistants ou appartenant à autrui', async () => {
  pool.query = async (query) => {
    if (/^DELETE FROM devis/.test(query)) return { rows: [] };
    if (/SELECT statut FROM devis/.test(query)) return { rows: [] };
    throw new Error(`Requête inattendue: ${query}`);
  };

  const response = await request('/me/5', {
    method: 'DELETE',
    token: tokenFor('client', 24),
  });
  assert.equal(response.status, 404);
  assert.deepEqual(await response.json(), { error: 'Devis non trouvé.' });
});

test('la suppression client est réservée à un client authentifié', async () => {
  let queried = false;
  pool.query = async () => {
    queried = true;
    throw new Error('aucune requête ne doit être exécutée');
  };

  assert.equal((await request('/me/5', { method: 'DELETE' })).status, 401);
  assert.equal(
    (await request('/me/5', { method: 'DELETE', token: tokenFor('admin') }))
      .status,
    403,
  );
  assert.equal(queried, false);
});
