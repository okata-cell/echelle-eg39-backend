// Rotation du mot de passe administrateur.
//
// Usage (depuis backend/, avec DATABASE_URL défini) :
//   ADMIN_PASSWORD='nouveau-mot-de-passe-unique' npm run admin:password
//
// L’adresse ciblée est ADMIN_EMAIL si la variable est définie, sinon le premier
// compte ayant le rôle admin. La valeur par défaut publiée dans les anciennes
// versions du dépôt (« Admin123! ») est refusée.

const bcrypt = require('bcryptjs');
const pool = require('../config/database');
const {
  assertStrongAdminPassword,
  resolveAdminIdentity,
} = require('../config/admin_account');

function notFound(email) {
  const error = new Error(
    email
      ? `Aucun compte administrateur avec l’adresse ${email}.`
      : 'Aucun compte administrateur en base. Lancez d’abord la migration.',
  );
  error.code = 'ADMIN_NOT_FOUND';
  return error;
}

/**
 * Met à jour le hash du compte administrateur.
 *
 * @param {object} [options]
 * @param {object} [options.env] Variables d’environnement.
 * @param {(sql: string, values: unknown[]) => Promise<{rows: object[]}>} [options.query]
 * @param {(value: string) => Promise<string>} [options.hashPassword]
 */
async function setAdminPassword({
  env = process.env,
  query = (sql, values) => pool.query(sql, values),
  hashPassword = (value) => bcrypt.hash(value, 10),
} = {}) {
  // Le mot de passe est validé avant toute requête : une valeur faible ne doit
  // jamais atteindre la base, même sur un compte existant.
  const password = assertStrongAdminPassword(env.ADMIN_PASSWORD);
  const configuredEmail = String(env.ADMIN_EMAIL || '').trim();

  let email = configuredEmail.toLowerCase();
  if (!email) {
    const admin = await query(
      "SELECT email FROM users WHERE role = 'admin' ORDER BY id LIMIT 1",
      [],
    );
    if (admin.rows.length === 0) throw notFound();
    email = String(admin.rows[0].email).toLowerCase();
  }

  const passwordHash = await hashPassword(password);
  const result = await query(
    `UPDATE users
        SET password_hash = $1,
            updated_at = CURRENT_TIMESTAMP
      WHERE LOWER(email) = $2
      RETURNING id, email`,
    [passwordHash, email],
  );

  if (result.rows.length === 0) throw notFound(email);

  return result.rows[0];
}

if (require.main === module) {
  setAdminPassword()
    .then((admin) => {
      console.log(`✅ Mot de passe administrateur mis à jour : ${admin.email}`);
      console.log('   Les jetons déjà émis restent valides jusqu’à expiration.');
    })
    .catch((error) => {
      console.error(`❌ ${error.message}`);
      process.exitCode = 1;
    })
    .finally(() => pool.end());
}

module.exports = { setAdminPassword };
