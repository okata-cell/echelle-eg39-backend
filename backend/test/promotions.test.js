const assert = require('node:assert/strict');
const http = require('node:http');
const express = require('express');
const jwt = require('jsonwebtoken');
const { after, before, test } = require('node:test');

process.env.JWT_SECRET = 'test-only-promotions-secret';

const pool = require('../src/config/database');
const firebaseStorage = require('../src/services/firebase_storage');
const promotionsRouter = require('../src/routes/promotions');

const app = express();
app.use(express.json());
app.use('/api/promotions', promotionsRouter);

let server;
let baseUrl;
let originalQuery;
let originalUpload;
let originalDelete;

before(async () => {
  originalQuery = pool.query;
  originalUpload = firebaseStorage.uploadPromotionImage;
  originalDelete = firebaseStorage.deletePromotionImage;
  server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}/api/promotions`;
});

after(async () => {
  pool.query = originalQuery;
  firebaseStorage.uploadPromotionImage = originalUpload;
  firebaseStorage.deletePromotionImage = originalDelete;
  if (server) await new Promise((resolve) => server.close(resolve));
  await pool.end();
});

function tokenFor(role = 'client', userId = 42) {
  return jwt.sign({ userId, role }, process.env.JWT_SECRET);
}

function promotionRow(overrides = {}) {
  return {
    id: 18,
    titre: 'Offre du moment',
    description: 'Remise spéciale sur les GPS',
    image_url: 'https://images.example.com/promo.png',
    image_storage_path: 'promotions/banner.png',
    date_debut: '2026-10-01',
    date_fin: '2026-10-31',
    actif: true,
    frequence: 'une_fois_par_jour',
    created_at: '2026-10-01T09:00:00.000Z',
    ...overrides,
  };
}

function apiRequest(path, { method = 'GET', role, userId = 42, body, image } = {}) {
  const headers = {};
  if (role) headers.Authorization = `Bearer ${tokenFor(role, userId)}`;
  if (image) {
    const form = new FormData();
    form.append('image', new Blob([image.bytes], { type: image.contentType }), image.name);
    return fetch(`${baseUrl}${path}`, { method, headers, body: form });
  }
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  return fetch(`${baseUrl}${path}`, {
    method,
    headers,
    ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
  });
}

const pngHeader = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

test('la route publique renvoie null quand aucune promotion n’est active', async () => {
  let params;
  pool.query = async (query, values) => {
    assert.match(query, /FROM promotions/);
    assert.match(query, /date_debut <= \$1/);
    assert.match(query, /date_fin >= \$1/);
    params = values;
    return { rows: [] };
  };

  const response = await apiRequest('/active');
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { promotion: null });
  assert.match(params[0], /^\d{4}-\d{2}-\d{2}$/);
});

test('la création fixe le titre et conserve switch et fréquence sélectionnés', async () => {
  let capturedParams;
  pool.query = async (query, params) => {
    assert.match(query, /INSERT INTO promotions/);
    assert.match(query, /image_storage_path/);
    capturedParams = params;
    return { rows: [promotionRow()] };
  };

  const response = await apiRequest('/', {
    method: 'POST',
    role: 'admin',
    body: {
      titre: 'Ce titre client doit être ignoré',
      description: 'Remise spéciale sur les GPS',
      image_url: 'https://images.example.com/promo.png',
      image_storage_path: 'promotions/banner.png',
      date_debut: '2026-10-01',
      date_fin: '2026-10-31',
      actif: false,
      frequence: 'une_seule_fois',
    },
  });
  const body = await response.json();

  assert.equal(response.status, 201);
  assert.equal(capturedParams[0], 'Offre du moment');
  assert.equal(capturedParams[5], '2026-10-31');
  assert.equal(capturedParams[6], false);
  assert.equal(capturedParams[7], 'une_seule_fois');
  assert.equal(body.promotion.id, 18);
});

test('la création refuse une période inversée et une fréquence inconnue', async () => {
  pool.query = async () => { throw new Error('Aucune écriture ne doit être faite'); };
  const base = {
    description: 'Remise spéciale sur les GPS',
    date_debut: '2026-10-20',
    date_fin: '2026-10-21',
  };

  const reversed = await apiRequest('/', {
    method: 'POST',
    role: 'admin',
    body: { ...base, date_debut: '2026-10-22' },
  });
  assert.equal(reversed.status, 400);

  const invalidFrequency = await apiRequest('/', {
    method: 'POST',
    role: 'admin',
    body: { ...base, frequence: 'chaque_seconde' },
  });
  assert.equal(invalidFrequency.status, 400);
});

test('l’upload photo est réservé à un admin authentifié', async () => {
  const anonymous = await apiRequest('/image', {
    method: 'POST',
    image: { bytes: pngHeader, contentType: 'image/png', name: 'banner.png' },
  });
  assert.equal(anonymous.status, 401);

  const client = await apiRequest('/image', {
    method: 'POST',
    role: 'client',
    image: { bytes: pngHeader, contentType: 'image/png', name: 'banner.png' },
  });
  assert.equal(client.status, 403);
});

test('l’upload refuse un contenu dont la signature ne correspond pas au MIME', async () => {
  let uploads = 0;
  firebaseStorage.uploadPromotionImage = async () => {
    uploads++;
    return { imageUrl: 'https://images.example.com/banner.png', storagePath: 'promotions/banner.png' };
  };

  const response = await apiRequest('/image', {
    method: 'POST',
    role: 'admin',
    image: { bytes: Buffer.from('ceci n’est pas une image'), contentType: 'image/png', name: 'banner.png' },
  });
  assert.equal(response.status, 415);
  assert.equal(uploads, 0);
});

test('l’upload admin renvoie l’URL et le chemin Storage de la photo', async () => {
  let uploadedBuffer;
  let uploadedType;
  firebaseStorage.uploadPromotionImage = async (buffer, contentType) => {
    uploadedBuffer = buffer;
    uploadedType = contentType;
    return {
      imageUrl: 'https://firebasestorage.googleapis.com/promo.png?token=test',
      storagePath: 'promotions/generated.png',
    };
  };

  const response = await apiRequest('/image', {
    method: 'POST',
    role: 'admin',
    image: { bytes: pngHeader, contentType: 'image/png', name: 'banner.png' },
  });
  const body = await response.json();

  assert.equal(response.status, 201);
  assert.equal(uploadedType, 'image/png');
  assert.deepEqual(uploadedBuffer, pngHeader);
  assert.equal(body.storagePath, 'promotions/generated.png');
  assert.match(body.imageUrl, /^https:\/\//);
});

test('l’upload signale une configuration Firebase absente', async () => {
  firebaseStorage.uploadPromotionImage = async () => {
    const error = new Error('not configured');
    error.code = 'FIREBASE_STORAGE_NOT_CONFIGURED';
    throw error;
  };

  const response = await apiRequest('/image', {
    method: 'POST',
    role: 'admin',
    image: { bytes: pngHeader, contentType: 'image/png', name: 'banner.png' },
  });
  const body = await response.json();

  assert.equal(response.status, 503);
  assert.equal(body.code, 'FIREBASE_STORAGE_NOT_CONFIGURED');
});

test('la suppression retire aussi la photo associée au Storage', async () => {
  let deletedPath;
  pool.query = async (query, params) => {
    assert.match(query, /DELETE FROM promotions/);
    assert.deepEqual(params, ['18']);
    return { rows: [promotionRow()] };
  };
  firebaseStorage.deletePromotionImage = async (path) => {
    deletedPath = path;
  };

  const response = await apiRequest('/18', { method: 'DELETE', role: 'admin' });
  assert.equal(response.status, 200);
  assert.equal(deletedPath, 'promotions/banner.png');
});
