const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  LONGUEUR_MAX,
  REGLES,
  verifierMotDePasse,
} = require('../src/utils/password_policy');

function accepte(password, identite) {
  const resultat = verifierMotDePasse(password, identite);
  assert.equal(resultat.valide, true, resultat.message);
}

function refuse(password, motif, identite) {
  const resultat = verifierMotDePasse(password, identite);
  assert.equal(resultat.valide, false);
  if (motif) assert.match(resultat.message, motif);
}

test('les caractères spéciaux et les phrases longues sont acceptés', () => {
  accepte('Chantier#2026');
  accepte('Bornes.Leica-2026');
  accepte('Métré+récép 2026!');
  accepte('Nivellement du terrain nord-ouest, 12 bornes à 30 m #2026');

  // Aucune longueur maximale courte : 128 caractères passent.
  accepte(`${'Ab3!'.repeat(LONGUEUR_MAX / 4)}`);
});

test('la longueur minimale et le plafond sont contrôlés', () => {
  refuse('Ab3!56789', /au moins 10 caractères/);
  refuse(`${'Ab3!'.repeat(40)}`, /ne peut pas dépasser/);
});

test('trois familles de caractères sont exigées', () => {
  refuse('terrainnord', /trois familles/);
  refuse('Terrainnord', /trois familles/);
  refuse('terrainnord12', /trois familles/);
  // Troisième famille présente : minuscules, chiffres et caractères spéciaux.
  accepte('terrainnord1!');
});

test('les mots de passe courants sont refusés', () => {
  refuse('Password123!', /plus courants/);
  refuse('Azerty1234!', /plus courants/);
  refuse('Motdepasse1!', /plus courants/);
  refuse('Echelle#2026', /plus courants/);
});

test('les répétitions et les suites sont refusées', () => {
  refuse('Aaaa1!vvvv', /répéter quatre fois/);
  refuse('Abcd1234!x', /suites de caractères/);
  refuse('Xy9876!abcd', /suites de caractères/);
});

test('le nom, l’e-mail et le téléphone du titulaire sont refusés', () => {
  const identite = {
    firstName: 'Afi',
    lastName: 'Koffi',
    email: 'afi.koffi@example.com',
    phone: '+22890718293',
  };

  refuse('Afi#Chantier26', /votre nom, votre e-mail ou votre numéro/, identite);
  refuse('Koffi#2026!x', /votre nom, votre e-mail ou votre numéro/, identite);
  refuse('afi.koffi#2026!', /votre nom, votre e-mail ou votre numéro/, identite);
  // Six derniers chiffres du numéro, sans suite ni répétition.
  refuse('Terrain#718293', /votre nom, votre e-mail ou votre numéro/, identite);
  accepte('Nivellement#2026', identite);
});

test('une base courte ne suffit pas à contourner la règle', () => {
  // Un mot de passe vide, nul ou uniquement composé d'espaces est refusé.
  refuse('', /requis/);
  refuse('          ', /trois familles|au moins 10/);
});

test('la règle affichée reste lisible par les écrans', () => {
  assert.match(REGLES, /10 caractères minimum/);
  assert.match(REGLES, /trois familles/);
});
