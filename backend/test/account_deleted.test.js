const assert = require('node:assert/strict');
const http = require('node:http');
const express = require('express');
const jwt = require('jsonwebtoken');
const { after, before, beforeEach, test } = require('node:test');

process.env.JWT_SECRET = 'test-engine-only-account-deleted-secret';

const pool = require('../src/config/database');
const authRouter = require('../src/routes/auth');
const { authMiddleware } = require('../src/middleware/auth');
const {
  revokeAccount,
  restoreAccount,
  clearRevokedAccounts,
} = require('../src/services/session_revocation');
const { hashIdentifier } = require('../src/utils/identifier_hash');

const app = express();
app.use(express.json());
app.use('/api/auth', authRouter);

const guardedApp = express();
guardedApp.get('/protege', authMiddleware, (req, res) => res.json({ ok: true }));

let server;
let guardedServer;
let loginUrl;
let guardedUrl;
let originalQuery;

function listen(instance) {
  return new Promise((resolve) => {
    instance.listen(0, '127.0.0.1', () => {
      resolve(`http://127.0.0.1:${instance.address().port}`);
    });
  });
}

before(async () => {
  originalQuery = pool.query;
  server = http.createServer(app);
  guardedServer = http.createServer(guardedApp);
  loginUrl = `${await listen(server)}/api/auth/login`;
  guardedUrl = `${await listen(guardedServer)}/protege`;
});

after(async () => {
  pool.query = originalQuery;
  await new Promise((resolve) => server.close(resolve));
  await new Promise((resolve) => guardedServer.close(resolve));
  await pool.end();
});

beforeEach(() => {
  clearRevokedAccounts();
});

function stubLogin({ userRows = [], deletedMatch = false } = {}) {
  pool.query = async (sql) => {
    if (/deleted_email_hash = ANY/.test(sql)) {
      return { rows: deletedMatch ? [{ id: 12 }] : [] };
    }
    if (/FROM users WHERE LOWER\(email\)/.test(sql)) {
      return { rows: userRows };
    }
    throw new Error(`Requête inattendue : ${sql}`);
  };
}

function login(identifier, password = '1234AZER') {
  return fetch(loginUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ identifier, password }),
  });
}

test('un ancien identifiant supprimé répond 403 ACCOUNT_DELETED', async () => {
  stubLogin({ deletedMatch: true });

  const response = await login('afi@example.com');
  const payload = await response.json();

  assert.equal(response.status, 403);
  assert.equal(payload.code, 'ACCOUNT_DELETED');
  assert.equal(
    payload.error,
    'Ce compte a été supprimé. Vous pouvez en créer un nouveau.',
  );
});

test('la reconnaissance passe par des empreintes, jamais par les coordonnées', async () => {
  const searched = [];
  pool.query = async (sql, values) => {
    if (/deleted_email_hash = ANY/.test(sql)) {
      searched.push(values[0]);
      return { rows: [{ id: 12 }] };
    }
    return { rows: [] };
  };

  await login('Afi@Example.com');
  await login('90 00 00 00');

  assert.equal(searched.length, 2);
  const [byEmail, byPhone] = searched;

  assert.ok(byEmail.includes(hashIdentifier('afi@example.com')));
  assert.ok(byPhone.includes(hashIdentifier('+22890000000')));

  // Aucune coordonnée en clair n'est transmise à la base.
  for (const values of searched) {
    assert.equal(values.includes('afi@example.com'), false);
    assert.equal(values.includes('+22890000000'), false);
  }
});

test('un identifiant réellement inconnu reste 401 IDENTIFIER_NOT_FOUND', async () => {
  stubLogin({ deletedMatch: false });

  const response = await login('inconnu@example.com');
  const payload = await response.json();

  assert.equal(response.status, 401);
  assert.equal(payload.code, 'IDENTIFIER_NOT_FOUND');
});

test('une ligne marquée supprimée ne peut pas ouvrir de session', async () => {
  stubLogin({
    userRows: [
      {
        id: 12,
        email: 'supprime+12@echelle-eg39.invalid',
        phone: '+0000012',
        role: 'client',
        password_hash: '$2a$10$abcdefghijklmnopqrstuv',
        deleted_at: '2026-11-06T22:00:00.000Z',
      },
    ],
  });

  const response = await login('supprime+12@echelle-eg39.invalid');
  const payload = await response.json();

  assert.equal(response.status, 403);
  assert.equal(payload.code, 'ACCOUNT_DELETED');
});

test('répéter la tentative ne verrouille pas la connexion', async () => {
  stubLogin({ deletedMatch: true });

  for (let attempt = 0; attempt < 10; attempt += 1) {
    const response = await login('afi@example.com');
    assert.equal(response.status, 403);
  }
});

test('le jeton d’un compte supprimé est refusé immédiatement', async () => {
  const token = jwt.sign({ userId: 12, role: 'client' }, process.env.JWT_SECRET);

  revokeAccount(12, 'deleted');

  const refused = await fetch(guardedUrl, {
    headers: { Authorization: `Bearer ${token}` },
  });
  const payload = await refused.json();

  assert.equal(refused.status, 401);
  assert.equal(payload.code, 'SESSION_REVOKED');

  // Réactivation par l'administration : la session redevient utilisable.
  restoreAccount(12);

  const accepted = await fetch(guardedUrl, {
    headers: { Authorization: `Bearer ${token}` },
  });
  assert.equal(accepted.status, 200);
});

test('un jeton visiteur reste refusé sur une route protégée', async () => {
  const response = await fetch(guardedUrl);
  assert.equal(response.status, 401);
});
