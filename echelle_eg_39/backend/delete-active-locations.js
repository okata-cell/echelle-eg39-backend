// Script pour supprimer toutes les locations actives (en_cours)
// Usage: DATABASE_URL=postgresql://... node delete-active-locations.js

const { Pool } = require('pg');
require('dotenv').config();

const databaseUrl = process.env.DATABASE_URL;

if (!databaseUrl) {
  console.log('❌ DATABASE_URL non définie!');
  console.log('💡 Sur Render Dashboard > votre database > Copies le Internal Database URL');
  console.log('   Ex: DATABASE_URL=postgresql://user:pass@host:port/db node delete-active-locations.js');
  process.exit(1);
}

const pool = new Pool({
  connectionString: databaseUrl,
  ssl: { require: true }
});

async function deleteActiveLocations() {
  try {
    console.log('🔌 Connexion à la base de données...');
    
    // Étape 1: Rendre les appareils disponibles
    console.log('📱 Rendre les appareils disponibles...');
    await pool.query(`
      UPDATE appareils 
      SET disponible = true 
      WHERE id IN (
        SELECT DISTINCT appareil_id 
        FROM locations 
        WHERE statut = 'en_cours' 
        AND appareil_id IS NOT NULL
      )
    `);
    
    // Étape 2: Supprimer les locations actives
    console.log('🗑️ Supprimer les locations actives...');
    const result = await pool.query(`
      DELETE FROM locations 
      WHERE statut = 'en_cours' 
      RETURNING id, code, appareil_nom
    `);
    
    console.log(`✅ ${result.rowCount} locations supprimées:`);
    result.rows.forEach(loc => {
      console.log(`   - ${loc.code}: ${loc.appareil_nom}`);
    });
    
    // Vérifier le résultat
    const remaining = await pool.query("SELECT COUNT(*) as total FROM locations");
    console.log(`📊 Locations restantes dans la DB: ${remaining.rows[0].total}`);
    
    await pool.end();
    console.log('✅ Terminé!');
    process.exit(0);
    
  } catch (error) {
    console.error('❌ Erreur:', error.message);
    await pool.end();
    process.exit(1);
  }
}

deleteActiveLocations();