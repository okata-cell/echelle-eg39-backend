const assert = require('node:assert/strict');
const { test } = require('node:test');

const { setAdminPassword } = require('../src/scripts/set-admin-password');

const strongPassword = 'Lome-Topographie-2026!x';

function fakeDatabase({ adminEmail = 'admin@echelle-eg39.com', updatedRows } = {}) {
  const calls = [];
  return {
    calls,
    async query(sql, values) {
      calls.push({ sql, values });
      if (sql.includes("role = 'admin'")) {
        return { rows: adminEmail ? [{ email: adminEmail }] : [] };
      }
      if (sql.includes('UPDATE users')) {
        return { rows: updatedRows ?? [] };
      }
      return { rows: [] };
    },
  };
}

test('cible l’administrateur en base quand ADMIN_EMAIL n’est pas fourni', async () => {
  const db = fakeDatabase({
    updatedRows: [{ id: 1, email: 'admin@echelle-eg39.com' }],
  });

  const admin = await setAdminPassword({
    env: { ADMIN_PASSWORD: strongPassword },
    query: db.query,
    hashPassword: async () => 'nouveau-hash',
  });

  assert.deepEqual(admin, { id: 1, email: 'admin@echelle-eg39.com' });
  const update = db.calls.at(-1);
  assert.deepEqual(update.values, ['nouveau-hash', 'admin@echelle-eg39.com']);
});

test('respecte ADMIN_EMAIL quand il est fourni', async () => {
  const db = fakeDatabase({
    updatedRows: [{ id: 4, email: 'direction@echelle-eg39.com' }],
  });

  await setAdminPassword({
    env: {
      ADMIN_EMAIL: 'Direction@Echelle-EG39.com',
      ADMIN_PASSWORD: strongPassword,
    },
    query: db.query,
    hashPassword: async () => 'hash',
  });

  assert.equal(db.calls.length, 1);
  assert.deepEqual(db.calls[0].values, [
    'hash',
    'direction@echelle-eg39.com',
  ]);
});

test('refuse un mot de passe faible avant d’écrire en base', async () => {
  const db = fakeDatabase({ updatedRows: [{ id: 1, email: 'admin@echelle-eg39.com' }] });

  await assert.rejects(
    () =>
      setAdminPassword({
        env: { ADMIN_PASSWORD: 'Admin123!' },
        query: db.query,
        hashPassword: async () => 'hash',
      }),
    (error) => error.code === 'ADMIN_PASSWORD_KNOWN',
  );
  assert.equal(db.calls.length, 0);
});

test('échoue clairement quand aucun administrateur n’existe', async () => {
  const db = fakeDatabase({ adminEmail: null });

  await assert.rejects(
    () =>
      setAdminPassword({
        env: { ADMIN_PASSWORD: strongPassword },
        query: db.query,
        hashPassword: async () => 'hash',
      }),
    (error) => error.code === 'ADMIN_NOT_FOUND',
  );
});
