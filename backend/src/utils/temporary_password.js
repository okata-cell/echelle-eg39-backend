// Mot de passe temporaire de récupération.
//
// Il n'est jamais conservé en clair : la route qui le crée le hache
// immédiatement et le renvoie une seule fois à l'application, qui l'affiche
// pendant deux minutes. Le client se connecte ensuite avec, et doit le
// remplacer à la première connexion.
//
// Le format suit exactement la règle imposée par l'écran de connexion de
// l'application : quatre chiffres puis quatre lettres majuscules (1234AZER).

const crypto = require('crypto');

/** Durée d'affichage du mot de passe temporaire, en secondes. */
const TEMPORARY_PASSWORD_DISPLAY_SECONDS = 120;

const LETTERS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const PATTERN = /^\d{4}[A-Z]{4}$/;

function generateTemporaryPassword() {
  let digits = '';
  for (let index = 0; index < 4; index += 1) {
    digits += crypto.randomInt(0, 10).toString();
  }

  let letters = '';
  for (let index = 0; index < 4; index += 1) {
    letters += LETTERS[crypto.randomInt(0, LETTERS.length)];
  }

  return `${digits}${letters}`;
}

function isTemporaryPasswordFormat(value) {
  return PATTERN.test(String(value ?? ''));
}

module.exports = {
  TEMPORARY_PASSWORD_DISPLAY_SECONDS,
  generateTemporaryPassword,
  isTemporaryPasswordFormat,
};
