const { Pool } = require('pg');
const bcrypt = require('bcryptjs');

const pool = new Pool({
  connectionString: 'postgresql://echelle_eg39_user:nqbcd791pIA8aTfeBbedaVbKXQ1RtvBR@dpg-d6lb50fkijhs73b1s4hg-a.frankfurt-postgres.render.com:5432/echelle_eg39_72f5',
  ssl: { rejectUnauthorized: false }
});

async function resetPassword() {
  try {
    const email = 'silvaokata@gmail.com';
    const newPassword = 'Test123!';

    // Vérifier que l'utilisateur existe
    const check = await pool.query(
      'SELECT id, email, first_name, last_name FROM users WHERE email = $1',
      [email]
    );

    if (check.rows.length === 0) {
      console.log('Utilisateur non trouvé:', email);
      return;
    }

    const user = check.rows[0];
    console.log('Utilisateur trouvé:', user);

    // Hasher le nouveau mot de passe
    const hashedPassword = await bcrypt.hash(newPassword, 10);
    console.log('Nouveau hash généré:', hashedPassword);

    // Mettre à jour en base
    await pool.query(
      'UPDATE users SET password_hash = $1 WHERE email = $2',
      [hashedPassword, email]
    );
    console.log('Mot de passe mis à jour avec succès pour:', email);
  } catch (error) {
    console.error('Erreur:', error.message);
  } finally {
    await pool.end();
  }
}

resetPassword();
