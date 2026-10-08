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
    date_validite: null,
    document_url: null,
    offre_emise_at: null,
    client_repondu_at: null,
    offre_expiree: false,
    created_at: '2026-09-25T10:00:00.000Z',
    updated_at: '2026-09-25T10:00:00.000Z',
    client_email: 'afi@example.com',
    client_first_name: 'Afi',
    client_last_name: 'Koffi',
    ...overrides,
  };
}

function dateInDays(days) {
  const date = new Date();
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
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

test('une demande sans authentification est refusée sans accès à la base', async () => {
  let queried = false;
  pool.query = async () => {
    queried = true;
    throw new Error('aucune écriture ne doit avoir lieu');
  };

  const response = await postDevis(corpsValide);
  assert.equal(response.status, 401);
  assert.equal(queried, false);
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

test('un jeton invalide ne permet pas de soumettre une demande', async () => {
  pool.query = async () => {
    throw new Error('aucune écriture ne doit avoir lieu');
  };

  const response = await postDevis(corpsValide, 'jeton-perime');
  assert.equal(response.status, 401);
});

test('un administrateur ne peut pas soumettre une demande client', async () => {
  pool.query = async () => {
    throw new Error('aucune écriture ne doit avoir lieu');
  };

  const response = await postDevis(corpsValide, tokenFor('admin'));
  assert.equal(response.status, 403);
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

test('l’admin émet un devis avec montant, validité et document HTTPS', async () => {
  let offerParams;
  pool.query = async (query, params) => {
    if (/UPDATE devis/.test(query)) {
      assert.match(query, /statut = 'envoye'/);
      assert.match(query, /user_id IS NOT NULL/);
      offerParams = params;
      return { rows: [{ id: 5 }] };
    }
    if (/SELECT d\.\*/.test(query)) {
      return {
        rows: [devisRow({
          statut: 'envoye',
          montant: '125000',
          date_validite: dateInDays(7),
          document_url: 'https://files.example.com/devis-5.pdf',
          offre_emise_at: '2026-10-08T10:00:00.000Z',
        })],
      };
    }
    throw new Error(`Requête inattendue: ${query}`);
  };

  const response = await fetch(`${baseUrl}/5/offre`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${tokenFor('admin')}`,
    },
    body: JSON.stringify({
      montant: 125000,
      dateValidite: dateInDays(7),
      documentUrl: 'https://files.example.com/devis-5.pdf',
    }),
  });
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(offerParams[0], 125000);
  assert.equal(offerParams[2], 'https://files.example.com/devis-5.pdf');
  assert.equal(body.devis.statut, 'envoye');
  assert.equal(body.devis.montant, '125000');
  assert.equal(body.devis.documentUrl, 'https://files.example.com/devis-5.pdf');
});

test('l’émission refuse une date de validité passée', async () => {
  let queried = false;
  pool.query = async () => {
    queried = true;
    return { rows: [] };
  };

  const response = await fetch(`${baseUrl}/5/offre`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${tokenFor('admin')}`,
    },
    body: JSON.stringify({
      montant: 50000,
      dateValidite: '2000-01-01',
      documentUrl: 'https://files.example.com/devis.pdf',
    }),
  });

  assert.equal(response.status, 400);
  assert.equal(queried, false);
});

test('l’émission refuse les liens PDF non HTTPS et les montants invalides', async () => {
  let queried = false;
  pool.query = async () => {
    queried = true;
    return { rows: [] };
  };

  const response = await fetch(`${baseUrl}/5/offre`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${tokenFor('admin')}`,
    },
    body: JSON.stringify({
      montant: 0,
      dateValidite: dateInDays(7),
      documentUrl: 'http://files.example.com/devis.pdf',
    }),
  });

  assert.equal(response.status, 400);
  assert.equal(queried, false);
});

test('seul le propriétaire connecté peut accepter une offre active', async () => {
  let updateParams;
  pool.query = async (query, params) => {
    if (/UPDATE devis/.test(query)) {
      assert.match(query, /user_id = \$3/);
      assert.match(query, /date_validite >=/);
      updateParams = params;
      return { rows: [{ id: 5 }] };
    }
    if (/SELECT d\.\*/.test(query)) {
      return { rows: [devisRow({ statut: 'acceptee', client_repondu_at: '2026-10-08T10:00:00.000Z' })] };
    }
    throw new Error(`Requête inattendue: ${query}`);
  };

  const response = await fetch(`${baseUrl}/5/reponse`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${tokenFor('client', 42)}`,
    },
    body: JSON.stringify({ decision: 'acceptee' }),
  });
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.deepEqual(updateParams, ['acceptee', '5', 42]);
  assert.equal(body.devis.statut, 'acceptee');
});

test('un client ne peut pas répondre au devis d’un autre compte', async () => {
  pool.query = async (query) => {
    if (/UPDATE devis/.test(query)) return { rows: [] };
    if (/SELECT user_id, statut, date_validite/.test(query)) {
      return { rows: [{ user_id: 84, statut: 'envoye', date_validite: dateInDays(7) }] };
    }
    throw new Error(`Requête inattendue: ${query}`);
  };

  const response = await fetch(`${baseUrl}/5/reponse`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${tokenFor('client', 42)}`,
    },
    body: JSON.stringify({ decision: 'acceptee' }),
  });

  assert.equal(response.status, 404);
});

test('une offre expirée ne peut plus être acceptée ou refusée', async () => {
  pool.query = async (query) => {
    if (/UPDATE devis/.test(query)) return { rows: [] };
    if (/SELECT user_id, statut, date_validite/.test(query)) {
      return { rows: [{ user_id: 42, statut: 'envoye', date_validite: '2000-01-01' }] };
    }
    throw new Error(`Requête inattendue: ${query}`);
  };

  const response = await fetch(`${baseUrl}/5/reponse`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${tokenFor('client', 42)}`,
    },
    body: JSON.stringify({ decision: 'refusee' }),
  });
  const body = await response.json();

  assert.equal(response.status, 409);
  assert.match(body.error, /expirée/);
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

test('l’admin ne peut pas simuler l’émission ou la décision du client par le suivi', async () => {
  let queried = false;
  pool.query = async () => {
    queried = true;
    throw new Error('aucune mutation ne doit avoir lieu');
  };

  for (const statut of ['envoye', 'acceptee', 'refusee']) {
    const response = await fetch(`${baseUrl}/5/statut`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenFor('admin')}`,
      },
      body: JSON.stringify({ statut }),
    });
    assert.equal(response.status, 400);
  }
  assert.equal(queried, false);
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
