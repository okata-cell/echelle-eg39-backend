const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  // SSL requis pour Render et autres services cloud
  ssl: {
    rejectUnauthorized: false,
    require: true
  }
});

// Test de connexion
pool.on('connect', () => {
  console.log('✅ Connecté à la base de données PostgreSQL');
});

pool.on('error', (err) => {
  console.error('❌ Erreur PostgreSQL:', err);
  process.exit(-1);
});

module.exports = pool;
