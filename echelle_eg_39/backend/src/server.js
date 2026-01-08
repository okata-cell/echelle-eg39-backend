const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
require('dotenv').config();

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
app.use('/api/appareils', require('./routes/appareils'));
app.use('/api/demandes', require('./routes/demandes'));
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
      appareils: '/api/appareils',
      demandes: '/api/demandes',
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

// Démarrage du serveur
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


module.exports = app;