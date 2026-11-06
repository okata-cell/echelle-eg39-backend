// Empreintes d'identifiants des comptes supprimés.
//
// Une fois un compte supprimé, l'e-mail et le téléphone sont retirés de la
// ligne `users`. Impossible dès lors de reconnaître la personne qui se
// reconnecte avec ses anciennes coordonnées : elle recevrait « identifiant
// introuvable », ce qui est faux et déroutant.
//
// On conserve donc une empreinte HMAC-SHA256 de chaque identifiant neutralisé :
// elle permet de répondre « ce compte a été supprimé », sans garder la donnée
// personnelle elle-même. Sans le secret serveur, une empreinte n'est pas
// réversible ; elle ne peut pas être recalculée à partir d'une liste d'e-mails.

const crypto = require('crypto');

/**
 * Secret utilisé pour les empreintes.
 *
 * `IDENTIFIER_HASH_SECRET` peut être défini séparément ; à défaut on retombe sur
 * `JWT_SECRET` pour ne pas ajouter une variable obligatoire. Conséquence à
 * connaître : changer ce secret rend les anciennes empreintes inutilisables, la
 * reconnaissance se dégrade en « identifiant introuvable » (jamais en erreur).
 */
function identifierHashSecret(env = process.env) {
  return String(env.IDENTIFIER_HASH_SECRET || env.JWT_SECRET || '').trim();
}

/** Empreinte d'un identifiant, ou `null` si elle ne peut pas être calculée. */
function hashIdentifier(value, { env = process.env } = {}) {
  const normalized = String(value ?? '')
    .trim()
    .toLowerCase();
  if (!normalized) return null;

  const secret = identifierHashSecret(env);
  if (!secret) return null;

  return crypto.createHmac('sha256', secret).update(normalized).digest('hex');
}

/** Empreintes de plusieurs identifiants, sans doublon ni valeur vide. */
function hashIdentifiers(values, options) {
  const hashes = new Set();
  for (const value of values || []) {
    const hash = hashIdentifier(value, options);
    if (hash) hashes.add(hash);
  }
  return [...hashes];
}

module.exports = { hashIdentifier, hashIdentifiers, identifierHashSecret };
