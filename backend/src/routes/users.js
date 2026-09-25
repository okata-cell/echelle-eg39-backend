const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { authMiddleware, adminMiddleware } = require('../middleware/auth');

// =============================================================================
// CLIENTS (ADMIN)
// =============================================================================

// GET /api/users — Liste tous les utilisateurs (admin uniquement)
// Retourne les utilisateurs avec leurs infos (non sensibles).
// Le mot de passe n'est jamais inclus dans la réponse.
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
    console.error('Erreur récupération clients:', error);
    return res.status(500).json({ error: 'Erreur serveur lors de la récupération des clients' });
  }
});

router.get('/', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, first_name, last_name, email, phone, role, created_at, updated_at
       FROM users
       ORDER BY created_at DESC`
    );

    const users = result.rows.map((user) => ({
      id: user.id,
      firstName: user.first_name,
      lastName: user.last_name,
      email: user.email,
      phone: user.phone,
      role: user.role,
      createdAt: user.created_at,
      updatedAt: user.updated_at,
    }));

    res.json({ users });
  } catch (error) {
    console.error('Erreur récupération utilisateurs:', error);
    res.status(500).json({ error: 'Erreur serveur lors de la récupération des utilisateurs' });
  }
});

// DELETE /api/users/:id — Supprimer un utilisateur (admin uniquement)
// Empêche la suppression du dernier admin.
router.delete('/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const userId = parseInt(req.params.id, 10);

    if (isNaN(userId)) {
      return res.status(400).json({ error: 'ID utilisateur invalide' });
    }

    // Vérifier que l'utilisateur existe
    const existingUser = await pool.query(
      'SELECT role FROM users WHERE id = $1',
      [userId]
    );

    if (existingUser.rows.length === 0) {
      return res.status(404).json({ error: 'Utilisateur non trouvé' });
    }

    // Empêcher la suppression du dernier admin
    if (existingUser.rows[0].role === 'admin') {
      const adminCount = await pool.query(
        "SELECT COUNT(*) FROM users WHERE role = 'admin'"
      );
      if (parseInt(adminCount.rows[0].count, 10) <= 1) {
        return res.status(400).json({
          error: 'Impossible de supprimer le dernier administrateur',
        });
      }
    }

    // Supprimer l'utilisateur (cascade sur clients, locations, demandes, etc.)
    await pool.query('DELETE FROM users WHERE id = $1', [userId]);

    res.json({ message: 'Utilisateur supprimé avec succès' });
  } catch (error) {
    console.error('Erreur suppression utilisateur:', error);
    res.status(500).json({ error: 'Erreur serveur lors de la suppression' });
  }
});

module.exports = router;
