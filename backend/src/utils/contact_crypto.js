/**
 * Chiffrement des coordonnées clients et index aveugle.
 *
 * Deux mécanismes pour deux besoins :
 *
 *  - **chiffrement AES-256-GCM** (colonnes `email_cipher`, `phone_cipher`) :
 *    relire une adresse ou un numéro pour l'afficher. Le texte chiffré est
 *    inutilisable sans la clé, qui vit dans l'environnement du serveur et non
 *    dans la base. GCM authentifie le contenu : une valeur modifiée en base est
 *    détectée au lieu d'être rendue de travers.
 *
 *  - **index aveugle HMAC-SHA256** (colonnes `email_bidx`, `phone_bidx`) :
 *    retrouver un compte à la connexion et tenir l'unicité, sans jamais
 *    déchiffrer. Un chiffrement à vecteur aléatoire donne un résultat différent
 *    à chaque fois : impossible d'écrire `WHERE email = …`. L'empreinte, elle,
 *    est stable pour une même valeur, et invérifiable sans le secret serveur —
 *    contrairement à un simple SHA-256, qu'un attaquant pourrait recalculer sur
 *    une liste d'adresses.
 *
 * Les comptes créés avant ce dispositif conservent `email` et `phone` en clair ;
 * la lecture est mixte (`contactsDuCompte` plus bas) et rien n'est migré de force.
 */

const crypto = require('crypto');

const PREFIXE = 'v1:';
const IV_OCTETS = 12;
const TAG_OCTETS = 16;

/**
 * Clé de chiffrement de 32 octets.
 *
 * `DATA_ENCRYPTION_KEY` est attendue en base64 ou en hexadécimal. À défaut, une
 * clé est dérivée du secret du serveur pour ne pas bloquer un environnement de
 * développement. Conséquence à connaître : changer ce secret rend illisibles
 * les coordonnées déjà chiffrées (la connexion par empreinte, elle, continue).
 */
function cleChiffrement(env = process.env) {
  const brute = String(env.DATA_ENCRYPTION_KEY || '').trim();

  if (brute) {
    const candidate = /^[0-9a-fA-F]{64}$/.test(brute)
      ? Buffer.from(brute, 'hex')
      : Buffer.from(brute, 'base64');
    if (candidate.length === 32) return candidate;
    if (candidate.length > 32) return candidate.subarray(0, 32);
    // Clé plus courte : dérivée pour atteindre exactement 32 octets.
    return crypto.createHash('sha256').update(candidate).digest();
  }

  const secours = String(env.JWT_SECRET || '').trim();
  if (!secours) return null;

  return crypto.createHash('sha256').update(`contacts:${secours}`).digest();
}

/** Secret des empreintes : séparé si possible, sinon celui des identifiants. */
function secretEmpreinte(env = process.env) {
  return String(
    env.CONTACT_INDEX_SECRET || env.IDENTIFIER_HASH_SECRET || env.JWT_SECRET || '',
  ).trim();
}

function normaliser(valeur) {
  return String(valeur ?? '')
    .trim()
    .toLowerCase();
}

/**
 * Chiffre une coordonnée. Renvoie `null` pour une valeur vide, afin que les
 * colonnes restent absentes plutôt que de contenir un chiffré de rien.
 */
function chiffrerContact(valeur, { env = process.env } = {}) {
  const clair = String(valeur ?? '').trim();
  if (!clair) return null;

  const cle = cleChiffrement(env);
  if (!cle) {
    throw new Error('DATA_ENCRYPTION_KEY manquante : chiffrement impossible');
  }

  const iv = crypto.randomBytes(IV_OCTETS);
  const chiffreur = crypto.createCipheriv('aes-256-gcm', cle, iv);
  const donnees = Buffer.concat([
    chiffreur.update(clair, 'utf8'),
    chiffreur.final(),
  ]);
  const tag = chiffreur.getAuthTag();

  return `${PREFIXE}${Buffer.concat([iv, tag, donnees]).toString('base64')}`;
}

/**
 * Déchiffre une coordonnée. Renvoie `null` si la valeur est absente, d'un
 * format inconnu ou si la clé ne correspond plus : un écran affiche alors un
 * tiret au lieu de faire tomber la requête.
 */
function dechiffrerContact(chiffre, { env = process.env } = {}) {
  const valeur = String(chiffre ?? '').trim();
  if (!valeur) return null;
  if (!valeur.startsWith(PREFIXE)) return null;

  const cle = cleChiffrement(env);
  if (!cle) return null;

  try {
    const brut = Buffer.from(valeur.slice(PREFIXE.length), 'base64');
    const iv = brut.subarray(0, IV_OCTETS);
    const tag = brut.subarray(IV_OCTETS, IV_OCTETS + TAG_OCTETS);
    const donnees = brut.subarray(IV_OCTETS + TAG_OCTETS);

    const dechiffreur = crypto.createDecipheriv('aes-256-gcm', cle, iv);
    dechiffreur.setAuthTag(tag);

    return Buffer.concat([
      dechiffreur.update(donnees),
      dechiffreur.final(),
    ]).toString('utf8');
  } catch (error) {
    // Clé changée ou valeur altérée : on ne rend rien.
    return null;
  }
}

/** Empreinte aveugle d'une coordonnée, ou `null` si elle est vide. */
function empreinteContact(valeur, { env = process.env } = {}) {
  const normalisee = normaliser(valeur);
  if (!normalisee) return null;

  const secret = secretEmpreinte(env);
  if (!secret) return null;

  return crypto
    .createHmac('sha256', secret)
    .update(`contact:${normalisee}`)
    .digest('hex');
}

/**
 * État des deux secrets, tel qu'affiché par `/health` : des mots, jamais les
 * valeurs. Permet de vérifier après un déploiement que Render a bien pris les
 * variables, sans avoir à se connecter pour le deviner.
 *
 * `dediee` / `dedie` : variable propre définie. `derivee` / `herite` : repli sur
 * `JWT_SECRET`, donc rien n'est cassé mais la séparation des clés n'est pas
 * faite. Changer de repli vers une variable dédiée plus tard rend illisibles
 * les empreintes et les chiffrés déjà écrits avec le repli : définir les
 * variables avant les premières inscriptions.
 */
function etatSecrets(env = process.env) {
  const chiffrement = String(env.DATA_ENCRYPTION_KEY || '').trim()
    ? 'dediee'
    : String(env.JWT_SECRET || '').trim()
      ? 'derivee'
      : 'absente';

  const empreinte = String(env.CONTACT_INDEX_SECRET || '').trim()
    ? 'dedie'
    : String(env.IDENTIFIER_HASH_SECRET || env.JWT_SECRET || '').trim()
      ? 'herite'
      : 'absent';

  return { encryptionKey: chiffrement, indexSecret: empreinte };
}

/** Coordonnées lisibles d'une ligne `users`, chiffrées ou héritées. */
function contactsDuCompte(ligne, { env = process.env } = {}) {
  if (!ligne) return { email: null, phone: null };

  return {
    email:
      ligne.email ??
      dechiffrerContact(ligne.email_cipher, { env }) ??
      null,
    phone:
      ligne.phone ??
      dechiffrerContact(ligne.phone_cipher, { env }) ??
      null,
  };
}

/** Vrai quand la ligne est chiffrée (aucune coordonnée en clair). */
function compteChiffre(ligne) {
  if (!ligne) return false;
  return Boolean(
    (ligne.email_cipher || ligne.phone_cipher) && !ligne.email && !ligne.phone,
  );
}

module.exports = {
  PREFIXE,
  chiffrerContact,
  cleChiffrement,
  compteChiffre,
  contactsDuCompte,
  dechiffrerContact,
  empreinteContact,
  etatSecrets,
  secretEmpreinte,
};
