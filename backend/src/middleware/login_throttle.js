// Limitation des tentatives de connexion, sans dépendance externe.
//
// Le mot de passe administrateur ayant circulé dans un dépôt public, la
// connexion doit être protégée contre les essais répétés. Le compteur est
// conservé en mémoire : une seule instance Render, donc suffisant ici.
//
// Règle retenue : quatre échecs sur un même compte bloquent les tentatives
// pendant 24 h, à compter de l'essai qui a déclenché le blocage. Le compteur
// suit l'identifiant visé, pas l'appareil : un client peut réessayer depuis un
// autre téléphone, il sera toujours bloqué, et un autre compte n'est pas
// pénalisé. Une connexion réussie avant le blocage remet le compteur à zéro.

const DEFAULTS = {
  maxAttempts: 4,
  blockMs: 24 * 60 * 60 * 1000,
  maxKeys: 5000,
};

/**
 * @param {object} [options]
 * @param {number} [options.maxAttempts] Échecs autorisés avant blocage.
 * @param {number} [options.blockMs] Durée du blocage, en millisecondes.
 * @param {string} [options.keyField] Champ du corps servant de clé.
 * @param {() => number} [options.now] Horloge injectable pour les tests.
 */
function createLoginThrottle(options = {}) {
  const { maxAttempts, blockMs, maxKeys } = { ...DEFAULTS, ...options };
  // `identifier` pour la connexion, `contact` pour la récupération de mot de passe.
  const keyField = options.keyField || 'identifier';
  const now = typeof options.now === 'function' ? options.now : Date.now;
  /** clé → { essais, dernierEssaiAt, bloqueAt } */
  const attempts = new Map();

  const keyFor = (req) =>
    String(req?.body?.[keyField] || '')
      .trim()
      .toLowerCase();

  const prune = (timestamp) => {
    if (attempts.size < maxKeys) return;

    for (const [key, entry] of attempts) {
      const reference = entry.bloqueAt ?? entry.dernierEssaiAt;
      if (timestamp - reference >= blockMs) attempts.delete(key);
    }
  };

  return {
    maxAttempts,
    blockMs,

    /** Secondes avant un nouvel essai, ou 0 si la connexion peut être tentée. */
    retryAfterSeconds(req) {
      const timestamp = now();
      prune(timestamp);

      const entry = attempts.get(keyFor(req));
      if (!entry || entry.bloqueAt === null) return 0;

      const reste = blockMs - (timestamp - entry.bloqueAt);
      if (reste <= 0) {
        attempts.delete(keyFor(req));
        return 0;
      }

      return Math.ceil(reste / 1000);
    },

    /** Enregistre un échec d’authentification. */
    registerFailure(req) {
      const timestamp = now();
      prune(timestamp);

      const key = keyFor(req);
      if (!key) return;

      const entry = attempts.get(key);
      if (!entry) {
        attempts.set(key, {
          essais: 1,
          dernierEssaiAt: timestamp,
          bloqueAt: maxAttempts <= 1 ? timestamp : null,
        });
        return;
      }

      // Déjà bloqué : les tentatives supplémentaires ne prolongent pas la peine.
      if (entry.bloqueAt !== null) return;

      entry.essais += 1;
      entry.dernierEssaiAt = timestamp;
      if (entry.essais >= maxAttempts) entry.bloqueAt = timestamp;
    },

    /** Efface le compteur après une connexion réussie. */
    reset(req) {
      attempts.delete(keyFor(req));
    },
  };
}

module.exports = { createLoginThrottle, DEFAULTS };
