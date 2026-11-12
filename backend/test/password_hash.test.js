const assert = require('node:assert/strict');
const { test } = require('node:test');
const bcrypt = require('bcryptjs');

const {
  COUT,
  PREFIXE,
  hachageARenforcer,
  hasherMotDePasse,
  verifierMotDePasse,
} = require('../src/utils/password_hash');

test('le mot de passe n’est jamais stocké en clair', async () => {
  const hash = await hasherMotDePasse('Chantier#2026');

  assert.ok(hash.startsWith(PREFIXE));
  assert.ok(!hash.includes('Chantier'));
  // Deux hachages du même mot de passe diffèrent : le sel est bien unique.
  assert.notEqual(hash, await hasherMotDePasse('Chantier#2026'));
  assert.equal(COUT, 12);
});

test('la vérification accepte le bon mot de passe et refuse les autres', async () => {
  const hash = await hasherMotDePasse('Chantier#2026');

  assert.equal(await verifierMotDePasse('Chantier#2026', hash), true);
  assert.equal(await verifierMotDePasse('chantier#2026', hash), false);
  assert.equal(await verifierMotDePasse('Chantier#2027', hash), false);
  assert.equal(await verifierMotDePasse('Chantier#2026', null), false);
  assert.equal(await verifierMotDePasse('Chantier#2026', 'pas un hash'), false);
});

test('les phrases de passe longues ne sont pas tronquées', async () => {
  // bcrypt seul s'arrête à 72 octets ; le pré-hachage SHA-256 lève la limite.
  const longue = `Nivellement#${'a'.repeat(90)}`;
  const autre = `Nivellement#${'a'.repeat(89)}b`;
  const hash = await hasherMotDePasse(longue);

  assert.equal(await verifierMotDePasse(longue, hash), true);
  assert.equal(await verifierMotDePasse(autre, hash), false);
});

test('un hachage hérité reste vérifiable et signale son renforcement', async () => {
  const ancien = await bcrypt.hash('4821KLMN', 4);

  assert.equal(await verifierMotDePasse('4821KLMN', ancien), true);
  assert.equal(await verifierMotDePasse('4821KLMN!', ancien), false);
  assert.equal(hachageARenforcer(ancien), true);
  assert.equal(hachageARenforcer(await hasherMotDePasse('4821KLMN')), false);
  assert.equal(hachageARenforcer(null), false);
});
