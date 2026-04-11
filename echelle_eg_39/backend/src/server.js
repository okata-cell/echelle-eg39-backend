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

// Debug: voir tous les appareils
app.get('/debug-appareils', async (req, res) => {
  try {
    const result = await pool.query('SELECT id, code, nom, type FROM appareils ORDER BY id');
    res.json({ appareils: result.rows });
  } catch (err) {
    console.error('❌ Erreur debug appareils:', err);
    res.status(500).json({ error: err.message });
  }
});

// Debug: forcer l'insertion des appareils manquants
app.get('/fix-appareils', async (req, res) => {
  try {
    const defaultAppareils = [
      ['APP-001', 'GPS e-survey E600', 'GPS', 'https://images.unsplash.com/photo-1581092334494-8b6a8c3a52f3', 25000, 2500000],
      ['APP-002', 'GPS e-survey E800', 'GPS', 'https://images.unsplash.com/photo-1590650153855-d9e808231d41', 15000, 1200000],
      ['APP-003', 'Niveau Leica', 'Niveau', 'https://images.unsplash.com/photo-1590650153855-d9e808231d41', 15000, 1200000],
      ['APP-004', 'Niveau Auto Leica', 'Niveau', 'https://images.unsplash.com/photo-1506744038136-46273834b3fb', 30000, 3500000],
      ['APP-005', 'Station Totale Leica TS06', 'Station totale', 'https://images.unsplash.com/photo-1506744038136-46273834b3fb', 30000, 3500000],
      ['APP-006', 'Station Totale Sokkia', 'Theodolite', 'https://images.unsplash.com/photo-1506744038136-46273834b3fb', 30000, 3500000],
      ['APP-007', 'GPS e-survey 3600', 'GPS', 'https://images.unsplash.com/photo-1581092334494-8b6a8c3a52f3', 25000, 2500000],
      ['APP-008', 'Trepied Leica', 'Trepied', 'https://images.unsplash.com/photo-1590650153855-d9e808231d41', 15000, 1200000],
      ['APP-009', 'Mire Stadimetrique', 'Mire', 'https://images.unsplash.com/photo-1590650153855-d9e808231d41', 15000, 1200000],
      ['APP-010', 'Antenne GPS RTK', 'Antenne', 'https://m.media-amazon.com/images/I/41B4Q7zJuhL._AC_UF894,1000_QL80_.jpg', 50000, 5000000],
      ['APP-011', 'Canne GPS', 'Canne', 'https://m.media-amazon.com/images/I/61D+67Fr13L.jpg', 12000, 1200000],
      ['APP-012', 'Réflecteur Leica', 'Réflecteur', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTwpQLIsIgCIxYZJ7erX8al95F12_iasdiQ6g&s', 8000, 800000],
      ['APP-013', 'Drone topographique', 'Drone', 'https://images.unsplash.com/photo-1506947411487-a56738267384', 100000, 10000000],
    ];
    
    let inserted = 0;
    for (const [code, nom, type, imageUrl, prixLocation, prixVente] of defaultAppareils) {
      await pool.query(`
        INSERT INTO appareils (code, nom, type, image_url, prix_location, prix_vente, disponible)
        VALUES ($1, $2, $3, $4, $5, $6, true)
        ON CONFLICT (code) DO UPDATE SET nom = EXCLUDED.nom, type = EXCLUDED.type, image_url = EXCLUDED.image_url, prix_location = EXCLUDED.prix_location, prix_vente = EXCLUDED.prix_vente, disponible = true
      `, [code, nom, type, imageUrl, prixLocation, prixVente]);
      inserted++;
    }
    
    const result = await pool.query('SELECT id, code, nom, type, disponible FROM appareils ORDER BY id');
    res.json({ message: `${inserted} appareils inserted/updated`, appareils: result.rows });
  } catch (err) {
    console.error('❌ Erreur fix appareils:', err);
    res.status(500).json({ error: err.message });
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
