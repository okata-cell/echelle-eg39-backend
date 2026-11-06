// Politique CORS du backend.
//
// En production, seules les origines listées dans ALLOWED_ORIGINS sont
// autorisées. Sans la variable, aucune origine navigateur n’est acceptée :
// l’ancien repli `*` ouvrait l’API à n’importe quel site.

function parseAllowedOrigins(env = process.env) {
  return String(env.ALLOWED_ORIGINS || '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
}

function isProduction(env = process.env) {
  return env.NODE_ENV === 'production';
}

/**
 * Options prêtes pour le middleware `cors`.
 *
 * Les requêtes sans en-tête `Origin` (application mobile Flutter, appels
 * serveur à serveur, curl) restent acceptées : CORS ne concerne que les
 * navigateurs.
 */
function buildCorsOptions(env = process.env) {
  const allowedOrigins = parseAllowedOrigins(env);
  const production = isProduction(env);

  return {
    origin(origin, callback) {
      if (!origin) return callback(null, true);
      if (allowedOrigins.length === 0) {
        // Développement : tout est ouvert. Production : refus silencieux,
        // sans casser la requête (le navigateur bloque simplement la réponse).
        return callback(null, !production);
      }
      return callback(null, allowedOrigins.includes(origin));
    },
    credentials: true,
  };
}

/** Avertissements de configuration affichés au démarrage. */
function securityWarnings(env = process.env) {
  if (!isProduction(env)) return [];

  const warnings = [];
  if (!String(env.JWT_SECRET || '').trim()) {
    warnings.push(
      'JWT_SECRET manquant : les connexions répondront « service indisponible ».',
    );
  } else if (String(env.JWT_SECRET).trim().length < 32) {
    warnings.push(
      'JWT_SECRET fait moins de 32 caractères : utilisez « openssl rand -hex 32 ».',
    );
  }

  if (!String(env.ALLOWED_ORIGINS || '').trim()) {
    warnings.push(
      'ALLOWED_ORIGINS manquant : aucune origine navigateur ne sera autorisée.',
    );
  }

  return warnings;
}

module.exports = {
  buildCorsOptions,
  parseAllowedOrigins,
  securityWarnings,
};
