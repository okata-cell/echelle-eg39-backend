const express = require('express');
require('express-async-errors'); // Doit être importé avant tout autre module
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
require('dotenv').config();

const { Pool } = require('pg');
const { runMigrations } = require('./config/migrate');

const app = express();
const PORT = process.env.PORT || 3000;

// ---------- CONFIGURATION POSTGRESQL ----------
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
});

// Vérification connexion DB
pool.connect()
  .then(client => {
    console.log('✅ Connecté à la base de données PostgreSQL');
    client.release();
  })
  .catch(err => {
    console.error('❌ Erreur de connexion PostgreSQL:', err);
    process.exit(-1); // stoppe le serveur si DB non joignable
  });

// ---------- MIDDLEWARE ----------
app.use(helmet());
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || '*',
  credentials: true
}));
app.use(express.json());
app.use(morgan('dev'));

// ---------- ROUTES EXISTANTES ----------
app.use('/api/auth', require('./routes/auth'));
app.use('/api/appareils', require('./routes/appareils'));
app.use('/api/demandes', require('./routes/demandes'));
app.use('/api/locations', require('./routes/locations'));
app.use('/api/prolongations', require('./routes/prolongations'));

// ---------- ROUTE DE SANTÉ ----------
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// ---------- ROUTE RACINE ----------
app.get('/', (req, res) => {
  res.json({
    message: 'API ÉCHELLE EG39 - Topographie & BTP',
    version: '1.0.0',
    endpoints: {
      auth: '/api/auth',
      appareils: '/api/appareils',
      demandes: '/api/demandes',
      locations: '/api/locations',
      prolongations: '/api/prolongations'
    }
  });
});

// ---------- ROUTE DE TEST DB ----------
app.get('/test-db', async (req, res) => {
  try {
    const result = await pool.query('SELECT NOW()');
    res.json({ message: '✅ DB connectée !', serverTime: result.rows[0].now });
  } catch (err) {
    console.error('❌ Erreur test DB:', err);
    res.status(500).json({ error: 'Erreur connexion DB' });
  }
});

// ---------- GESTION DES ERREURS ----------
app.use((req, res) => {
  res.status(404).json({ error: 'Route non trouvée' });
});

app.use((err, req, res, next) => {
  console.error('Erreur serveur:', err);
  res.status(500).json({ error: 'Erreur serveur interne' });
});

// ---------- TÂCHE AUTOMATIQUE: EXPIRATION DES LOCATIONS ----------
async function checkExpiredLocations() {
  try {
    // Trouver les locations expirées (dateFin < aujourd'hui)
    const today = new Date().toISOString().split('T')[0];
    
    const expiredResult = await pool.query(
      "SELECT l.id, l.code, l.appareil_id, l.date_fin FROM locations l WHERE statut = 'en_cours' AND date_fin < $1",
      [today]
    );
    
    if (expiredResult.rows.length > 0) {
      console.log(`⏰ ${expiredResult.rows.length} location(s) expirée(s) trouvée(s)`);
      
      for (const loc of expiredResult.rows) {
        // Marquer comme terminée
        await pool.query(
          "UPDATE locations SET statut = 'termine', updated_at = NOW() WHERE id = $1",
          [loc.id]
        );
        
        // Rendre l'appareil disponible
        if (loc.appareil_id) {
          await pool.query('UPDATE appareils SET disponible = true WHERE id = $1', [loc.appareil_id]);
        }
        
        console.log(`✅ Location ${loc.code} expirée - appareil libéré`);
      }
    }
  } catch (e) {
    console.error('❌ Erreur vérification locations expirées:', e);
  }
}

// ---------- DÉMARRAGE DU SERVEUR AVEC MIGRATIONS ----------
(async () => {
  try {
    console.log('🔧 Exécution des migrations au démarrage...');
    await runMigrations({ closePool: false });
    console.log('✅ Migrations terminées');
    
    // Vérifier les locations expirées
    console.log('🔍 Vérification des locations expirées...');
    await checkExpiredLocations();
  } catch (e) {
    console.error('❌ Échec des migrations:', e);
  } finally {
    app.listen(PORT, () => {
      console.log(`
      ╔═══════════════════════════════════════════════════════════╗
      ║                                                           ║
      ║         🚀 ÉCHELLE EG39 API - DÉMARRÉ                    ║
      ║                                                           ║
      ║         📡 Port: ${PORT}                                   ║
      ║         🌍 Environnement: ${process.env.NODE_ENV || 'development'}              ║
      ║         📅 Date: ${new Date().toLocaleString()}          ║
      ║                                                           ║
      ╚═══════════════════════════════════════════════════════════╝
      `);
    });
  }
})();

module.exports = app;
