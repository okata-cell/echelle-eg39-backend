const express = require('express');

const pool = require('../config/database');
const { authMiddleware, adminMiddleware } = require('../middleware/auth');
const { maskEmail } = require('../utils/anonymize');

const router = express.Router();

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