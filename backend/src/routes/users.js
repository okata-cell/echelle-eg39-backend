const express = require('express');

const pool = require('../config/database');
const { authMiddleware, adminMiddleware } = require('../middleware/auth');
const { maskEmail } = require('../utils/anonymize');

const router = express.Router();

// Coordonnées nécessaires à la gestion des clients, réservées aux admins.
router.get('/clients', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, first_name, last_name, email, phone, role, created_at
       FROM users
       WHERE role <> 'admin'
       ORDER BY created_at DESC, id DESC`,
    );

    res.set('Cache-Control', 'no-store');
    return res.json({
      clients: result.rows.map((client) => ({
        id: client.id,
        firstName: client.first_name,
        lastName: client.last_name,
        email: client.email,
        phone: client.phone,
        role: client.role || 'client',
        createdAt: client.created_at,
      })),
    });
  } catch (error) {
    console.error('❌ Erreur chargement des clients:', error.message);
    return res.status(500).json({ error: 'Impossible de charger les clients' });
  }
});

// Répertoire volontairement limité aux champs nécessaires à la vérification admin.
router.get('/', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, role, email FROM users ORDER BY id ASC',
    );

    res.set('Cache-Control', 'no-store');
    return res.json({
      users: result.rows.map((user) => ({
        id: user.id,
        role: user.role || 'inconnu',
        maskedEmail: maskEmail(user.email),
      })),
    });
  } catch (error) {
    console.error('❌ Erreur chargement du répertoire anonymisé:', error.message);
    return res.status(500).json({
      error: 'Impossible de charger le répertoire anonymisé',
    });
  }
});

module.exports = router;
