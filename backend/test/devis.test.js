const assert = require('node:assert/strict');
const http = require('node:http');
const express = require('express');
const jwt = require('jsonwebtoken');
const { after, before, test } = require('node:test');

process.env.JWT_SECRET = 'test-only-devis-secret';

const pool = require('../src/config/database');
const devisPdfService = require('../src/services/devis_pdf_service');
const devisDocumentStorage = require('../src/services/devis_document_storage');
const devisRouter = require('../src/routes/devis');

const app = express();
app.use(express.json());
app.use('/api/devis', devisRouter);

let server;
let originalQuery;
let originalPdfGenerator;
let originalPutPrivatePdf;
let originalSignPrivatePdfGet;
let originalDeletePrivatePdf;
let baseUrl;

before(async () => {
  originalQuery = pool.query;
  originalPdfGenerator = devisPdfService.createDevisPdfBuffer;
  originalPutPrivatePdf = devisDocumentStorage.putPrivatePdf;
  originalSignPrivatePdfGet = devisDocumentStorage.signPrivatePdfGet;
  originalDeletePrivatePdf = devisDocumentStorage.deletePrivatePdf;
  server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}/api/devis`;
});

after(async () => {
  pool.query = originalQuery;
  devisPdfService.createDevisPdfBuffer = originalPdfGenerator;
  devisDocumentStorage.putPrivatePdf = originalPutPrivatePdf;
  devisDocumentStorage.signPrivatePdfGet = originalSignPrivatePdfGet;
  devisDocumentStorage.deletePrivatePdf = originalDeletePrivatePdf;
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
    document_storage_key: null,
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

test('l’admin génère une offre PDF et stocke uniquement sa clé R2', async () => {
  let offerParams;
  let generatedPdf;
  let uploaded;
  devisPdfService.createDevisPdfBuffer = async (input) => {
    generatedPdf = input;
    return Buffer.from('%PDF-test');
  };
  devisDocumentStorage.putPrivatePdf = async (...args) => { uploaded = args; };
  devisDocumentStorage.signPrivatePdfGet = async (key) => ({
    url: `https://account.r2.cloudflarestorage.com/private/${encodeURIComponent(key)}?X-Amz-Signature=test`,
    expiresAt: '2026-10-08T12:55:00.000Z',
  });
  pool.query = async (query, params) => {
    if (/SELECT d\.\*/.test(query)) {
      return { rows: [devisRow()] };
    }
    if (/UPDATE devis/.test(query)) {
      assert.match(query, /document_url = NULL/);
      assert.match(query, /document_storage_key = \$3/);
      assert.match(query, /IS NOT DISTINCT FROM \$7/);
      offerParams = params;
      return {
        rows: [devisRow({
          statut: 'envoye',
          montant: '125000',
          date_validite: dateInDays(7),
          document_storage_key: params[2],
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
      commentaireAdmin: 'Offre valable jusqu’à la date indiquée.',
    }),
  });
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(generatedPdf.montant, 125000);
  assert.equal(generatedPdf.devis.id, 5);
  assert.equal(uploaded[0], offerParams[2]);
  assert.match(uploaded[0], /^devis\/5\/offers\/.+\.pdf$/);
  assert.deepEqual(uploaded[1], Buffer.from('%PDF-test'));
  assert.equal(offerParams[0], 125000);
  assert.equal(offerParams[4], '5');
  assert.equal(offerParams[5], 'en_attente');
  assert.equal(body.devis.statut, 'envoye');
  assert.equal(body.devis.montant, '125000');
  assert.equal(body.devis.documentDisponible, true);
  assert.equal(body.devis.documentUrlExpiresAt, '2026-10-08T12:55:00.000Z');
  assert.equal(response.headers.get('cache-control'), 'private, no-store');
});

test('une panne R2 ne met pas l’offre au statut envoyé', async () => {
  let updated = false;
  devisPdfService.createDevisPdfBuffer = async () => Buffer.from('%PDF-test');
  devisDocumentStorage.putPrivatePdf = async () => {
    throw new Error('R2 inaccessible');
  };
  pool.query = async (query) => {
    if (/SELECT d\.\*/.test(query)) return { rows: [devisRow()] };
    if (/UPDATE devis/.test(query)) updated = true;
    throw new Error(`Requête inattendue: ${query}`);
  };

  const response = await fetch(`${baseUrl}/5/offre`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${tokenFor('admin')}`,
    },
    body: JSON.stringify({ montant: 125000, dateValidite: dateInDays(7) }),
  });

  assert.equal(response.status, 503);
  assert.equal(updated, false);
});

test('sans configuration R2, l’émission renvoie une erreur explicite sans mise à jour SQL', async () => {
  let updated = false;
  devisPdfService.createDevisPdfBuffer = async () => Buffer.from('%PDF-test');
  devisDocumentStorage.putPrivatePdf = async () => {
    const error = new Error('private details');
    error.code = 'R2_NOT_CONFIGURED';
    throw error;
  };
  pool.query = async (query) => {
    if (/SELECT d\.\*/.test(query)) return { rows: [devisRow()] };
    if (/UPDATE devis/.test(query)) updated = true;
    throw new Error(`Requête inattendue: ${query}`);
  };

  const response = await fetch(`${baseUrl}/5/offre`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${tokenFor('admin')}`,
    },
    body: JSON.stringify({ montant: 125000, dateValidite: dateInDays(7) }),
  });
  const body = await response.json();

  assert.equal(response.status, 503);
  assert.match(body.error, /stockage privé/);
  assert.equal(updated, false);
  assert.equal(JSON.stringify(body).includes('private details'), false);
});

test('un conflit SQL après upload supprime le PDF orphelin', async () => {
  let deletedKey;
  let updated = false;
  devisPdfService.createDevisPdfBuffer = async () => Buffer.from('%PDF-test');
  devisDocumentStorage.putPrivatePdf = async () => {};
  devisDocumentStorage.deletePrivatePdf = async (key) => { deletedKey = key; };
  pool.query = async (query) => {
    if (/SELECT d\.\*/.test(query)) return { rows: [devisRow()] };
    if (/UPDATE devis/.test(query)) {
      updated = true;
      return { rows: [] };
    }
    if (/SELECT id, user_id, statut, client_repondu_at/.test(query)) {
      return { rows: [devisRow({ statut: 'refusee' })] };
    }
    throw new Error(`Requête inattendue: ${query}`);
  };

  const response = await fetch(`${baseUrl}/5/offre`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${tokenFor('admin')}`,
    },
    body: JSON.stringify({ montant: 125000, dateValidite: dateInDays(7) }),
  });

  assert.equal(response.status, 409);
  assert.equal(updated, true);
  assert.match(deletedKey, /^devis\/5\/offers\/.+\.pdf$/);
});

test('le propriétaire peut obtenir un lien R2 temporaire sans cache', async () => {
  let signedKey;
  devisDocumentStorage.signPrivatePdfGet = async (key, id) => {
    signedKey = [key, id];
    return { url: 'https://account.r2.cloudflarestorage.com/private/file.pdf?sig=test', expiresAt: '2026-10-08T12:55:00.000Z' };
  };
  pool.query = async (query) => {
    assert.match(query, /document_storage_key/);
    return { rows: [{ id: 5, user_id: 42, document_url: null, document_storage_key: 'devis/5/offers/private.pdf' }] };
  };

  const response = await fetch(`${baseUrl}/5/document-url`, {
    headers: { Authorization: `Bearer ${tokenFor('client', 42)}` },
  });
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(response.headers.get('cache-control'), 'private, no-store');
  assert.deepEqual(signedKey, ['devis/5/offers/private.pdf', 5]);
  assert.equal(body.expiresAt, '2026-10-08T12:55:00.000Z');
  assert.match(body.url, /^https:\/\//);
});

test('la liste client conserve un lien signé court pour compatibilité mobile', async () => {
  devisDocumentStorage.signPrivatePdfGet = async () => ({
    url: 'https://account.r2.cloudflarestorage.com/private/file.pdf?sig=legacy-client',
    expiresAt: '2026-10-08T12:55:00.000Z',
  });
  pool.query = async () => ({
    rows: [devisRow({ document_storage_key: 'devis/5/offers/private.pdf' })],
  });

  const response = await fetch(`${baseUrl}/me`, {
    headers: { Authorization: `Bearer ${tokenFor('client', 42)}` },
  });
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(response.headers.get('cache-control'), 'private, no-store');
  assert.equal(body.devis[0].documentDisponible, true);
  assert.match(body.devis[0].documentUrl, /^https:\/\//);
  assert.equal(body.devis[0].documentUrlExpiresAt, '2026-10-08T12:55:00.000Z');
});

test('un autre client ne peut pas signer le document du devis', async () => {
  let signed = false;
  devisDocumentStorage.signPrivatePdfGet = async () => {
    signed = true;
    return { url: 'https://account.r2.cloudflarestorage.com/private/file.pdf?sig=test' };
  };
  pool.query = async () => ({
    rows: [{ id: 5, user_id: 84, document_url: null, document_storage_key: 'private.pdf' }],
  });

  const response = await fetch(`${baseUrl}/5/document-url`, {
    headers: { Authorization: `Bearer ${tokenFor('client', 42)}` },
  });

  assert.equal(response.status, 404);
  assert.equal(signed, false);
});

test('un rôle autre que client ne signe pas un document avec un userId correspondant', async () => {
  let signed = false;
  devisDocumentStorage.signPrivatePdfGet = async () => {
    signed = true;
    return { url: 'https://account.r2.cloudflarestorage.com/private/file.pdf?sig=test' };
  };
  pool.query = async () => ({
    rows: [{ id: 5, user_id: 42, document_url: null, document_storage_key: 'private.pdf' }],
  });

  const response = await fetch(`${baseUrl}/5/document-url`, {
    headers: { Authorization: `Bearer ${tokenFor('support', 42)}` },
  });

  assert.equal(response.status, 404);
  assert.equal(signed, false);
});

test('les anciens devis conservent leur lien externe après contrôle de propriété', async () => {
  pool.query = async () => ({
    rows: [{
      id: 5,
      user_id: 42,
      document_url: 'https://legacy.example.com/devis-5.pdf',
      document_storage_key: null,
    }],
  });

  const response = await fetch(`${baseUrl}/5/document-url`, {
    headers: { Authorization: `Bearer ${tokenFor('client', 42)}` },
  });
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.url, 'https://legacy.example.com/devis-5.pdf');
  assert.equal(body.expiresAt, null);
});

test('la suppression admin nettoie la clé R2 après suppression en base', async () => {
  let deletedKey;
  devisDocumentStorage.deletePrivatePdf = async (key) => { deletedKey = key; };
  pool.query = async (query) => {
    assert.match(query, /DELETE FROM devis/);
    assert.match(query, /RETURNING id, document_storage_key/);
    return { rows: [{ id: 5, document_storage_key: 'devis/5/offers/old.pdf' }] };
  };

  const response = await fetch(`${baseUrl}/5`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${tokenFor('admin')}` },
  });

  assert.equal(response.status, 200);
  assert.equal(deletedKey, 'devis/5/offers/old.pdf');
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
    }),
  });

  assert.equal(response.status, 400);
  assert.equal(queried, false);
});

test('l’émission refuse les montants invalides', async () => {
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
