// Code de récupération de compte.
//
// Il remplace l'envoi d'e-mail ou de SMS : c'est la preuve d'identité que le
// client conserve chez lui. Il est généré à l'inscription, affiché une seule
// fois, et seule son empreinte HMAC est enregistrée. Sans ce code, connaître
// l'adresse e-mail d'un client ne suffit pas à prendre son compte.
//
// Format affiché : EG39-ABCD-EFGH (8 caractères utiles). L'alphabet exclut les
// caractères ambigus (0/O, 1/I/L) pour une recopie au téléphone sans erreur.

const crypto = require('crypto');

const { hashIdentifier } = require('./identifier_hash');

const PREFIX = 'EG39';
const ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const CODE_LENGTH = 8;

function randomGroup(length) {
  let value = '';
  for (let index = 0; index < length; index += 1) {
    value += ALPHABET[crypto.randomInt(0, ALPHABET.length)];
  }
  return value;
}

/** Code de récupération lisible, prêt à être dicté au téléphone. */
function generateRecoveryCode() {
  const raw = `${randomGroup(4)}${randomGroup(4)}`;
  return `${PREFIX}-${raw.slice(0, 4)}-${raw.slice(4)}`;
}

/**
 * Forme canonique d'un code saisi : majuscules, sans séparateurs, sans préfixe.
 * Tolère « eg39 abcd efgh », « ABCD-EFGH », « eg39abcdefgh ».
 */
function normalizeRecoveryCode(value) {
  const compact = String(value ?? '')
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, '');

  const withoutPrefix = compact.startsWith(PREFIX)
    ? compact.slice(PREFIX.length)
    : compact;

  return withoutPrefix;
}

/** Empreinte du code, ou `null` si le secret serveur manque. */
function hashRecoveryCode(value) {
  const canonical = normalizeRecoveryCode(value);
  if (canonical.length !== CODE_LENGTH) return null;
  return hashIdentifier(canonical);
}

/** Comparaison à temps constant entre le code saisi et l'empreinte stockée. */
function matchesRecoveryCodeHash(value, storedHash) {
  const candidate = hashRecoveryCode(value);
  if (!candidate || typeof storedHash !== 'string') return false;
  if (storedHash.length !== candidate.length) return false;

  return crypto.timingSafeEqual(
    Buffer.from(candidate, 'utf8'),
    Buffer.from(storedHash, 'utf8'),
  );
}

module.exports = {
  PREFIX,
  CODE_LENGTH,
  generateRecoveryCode,
  normalizeRecoveryCode,
  hashRecoveryCode,
  matchesRecoveryCodeHash,
};
