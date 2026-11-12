/**
 * Hachage des mots de passe.
 *
 * Deux générations cohabitent, sans migration forcée :
 *
 *  - `p2:` — mot de passe réduit d'abord par SHA-256, puis haché en bcrypt
 *    (coût 12). Le pré-hachage évite la troncature de bcrypt à 72 octets et
 *    permet donc d'accepter des phrases de passe longues, accents et emoji
 *    compris.
 *  - ancien format — bcrypt direct du mot de passe saisi, coût 10. Toujours
 *    vérifiable ; réécrit au format courant dès la première connexion réussie.
 *
 * Aucun mot de passe n'est jamais stocké ni journalisé en clair.
 */

const crypto = require('crypto');
const bcrypt = require('bcryptjs');

const PREFIXE = 'p2:';
const COUT = 12;

/** Empreinte intermédiaire : 64 caractères, sous la limite de bcrypt. */
function empreinte(password) {
  return crypto
    .createHash('sha256')
    .update(String(password), 'utf8')
    .digest('hex');
}

/** Hache un mot de passe pour stockage. */
async function hasherMotDePasse(password) {
  const hash = await bcrypt.hash(empreinte(password), COUT);
  return `${PREFIXE}${hash}`;
}

/** Vérifie un mot de passe contre un hachage stocké, quel que soit son format. */
async function verifierMotDePasse(password, stocke) {
  const valeur = String(stocke ?? '');
  if (!valeur) return false;

  try {
    if (valeur.startsWith(PREFIXE)) {
      return await bcrypt.compare(
        empreinte(password),
        valeur.slice(PREFIXE.length),
      );
    }

    return await bcrypt.compare(String(password), valeur);
  } catch (error) {
    // Un hachage corrompu ne doit pas faire tomber la connexion : il refuse.
    return false;
  }
}

/** Vrai quand le hachage stocké date de l'ancienne génération. */
function hachageARenforcer(stocke) {
  const valeur = String(stocke ?? '');
  return valeur.length > 0 && !valeur.startsWith(PREFIXE);
}

module.exports = {
  COUT,
  PREFIXE,
  hachageARenforcer,
  hasherMotDePasse,
  verifierMotDePasse,
};
