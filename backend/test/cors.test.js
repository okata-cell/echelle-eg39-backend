const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  buildCorsOptions,
  parseAllowedOrigins,
  securityWarnings,
} = require('../src/config/cors');

function originAllowed(options, origin) {
  return new Promise((resolve) => {
    options.origin(origin, (_error, allowed) => resolve(allowed));
  });
}

test('ALLOWED_ORIGINS est découpé et nettoyé', () => {
  assert.deepEqual(
    parseAllowedOrigins({
      ALLOWED_ORIGINS: 'https://app.test, http://localhost:3000 ,',
    }),
    ['https://app.test', 'http://localhost:3000'],
  );
});

test('en production, seules les origines listées sont acceptées', async () => {
  const options = buildCorsOptions({
    NODE_ENV: 'production',
    ALLOWED_ORIGINS: 'https://app.test',
  });

  assert.equal(await originAllowed(options, 'https://app.test'), true);
  assert.equal(await originAllowed(options, 'https://pirate.test'), false);
  // Les applications mobiles n’envoient pas d’en-tête Origin.
  assert.equal(await originAllowed(options, undefined), true);
});

test('en production sans ALLOWED_ORIGINS, aucune origine navigateur ne passe', async () => {
  const options = buildCorsOptions({ NODE_ENV: 'production' });

  assert.equal(await originAllowed(options, 'https://app.test'), false);
  assert.equal(await originAllowed(options, undefined), true);
});

test('en développement, l’absence de liste reste permissive', async () => {
  const options = buildCorsOptions({ NODE_ENV: 'development' });

  assert.equal(await originAllowed(options, 'http://localhost:3000'), true);
});

test('les avertissements signalent les secrets manquants en production', () => {
  assert.deepEqual(securityWarnings({ NODE_ENV: 'development' }), []);

  const missing = securityWarnings({ NODE_ENV: 'production' });
  assert.equal(missing.length, 2);
  assert.ok(missing.some((warning) => warning.includes('JWT_SECRET')));
  assert.ok(missing.some((warning) => warning.includes('ALLOWED_ORIGINS')));

  const shortSecret = securityWarnings({
    NODE_ENV: 'production',
    JWT_SECRET: 'court',
    ALLOWED_ORIGINS: 'https://app.test',
  });
  assert.equal(shortSecret.length, 1);
  assert.match(shortSecret[0], /moins de 32 caractères/);
});
