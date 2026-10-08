const assert = require('node:assert/strict');
const { test } = require('node:test');

const storage = require('../src/services/devis_document_storage');

const R2_KEYS = [
  'R2_ACCOUNT_ID',
  'R2_ACCESS_KEY_ID',
  'R2_SECRET_ACCESS_KEY',
  'R2_BUCKET_NAME',
];

function withR2Env(values, run) {
  const previous = Object.fromEntries(R2_KEYS.map((key) => [key, process.env[key]]));
  for (const key of R2_KEYS) {
    if (values[key] == null) delete process.env[key];
    else process.env[key] = values[key];
  }
  return Promise.resolve()
    .then(run)
    .finally(() => {
      for (const key of R2_KEYS) {
        if (previous[key] == null) delete process.env[key];
        else process.env[key] = previous[key];
      }
    });
}

test('le stockage échoue explicitement lorsque les secrets R2 manquent', async () => {
  await withR2Env({}, async () => {
    await assert.rejects(
      storage.signPrivatePdfGet('devis/5/offers/private.pdf', 5),
      (error) => error.code === 'R2_NOT_CONFIGURED',
    );
  });
});

test('signe une URL HTTPS d’objet privé avec une expiration courte', async () => {
  await withR2Env({
    R2_ACCOUNT_ID: 'test-account',
    R2_ACCESS_KEY_ID: 'test-access-key',
    R2_SECRET_ACCESS_KEY: 'test-secret-key',
    R2_BUCKET_NAME: 'private-quotes',
  }, async () => {
    const before = Date.now();
    const signed = await storage.signPrivatePdfGet('devis/5/offers/private.pdf', 5);
    const expiry = Date.parse(signed.expiresAt);
    const url = new URL(signed.url);

    assert.equal(url.protocol, 'https:');
    assert.equal(url.hostname, 'private-quotes.test-account.r2.cloudflarestorage.com');
    assert.equal(url.pathname, '/devis/5/offers/private.pdf');
    assert.equal(url.searchParams.get('X-Amz-Expires'), '300');
    assert.ok(expiry >= before + 299_000);
    assert.ok(expiry <= Date.now() + 301_000);
    assert.equal(url.searchParams.get('response-cache-control'), 'private, no-store');
  });
});
