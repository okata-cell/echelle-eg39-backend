const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  assertStrongAdminPassword,
  ensureAdminAccount,
  resolveAdminIdentity,
} = require('../src/config/admin_account');

const silentLogger = { warn() {}, error() {} };

function clientWith({ admins = [], emailOwners = [] } = {}) {
  const calls = [];
  return {
    calls,
    async query(sql, values) {
      calls.push({ sql, values });
      if (sql.includes("role = 'admin'")) return { rows: admins };
      if (sql.includes('SELECT id, role FROM users')) return { rows: emailOwners };
      return { rows: [] };
    },
  };
}

const strongPassword = 'Lome-Topographie-2026!x';

test('un compte administrateur existant n’est jamais recréé, même sans ADMIN_PASSWORD', async () => {
  const client = clientWith({
    admins: [{ id: 1, email: 'admin@echelle-eg39.com' }],
  });

  const result = await ensureAdminAccount(client, {
    env: { ADMIN_EMAIL: 'Autre-Adresse@Echelle-EG39.com' },
    logger: silentLogger,
  });

  assert.deepEqual(result, {
    created: false,
    email: 'admin@echelle-eg39.com',
  });
  // Un seul SELECT : la configuration ADMIN_EMAIL n’entre pas en jeu.
  assert.equal(client.calls.length, 1);
  assert.match(client.calls[0].sql, /SELECT id, email/);
});

test('une base sans administrateur exige ADMIN_PASSWORD', async () => {
  const client = clientWith();

  await assert.rejects(
    () => ensureAdminAccount(client, { env: {}, logger: silentLogger }),
    (error) => error.code === 'ADMIN_PASSWORD_MISSING',
  );
  assert.equal(
    client.calls.some((call) => /INSERT INTO users/.test(call.sql)),
    false,
  );
});

test('le mot de passe par défaut publié est refusé', async () => {
  const client = clientWith();

  await assert.rejects(
    () =>
      ensureAdminAccount(client, {
        env: { ADMIN_PASSWORD: 'Admin123!' },
        logger: silentLogger,
      }),
    (error) => error.code === 'ADMIN_PASSWORD_KNOWN',
  );

  await assert.rejects(
    () =>
      ensureAdminAccount(client, {
        env: { ADMIN_PASSWORD: 'court-123' },
        logger: silentLogger,
      }),
    (error) => error.code === 'ADMIN_PASSWORD_TOO_SHORT',
  );
});

test('un mot de passe fort crée le compte avec un hash', async () => {
  const client = clientWith();
  const hashed = [];

  const result = await ensureAdminAccount(client, {
    env: {
      ADMIN_EMAIL: 'Direction@Echelle-EG39.com',
      ADMIN_PHONE: '+22890014329',
      ADMIN_PASSWORD: strongPassword,
    },
    hashPassword: async (value) => {
      hashed.push(value);
      return 'hash-de-test';
    },
    logger: silentLogger,
  });

  assert.deepEqual(result, {
    created: true,
    email: 'direction@echelle-eg39.com',
  });
  assert.deepEqual(hashed, [strongPassword]);

  const insert = client.calls.at(-1);
  assert.match(insert.sql, /INSERT INTO users/);
  assert.deepEqual(insert.values, [
    'Admin',
    'ÉCHELLE EG39',
    'direction@echelle-eg39.com',
    '+22890014329',
    'hash-de-test',
  ]);
});

test('une adresse déjà utilisée par un client est refusée explicitement', async () => {
  const client = clientWith({ emailOwners: [{ id: 9, role: 'client' }] });

  await assert.rejects(
    () =>
      ensureAdminAccount(client, {
        env: {
          ADMIN_EMAIL: 'client@echelle-eg39.com',
          ADMIN_PASSWORD: strongPassword,
        },
        hashPassword: async () => 'hash',
        logger: silentLogger,
      }),
    (error) => error.code === 'ADMIN_EMAIL_TAKEN',
  );
});

test('l’identité administrateur retombe sur les coordonnées de l’entreprise', () => {
  assert.deepEqual(resolveAdminIdentity({}), {
    email: 'admin@echelle-eg39.com',
    phone: '+22890014329',
  });
  assert.throws(
    () => resolveAdminIdentity({ ADMIN_EMAIL: 'sans-arobase' }),
    (error) => error.code === 'ADMIN_EMAIL_INVALID',
  );
});

test('la validation du mot de passe exige lettres et chiffres', () => {
  assert.equal(assertStrongAdminPassword(strongPassword), strongPassword);
  assert.throws(
    () => assertStrongAdminPassword('MotDePasseSansChiffre'),
    (error) => error.code === 'ADMIN_PASSWORD_WEAK',
  );
  assert.throws(
    () => assertStrongAdminPassword(undefined),
    (error) => error.code === 'ADMIN_PASSWORD_MISSING',
  );
});
