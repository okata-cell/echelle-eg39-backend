const express = require('express');
const pool = require('../config/database');
const { authMiddleware, adminMiddleware } = require('../middleware/auth');

const router = express.Router();

router.get('/', authMiddleware, adminMiddleware, async (req, res) => {
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
    console.error('Erreur récupération clients:', error);
    return res.status(500).json({
      error: 'Erreur serveur lors de la récupération des clients',
    });
  }
});

module.exports = router;
