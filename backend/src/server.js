const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
require('dotenv').config();
const pool = require('./config/database');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(helmet());
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || '*',
  credentials: true
}));
app.use(express.json());
app.use(morgan('dev'));

// Routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/users/clients', require('./routes/admin_clients'));
app.use('/api/appareils', require('./routes/appareils'));
app.use('/api/demandes', require('./routes/demandes'));
app.use('/api/devis', require('./routes/devis'));
app.use('/api/locations', require('./routes/locations'));
app.use('/api/prolongations', require('./routes/prolongations'));

// Route de santé
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Route racine
app.get('/', (req, res) => {
  res.json({
    message: 'API ÉCHELLE EG39 - Topographie & BTP',
    version: '1.0.0',
    endpoints: {
      auth: '/api/auth',
      users: '/api/users',
      clients: '/api/users/clients',
      appareils: '/api/appareils',
      demandes: '/api/demandes',
      devis: '/api/devis',
      locations: '/api/locations',
      prolongations: '/api/prolongations'
    }
  });
});

// Gestion des erreurs 404
app.use((req, res) => {
  res.status(404).json({ error: 'Route non trouvée' });
});

// Gestion des erreurs globales
app.use((err, req, res, next) => {
  console.error('Erreur:', err);
  res.status(500).json({ error: 'Erreur serveur interne' });
});

// Le schéma est mis à niveau avant d'accepter les requêtes, sans supprimer d'historique.
async function startServer() {
  try {
    await pool.query(
      'ALTER TABLE users ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE',
    );
  } catch (error) {
    console.error('Impossible de préparer le schéma des comptes clients:', error);
    await pool.end();
    process.exitCode = 1;
    return;
  }

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

if (require.main === module) {
  startServer();
}

module.exports = app;