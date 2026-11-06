const assert = require('node:assert/strict');
const { beforeEach, test } = require('node:test');

const {
  revokeAccount,
  restoreAccount,
  isSessionRevoked,
  revocationReason,
  loadRevokedAccounts,
  clearRevokedAccounts,
} = require('../src/services/session_revocation');

beforeEach(() => {
  clearRevokedAccounts();
});

test('un compte supprimé est marqué comme révoqué', () => {
  assert.equal(isSessionRevoked(12), false);

  assert.equal(revokeAccount(12, 'deleted'), true);
  assert.equal(isSessionRevoked(12), true);
  assert.equal(revocationReason(12), 'deleted');
});

test('une désactivation est distinguée d’une suppression', () => {
  revokeAccount(8, 'disabled');
  assert.equal(revocationReason(8), 'disabled');

  restoreAccount(8);
  assert.equal(isSessionRevoked(8), false);
});

test('les identifiants invalides sont ignorés', () => {
  assert.equal(revokeAccount('abc'), false);
  assert.equal(revokeAccount(null), false);
  assert.equal(revokeAccount(-3), false);
  assert.equal(isSessionRevoked('abc'), false);
});

test('la liste est reconstruite depuis la base au démarrage', async () => {
  const db = {
    query: async () => ({
      rows: [
        { id: 12, deleted_at: '2026-11-06T22:00:00.000Z', is_active: false },
        { id: 8, deleted_at: null, is_active: false },
        { id: 4, deleted_at: null, is_active: true },
      ],
    }),
  };

  const count = await loadRevokedAccounts(db, null);

  assert.equal(count, 2);
  assert.equal(revocationReason(12), 'deleted');
  assert.equal(revocationReason(8), 'disabled');
  assert.equal(isSessionRevoked(4), false);
});
