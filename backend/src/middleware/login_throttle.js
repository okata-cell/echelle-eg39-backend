// Limitation des tentatives de connexion, sans dépendance externe.
//
// Le mot de passe administrateur ayant circulé dans un dépôt public, la
// connexion doit être protégée contre les essais répétés. Le compteur est
// conservé en mémoire : une seule instance Render, donc suffisant ici.

const DEFAULTS = {
  maxAttempts: 8,
  windowMs: 15 * 60 * 1000,
  maxKeys: 2000,
};

/**
 * @param {object} [options]
 * @param {number} [options.maxAttempts] Essais autorisés par fenêtre.
 * @param {number} [options.windowMs] Durée de la fenêtre en millisecondes.
 * @param {() => number} [options.now] Horloge injectable pour les tests.
 */
function createLoginThrottle(options = {}) {
  const { maxAttempts, windowMs, maxKeys } = { ...DEFAULTS, ...options };
  const now = typeof options.now === 'function' ? options.now : Date.now;
  const attempts = new Map();

  const keyFor = (req) => {
    const identifier = String(req?.body?.identifier || '')
      .trim()
      .toLowerCase();
    const ip =
      req?.ip || req?.socket?.remoteAddress || req?.connection?.remoteAddress;
    return `${ip || 'inconnu'}|${identifier}`;
  };

  const prune = (timestamp) => {
    if (attempts.size < maxKeys) return;
    for (const [key, entry] of attempts) {
      if (timestamp - entry.firstAttemptAt >= windowMs) attempts.delete(key);
    }
  };

  return {
    /** Secondes avant un nouvel essai, ou 0 si la connexion peut être tentée. */
    retryAfterSeconds(req) {
      const timestamp = now();
      prune(timestamp);

      const key = keyFor(req);
      const entry = attempts.get(key);
      if (!entry) return 0;

      const elapsed = timestamp - entry.firstAttemptAt;
      if (elapsed >= windowMs) {
        attempts.delete(key);
        return 0;
      }
      if (entry.count < maxAttempts) return 0;

      return Math.ceil((windowMs - elapsed) / 1000);
    },

    /** Enregistre un échec d’authentification. */
    registerFailure(req) {
      const timestamp = now();
      const key = keyFor(req);
      const entry = attempts.get(key);

      if (!entry || timestamp - entry.firstAttemptAt >= windowMs) {
        attempts.set(key, { count: 1, firstAttemptAt: timestamp });
        return;
      }
      entry.count += 1;
    },

    /** Efface le compteur après une connexion réussie. */
    reset(req) {
      attempts.delete(keyFor(req));
    },
  };
}

module.exports = { createLoginThrottle, DEFAULTS };
