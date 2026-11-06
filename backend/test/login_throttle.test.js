const assert = require('node:assert/strict');
const { test } = require('node:test');

const { createLoginThrottle } = require('../src/middleware/login_throttle');

function requestFor(identifier, ip = '196.0.0.1') {
  return { ip, body: { identifier } };
}

test('bloque après le nombre d’essais autorisé', () => {
  let clock = 0;
  const throttle = createLoginThrottle({
    maxAttempts: 3,
    windowMs: 60_000,
    now: () => clock,
  });
  const request = requestFor('Admin@Echelle-EG39.com');

  for (let attempt = 0; attempt < 3; attempt += 1) {
    assert.equal(throttle.retryAfterSeconds(request), 0);
    throttle.registerFailure(request);
  }

  assert.equal(throttle.retryAfterSeconds(request), 60);
});

test('un autre identifiant ou une autre IP n’est pas pénalisé', () => {
  let clock = 0;
  const throttle = createLoginThrottle({
    maxAttempts: 2,
    windowMs: 60_000,
    now: () => clock,
  });
  const blocked = requestFor('admin@echelle-eg39.com');

  throttle.registerFailure(blocked);
  throttle.registerFailure(blocked);

  assert.ok(throttle.retryAfterSeconds(blocked) > 0);
  assert.equal(throttle.retryAfterSeconds(requestFor('client@test.com')), 0);
  assert.equal(
    throttle.retryAfterSeconds(requestFor('admin@echelle-eg39.com', '41.0.0.9')),
    0,
  );
});

test('la fenêtre expire et une connexion réussie remet le compteur à zéro', () => {
  let clock = 1_000;
  const throttle = createLoginThrottle({
    maxAttempts: 2,
    windowMs: 30_000,
    now: () => clock,
  });
  const request = requestFor('admin@echelle-eg39.com');

  throttle.registerFailure(request);
  throttle.registerFailure(request);
  assert.ok(throttle.retryAfterSeconds(request) > 0);

  clock += 30_001;
  assert.equal(throttle.retryAfterSeconds(request), 0);

  throttle.registerFailure(request);
  assert.equal(throttle.retryAfterSeconds(request), 0);

  throttle.reset(request);
  assert.equal(throttle.retryAfterSeconds(request), 0);
});
