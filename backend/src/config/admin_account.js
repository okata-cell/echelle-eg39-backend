// Provisionnement du compte administrateur.
//
// Aucun mot de passe par défaut n'est accepté ici : le dépôt est public, donc
// un repli écrit dans le code revient à publier le mot de passe du back-office.
// La valeur vient obligatoirement de ADMIN_PASSWORD (variable Render), choisie
// par l'exploitant.

const bcrypt = require('bcryptjs');

const DEFAULT_ADMIN_EMAIL = 'admin@echelle-eg39.com';
const DEFAULT_ADMIN_PHONE = '+22890014329';
const MIN_ADMIN_PASSWORD_LENGTH = 16;

// Valeurs déjà publiées ou trop évidentes : refusées même si elles sont
// fournies explicitement dans l'environnement.
const FORBIDDEN_ADMIN_PASSWORDS = new Set([
  'admin123!',
  'admin1234',
  'password123!',
  'motdepasse123!',
  'changeme',
  'motdepasse',
  'echelleeg39',
]);

function configError(code, message) {
  const error = new Error(message);
  error.code = code;
  return error;
}

/**
 * Valide le mot de passe administrateur et le renvoie.
 * Échoue explicitement plutôt que de retomber sur une valeur connue.
 */
function assertStrongAdminPassword(password) {
  if (typeof password !== 'string' || password.trim() === '') {
    throw configError(
      'ADMIN_PASSWORD_MISSING',
      'ADMIN_PASSWORD est requis pour créer le compte administrateur. ' +
        'Définissez une valeur unique (16 caractères minimum) dans les ' +
        'variables d’environnement Render.',
    );
  }

  // Testé avant la longueur : « Admin123! » doit être signalé comme valeur
  // publique, pas comme simple mot de passe trop court.
  if (FORBIDDEN_ADMIN_PASSWORDS.has(password.toLowerCase())) {
    throw configError(
      'ADMIN_PASSWORD_KNOWN',
      'ADMIN_PASSWORD utilise une valeur publique connue. Choisissez-en une autre.',
    );
  }

  if (password.length < MIN_ADMIN_PASSWORD_LENGTH) {
    throw configError(
      'ADMIN_PASSWORD_TOO_SHORT',
      `ADMIN_PASSWORD doit contenir au moins ${MIN_ADMIN_PASSWORD_LENGTH} caractères.`,
    );
  }

  if (!/[a-zA-Z]/.test(password) || !/\d/.test(password)) {
    throw configError(
      'ADMIN_PASSWORD_WEAK',
      'ADMIN_PASSWORD doit mélanger lettres et chiffres.',
    );
  }

  return password;
}

/** Identité du compte administrateur, avec les coordonnées de l’entreprise. */
function resolveAdminIdentity(env = process.env) {
  const email = String(env.ADMIN_EMAIL || DEFAULT_ADMIN_EMAIL)
    .trim()
    .toLowerCase();
  const phone = String(env.ADMIN_PHONE || DEFAULT_ADMIN_PHONE).trim();

  if (!email.includes('@')) {
    throw configError(
      'ADMIN_EMAIL_INVALID',
      `ADMIN_EMAIL invalide : « ${email} ».`,
    );
  }
  if (!phone) {
    throw configError('ADMIN_PHONE_INVALID', 'ADMIN_PHONE est vide.');
  }

  return { email, phone };
}

/**
 * Crée le compte administrateur s’il n’existe pas encore.
 *
 * Un compte déjà présent n’est jamais modifié : le mot de passe en place reste
 * valide, même si ADMIN_PASSWORD a changé. La rotation passe par
 * `npm run admin:password`.
 *
 * @returns {Promise<{created: boolean, email: string}>}
 */
async function ensureAdminAccount(
  client,
  {
    env = process.env,
    hashPassword = (value) => bcrypt.hash(value, 10),
    logger = console,
  } = {},
) {
  // On raisonne sur « un administrateur existe-t-il ? », pas sur l'adresse
  // configurée : un ADMIN_EMAIL différent de la ligne en base ne doit pas
  // interrompre la migration à chaque redéploiement.
  const existingAdmin = await client.query(
    "SELECT id, email FROM users WHERE role = 'admin' ORDER BY id LIMIT 1",
  );

  if (existingAdmin.rows.length > 0) {
    logger.warn(
      `⚠️  Compte administrateur ${existingAdmin.rows[0].email} déjà présent : ` +
        'mot de passe inchangé. Utilisez « npm run admin:password » pour le remplacer.',
    );
    return { created: false, email: existingAdmin.rows[0].email };
  }

  const { email, phone } = resolveAdminIdentity(env);
  const password = assertStrongAdminPassword(env.ADMIN_PASSWORD);

  // Une adresse déjà utilisée par un client ne peut pas devenir admin : mieux
  // vaut un message explicite qu'une insertion silencieusement ignorée.
  const emailOwner = await client.query(
    'SELECT id, role FROM users WHERE LOWER(email) = $1 LIMIT 1',
    [email],
  );
  if (emailOwner.rows.length > 0) {
    throw configError(
      'ADMIN_EMAIL_TAKEN',
      `ADMIN_EMAIL (${email}) appartient déjà à un compte ${emailOwner.rows[0].role}. ` +
        'Choisissez une autre adresse pour l’administrateur.',
    );
  }

  const passwordHash = await hashPassword(password);

  await client.query(
    `INSERT INTO users (first_name, last_name, email, phone, password_hash, role)
     VALUES ($1, $2, $3, $4, $5, 'admin')
     ON CONFLICT (email) DO NOTHING`,
    ['Admin', 'ÉCHELLE EG39', email, phone, passwordHash],
  );

  return { created: true, email };
}

module.exports = {
  DEFAULT_ADMIN_EMAIL,
  DEFAULT_ADMIN_PHONE,
  MIN_ADMIN_PASSWORD_LENGTH,
  FORBIDDEN_ADMIN_PASSWORDS,
  assertStrongAdminPassword,
  resolveAdminIdentity,
  ensureAdminAccount,
};
