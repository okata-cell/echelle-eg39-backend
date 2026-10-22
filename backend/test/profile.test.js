const assert = require('node:assert/strict');
const http = require('node:http');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { after, before, test } = require('node:test');

process.env.JWT_SECRET = 'test-only-profile-secret';

const pool = require('../src/config/database');
const app = require('../src/server');

let server;
let originalQuery;
let originalConnect;
let baseUrl;

before(async () => {
  originalQuery = pool.query;
  originalConnect = pool.connect;
  server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}/api/profile`;
});

after(async () => {
  pool.query = originalQuery;
  pool.connect = originalConnect;
  if (server) await new Promise((resolve) => server.close(resolve));
  await pool.end();
});

function tokenFor(role = 'client', userId = 42, extra = {}) {
  return jwt.sign({ userId, role, ...extra }, process.env.JWT_SECRET);
}

function row(overrides = {}) {
  return {
    id: 42,
    first_name: 'Afi',
    last_name: 'Koffi',
    email: 'afi@example.com',
    phone: '+22890000000',
    role: 'client',
    created_at: '2026-10-18T00:00:00.000Z',
    avatar_data: null,
    avatar_mime_type: null,
    entreprise: 'EG39',
    adresse: 'Aflao Gagli',
    ville: 'Lomé',
    pays: 'Togo',
    ...overrides,
  };
}

function request(path, { method = 'GET', token = tokenFor(), body } = {}) {
  return fetch(`${baseUrl}${path}`, {
    method,
    headers: {
      ...(body ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
}

function fakeTransactionClient(handler) {
  const calls = [];
  return {
    calls,
    client: {
      async query(query, params = []) {
        calls.push({ query, params });
        return handler(query, params);
      },
      release() {},
    },
  };
}

test('la route /me exige une session et refuse les jetons de réinitialisation', async () => {
  assert.equal((await request('/me', { token: null })).status, 401);
  assert.equal((await request('/me', {
    token: tokenFor('client', 42, { type: 'password_reset' }),
  })).status, 401);
});

test('GET /me renvoie uniquement le profil du compte authentifié', async () => {
  let params;
  pool.query = async (query, queryParams) => {
    assert.match(query, /LEFT JOIN clients/);
    assert.doesNotMatch(query, /password_hash/);
    params = queryParams;
    return { rows: [row()] };
  };

  const response = await request('/me');
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('cache-control'), 'no-store');
  assert.deepEqual(params, [42]);
  assert.equal(body.profile.firstName, 'Afi');
  assert.equal(body.profile.company, 'EG39');
  assert.equal(body.profile.city, 'Lomé');
  assert.equal(body.profile.avatarData, null);
  assert.equal('password_hash' in body.profile, false);
});

test('PATCH /me sauvegarde le profil et les coordonnées dans une transaction', async () => {
  const fake = fakeTransactionClient((query) => {
    if (/^(BEGIN|COMMIT|ROLLBACK)$/.test(query.trim())) return { rows: [] };
    if (/SELECT id, email, phone/.test(query)) return { rows: [row()] };
    if (/SELECT id FROM users/.test(query)) return { rows: [] };
    if (/UPDATE users/.test(query) || /INSERT INTO clients/.test(query)) return { rows: [] };
    if (/LEFT JOIN clients/.test(query)) {
      return { rows: [row({ first_name: 'Ama', last_name: 'Mensah', entreprise: 'Topos', adresse: 'Rue 1' })] };
    }
    throw new Error(`Requête inattendue: ${query}`);
  });
  pool.connect = async () => fake.client;
  pool.query = async () => { throw new Error('La sauvegarde doit utiliser une transaction'); };

  const response = await request('/me', {
    method: 'PATCH',
    body: {
      firstName: 'Ama', lastName: 'Mensah', email: 'afi@example.com',
      phone: '+22890000000', company: 'Topos', address: 'Rue 1', city: 'Lomé', country: 'Togo',
    },
  });
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.equal(body.profile.firstName, 'Ama');
  assert.equal(body.profile.company, 'Topos');
  assert.equal(typeof body.token, 'string');
  assert.deepEqual(fake.calls.map((call) => call.query.trim().split(/\s+/)[0]), [
    'BEGIN', 'SELECT', 'SELECT', 'UPDATE', 'INSERT', 'SELECT', 'COMMIT',
  ]);
});

test('modifier e-mail ou téléphone exige le mot de passe courant', async () => {
  const passwordHash = await bcrypt.hash('Current123', 4);
  const fake = fakeTransactionClient((query) => {
    if (/^(BEGIN|COMMIT|ROLLBACK)$/.test(query.trim())) return { rows: [] };
    if (/SELECT id, email, phone/.test(query)) return { rows: [row({ password_hash: passwordHash })] };
    throw new Error(`Aucune écriture attendue: ${query}`);
  });
  pool.connect = async () => fake.client;

  const response = await request('/me', {
    method: 'PATCH',
    body: {
      firstName: 'Afi', lastName: 'Koffi', email: 'new@example.com',
      phone: '+22890000000', company: 'EG39', address: 'Aflao Gagli', city: 'Lomé',
      country: 'Togo', currentPassword: 'Wrong123',
    },
  });
  const body = await response.json();
  assert.equal(response.status, 401);
  assert.match(body.error, /Mot de passe actuel/);
  assert.equal(fake.calls.some((call) => /UPDATE users/.test(call.query)), false);
});

test('le changement de mot de passe vérifie le mot de passe actuel', async () => {
  const passwordHash = await bcrypt.hash('Current123', 4);
  let updatedHash;
  pool.query = async (query, params) => {
    if (/SELECT password_hash/.test(query)) return { rows: [{ password_hash: passwordHash }] };
    if (/UPDATE users SET password_hash/.test(query)) { updatedHash = params[0]; return { rows: [] }; }
    throw new Error(`Requête inattendue: ${query}`);
  };

  assert.equal((await request('/password', {
    method: 'POST', body: { currentPassword: 'wrong', newPassword: 'Newpass123' },
  })).status, 401);
  const valid = await request('/password', {
    method: 'POST', body: { currentPassword: 'Current123', newPassword: 'Newpass123' },
  });
  assert.equal(valid.status, 200);
  assert.equal(await bcrypt.compare('Newpass123', updatedHash), true);
});

test('les avatars acceptent uniquement des octets image valides de moins de 1 Mo', async () => {
  const png = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  pool.query = async (query, params) => {
    if (/UPDATE users SET avatar_data/.test(query)) {
      assert.deepEqual(params.slice(0, 2), [png, 'image/png']);
      return { rows: [{ id: 42 }] };
    }
    if (/LEFT JOIN clients/.test(query)) return { rows: [row({ avatar_data: png, avatar_mime_type: 'image/png' })] };
    throw new Error(`Requête inattendue: ${query}`);
  };

  const invalid = await request('/me/avatar', {
    method: 'PUT', body: { image: { mimeType: 'image/png', data: Buffer.from('not png').toString('base64') } },
  });
  assert.equal(invalid.status, 400);
  const valid = await request('/me/avatar', {
    method: 'PUT', body: { image: { mimeType: 'image/png', data: png.toString('base64') } },
  });
  assert.equal(valid.status, 200);
  assert.equal((await valid.json()).profile.avatarMimeType, 'image/png');
});

test('les signalements sont persistants et la file admin est protégée', async () => {
  const fake = fakeTransactionClient((query) => {
    if (/^(BEGIN|COMMIT|ROLLBACK)$/.test(query.trim())) return { rows: [] };
    if (/INSERT INTO profile_support_messages/.test(query)) return { rows: [{ id: 8, created_at: '2026-10-18T00:00:00.000Z' }] };
    throw new Error(`Requête inattendue: ${query}`);
  });
  pool.connect = async () => fake.client;

  const support = await request('/support-messages', {
    method: 'POST', body: { message: 'Mon appareil ne démarre pas.', attachments: [] },
  });
  assert.equal(support.status, 201);
  assert.equal((await request('/admin/support-messages', { token: tokenFor('client') })).status, 403);
});

test('les intérêts de formation et évaluations enregistrent les valeurs validées', async () => {
  const queries = [];
  pool.query = async (query, params) => {
    queries.push({ query, params });
    if (/INSERT INTO profile_training_interests/.test(query)) return { rows: [{ id: 4, status: 'nouveau', created_at: 'now' }] };
    if (/INSERT INTO profile_app_ratings/.test(query)) return { rows: [{ id: 5, rating: params[1], comment: params[2] }] };
    throw new Error(`Requête inattendue: ${query}`);
  };

  assert.equal((await request('/training-interests', {
    method: 'POST', body: { trainingName: 'Initiation GPS', message: 'Merci de me recontacter.' },
  })).status, 201);
  assert.equal((await request('/training-interests', {
    method: 'POST', body: { trainingName: 'Session inventée' },
  })).status, 400);
  assert.equal((await request('/ratings', {
    method: 'POST', body: { rating: 4, comment: 'Application utile.' },
  })).status, 201);
  assert.equal(queries.some((query) => /INSERT INTO profile_app_ratings/.test(query.query)), true);
});
