const assert = require('node:assert/strict');
const test = require('node:test');

const { maskEmail } = require('../src/utils/anonymize');

test('maskEmail masque la partie locale tout en gardant le domaine', () => {
  const email = 'jean.dupont@example.com';
  const masked = maskEmail(email);

  assert.equal(masked, 'j••••••@example.com');
  assert.notEqual(masked, email);
  assert.equal(masked.includes('jean.dupont'), false);
});

test('maskEmail gère les adresses courtes', () => {
  assert.equal(maskEmail('a@b.io'), 'a•••@b.io');
});

test('maskEmail ne révèle pas les valeurs invalides', () => {
  assert.equal(maskEmail('adresse-invalide'), '••••');
  assert.equal(maskEmail(''), '••••');
  assert.equal(maskEmail(null), '••••');
});
