const assert = require('node:assert/strict');
const { test } = require('node:test');

const { createLoginThrottle, DEFAULTS } = require('../src/middleware/login_throttle');

function requestFor(identifier, ip = '196.0.0.1') {
  return { ip, body: { identifier } };
}

const HEURE = 60 * 60 * 1000;

test('quatre échecs bloquent le compte pendant 24 heures', () => {
  let clock = 0;
  const throttle = createLoginThrottle({ now: () => clock });
  const request = requestFor('Client@Example.com');

  // Trois échecs : la connexion reste possible.
  for (let attempt = 0; attempt < 3; attempt += 1) {
    assert.equal(throttle.retryAfterSeconds(request), 0);
    throttle.registerFailure(request);
  }
  assert.equal(throttle.retryAfterSeconds(request), 0);

  // Le quatrième déclenche le blocage, décompté depuis cet essai.
  clock = 2 * HEURE;
  throttle.registerFailure(request);
  assert.equal(throttle.retryAfterSeconds(request), 24 * 3600);

  clock = 2 * HEURE + 23 * HEURE;
  assert.equal(throttle.retryAfterSeconds(request), 3600);

  clock = 2 * HEURE + 24 * HEURE + 1;
  assert.equal(throttle.retryAfterSeconds(request), 0);
});

test('le blocage suit le compte, pas l’appareil', () => {
  let clock = 0;
  const throttle = createLoginThrottle({ now: () => clock });
  const vise = requestFor('client@example.com', '196.0.0.1');

  for (let attempt = 0; attempt < DEFAULTS.maxAttempts; attempt += 1) {
    throttle.registerFailure(vise);
  }

  // Même compte depuis une autre adresse : toujours bloqué.
  assert.ok(
    throttle.retryAfterSeconds(
      requestFor('CLIENT@example.com', '41.0.0.9'),
    ) > 0,
  );

  // Un autre compte depuis la même adresse n'est pas pénalisé.
  assert.equal(
    throttle.retryAfterSeconds(requestFor('autre@example.com', '196.0.0.1')),
    0,
  );
});

test('une connexion réussie remet le compteur à zéro', () => {
  let clock = 0;
  const throttle = createLoginThrottle({ now: () => clock });
  const request = requestFor('client@example.com');

  throttle.registerFailure(request);
  throttle.registerFailure(request);
  throttle.registerFailure(request);
  throttle.reset(request);

  // Le compteur repart de zéro : trois nouveaux échecs ne suffisent pas.
  for (let attempt = 0; attempt < 3; attempt += 1) {
    throttle.registerFailure(request);
  }
  assert.equal(throttle.retryAfterSeconds(request), 0);
});

test('un blocage court peut être choisi pour le code de récupération', () => {
  let clock = 0;
  const throttle = createLoginThrottle({
    keyField: 'contact',
    maxAttempts: 2,
    blockMs: 15 * 60 * 1000,
    now: () => clock,
  });
  const request = { body: { contact: 'client@example.com' } };

  throttle.registerFailure(request);
  throttle.registerFailure(request);
  assert.equal(throttle.retryAfterSeconds(request), 900);

  clock = 15 * 60 * 1000 + 1;
  assert.equal(throttle.retryAfterSeconds(request), 0);
});

test('une tentative pendant le blocage ne prolonge pas la peine', () => {
  let clock = 0;
  const throttle = createLoginThrottle({ now: () => clock });
  const request = requestFor('client@example.com');

  for (let attempt = 0; attempt < DEFAULTS.maxAttempts; attempt += 1) {
    throttle.registerFailure(request);
  }
  const restant = throttle.retryAfterSeconds(request);

  clock += HEURE;
  throttle.registerFailure(request);
  throttle.registerFailure(request);

  assert.equal(throttle.retryAfterSeconds(request), restant - 3600);
});
