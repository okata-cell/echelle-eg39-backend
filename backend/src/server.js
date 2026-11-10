const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
require('dotenv').config();

const { buildCorsOptions, securityWarnings } = require('./config/cors');
const { loadRevokedAccounts } = require('./services/session_revocation');
const {
  describeDeliveryChannels,
  deliveryWarnings,
} = require('./services/notification_service');

const app = express();
const PORT = process.env.PORT || 3000;

// Render place le service derrière un proxy : sans cela, req.ip renvoie
// l'adresse du proxy et la limitation des tentatives de connexion devient
// inopérante.
app.set('trust proxy', 1);

// Middleware
app.use(helmet());
app.use(cors(buildCorsOptions()));
app.use(express.json({ limit: '4mb' }));
app.use(morgan('dev'));

// Routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/profile', require('./routes/profile'));
app.use('/api/appareils', require('./routes/appareils'));
app.use('/api/demandes', require('./routes/demandes'));
app.use('/api/devis', require('./routes/devis'));
app.use('/api/locations', require('./routes/locations'));
app.use('/api/prolongations', require('./routes/prolongations'));
app.use('/api/promotions', require('./routes/promotions'));
app.use('/api/actualites', require('./routes/actualites'));
// Activité des demandes clientes : flux temps réel et rattrapage pour l'admin.
app.use('/api/admin/activity', require('./routes/admin_activity'));
// La gestion des comptes clients (édition, activation) doit être déclarée
// avant le routeur /api/users pour que ses PATCH ne soient pas masqués.
app.use('/api/users/clients', require('./routes/admin_clients'));
app.use('/api/users', require('./routes/users'));

// Route de santé
// `/health` sert aussi de diagnostic : les canaux d'envoi (e-mail, SMS) sont
// annoncés configurés ou non, sans jamais exposer de clé.
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    delivery: describeDeliveryChannels(),
  });
});

// Route racine
app.get('/', (req, res) => {
  res.json({
    message: 'API ÉCHELLE EG39 - Topographie & BTP',
    version: '1.0.0',
    endpoints: {
      auth: '/api/auth',
      profile: '/api/profile',
      appareils: '/api/appareils',
      demandes: '/api/demandes',
      devis: '/api/devis',
      locations: '/api/locations',
      prolongations: '/api/prolongations',
      actualites: '/api/actualites',
      users: '/api/users',
      clients: '/api/users/clients'
    }
  });
});

// Pages publiques servies sans compte : politique de confidentialité,
// suppression de compte, conditions d'utilisation (exigées par les stores) et
// page de test qui distribue les APK Android hors magasin.
app.use('/', require('./routes/public_pages'));

// Gestion des erreurs 404
app.use((req, res) => {
  res.status(404).json({ error: 'Route non trouvée' });
});

// Gestion des erreurs globales
app.use((err, req, res, next) => {
  console.error('Erreur:', err);
  res.status(500).json({ error: 'Erreur serveur interne' });
});

// Démarrage du serveur uniquement lorsqu’il est lancé comme processus principal.
if (require.main === module) {
  for (const warning of securityWarnings()) {
    console.warn(`⚠️  ${warning}`);
  }

  for (const warning of deliveryWarnings()) {
    console.warn(`⚠️  ${warning}`);
  }

  // La liste des comptes dont la session est fermée est tenue en mémoire : elle
  // est reconstruite depuis la base avant d'accepter la première requête.
  loadRevokedAccounts()
    .catch((error) => {
      console.warn(
        '⚠️  Impossible de recharger les comptes supprimés ou désactivés : ' +
          `${error.message}. Les jetons déjà émis restent acceptés.`,
      );
    })
    .finally(() => {
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
    });
}

module.exports = app;