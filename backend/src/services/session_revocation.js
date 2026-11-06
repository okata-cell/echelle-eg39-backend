// Comptes dont la session est fermée d'office.
//
// Un jeton JWT reste valide jusqu'à son expiration (30 jours) : supprimer un
// compte ou le désactiver ne l'invalide pas. Pour que l'appareil resté ouvert
// perde l'accès tout de suite, on tient la liste des comptes concernés en
// mémoire. C'est la même hypothèse que la limitation des connexions : Render ne
// fait tourner qu'une instance.
//
// La liste est reconstruite depuis la base au démarrage du serveur : elle
// survit donc aux redéploiements, sans table dédiée ni requête sur chaque appel.

/** @type {Map<number, 'deleted'|'disabled'>} */
const revokedAccounts = new Map();

function toUserId(userId) {
  const id = Number(userId);
  return Number.isInteger(id) && id > 0 ? id : null;
}

/** Ferme l'accès d'un compte : le jeton en cours cesse d'être accepté. */
function revokeAccount(userId, reason = 'deleted') {
  const id = toUserId(userId);
  if (id === null) return false;
  revokedAccounts.set(id, reason === 'disabled' ? 'disabled' : 'deleted');
  return true;
}

/** Réouvre l'accès : utilisé quand l'administration réactive un client. */
function restoreAccount(userId) {
  const id = toUserId(userId);
  if (id === null) return false;
  return revokedAccounts.delete(id);
}

function isSessionRevoked(userId) {
  const id = toUserId(userId);
  return id !== null && revokedAccounts.has(id);
}

/** Motif de fermeture, `null` si la session est ouverte. */
function revocationReason(userId) {
  const id = toUserId(userId);
  return id === null ? null : revokedAccounts.get(id) || null;
}

/**
 * Recharge la liste depuis la base (démarrage du serveur).
 *
 * Les colonnes `deleted_at` peuvent manquer sur une toute première exécution,
 * avant la migration : l'appelant décide alors de continuer sans liste plutôt
 * que d'empêcher le serveur de démarrer.
 */
async function loadRevokedAccounts(
  db = require('../config/database'),
  logger = console,
) {
  const result = await db.query(
    'SELECT id, deleted_at, is_active FROM users WHERE deleted_at IS NOT NULL OR is_active = FALSE',
  );

  revokedAccounts.clear();
  for (const row of result.rows) {
    const id = toUserId(row.id);
    const isDeleted = Boolean(row.deleted_at);
    // La requête filtre déjà, mais on ne révoque jamais un compte actif si la
    // base renvoie une ligne de trop.
    const isDisabled = row.is_active === false;
    if (id === null || (!isDeleted && !isDisabled)) continue;

    revokedAccounts.set(id, isDeleted ? 'deleted' : 'disabled');
  }

  if (logger && revokedAccounts.size > 0) {
    logger.warn(
      `⚠️  ${revokedAccounts.size} compte(s) supprimé(s) ou désactivé(s) : ` +
        'leurs anciens jetons sont refusés.',
    );
  }

  return revokedAccounts.size;
}

/** Réservé aux tests : vide la liste en mémoire. */
function clearRevokedAccounts() {
  revokedAccounts.clear();
}

module.exports = {
  revokeAccount,
  restoreAccount,
  isSessionRevoked,
  revocationReason,
  loadRevokedAccounts,
  clearRevokedAccounts,
};
