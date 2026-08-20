const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { authMiddleware, adminMiddleware } = require('../middleware/auth');

// Récupérer toutes les promotions (admin seulement)
router.get('/', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT * FROM promotions 
      ORDER BY created_at DESC
    `);
    res.json({ promotions: result.rows });
  } catch (error) {
    console.error('Erreur liste promotions:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Récupérer la promotion active (public - pour le popup client)
router.get('/active', async (req, res) => {
  try {
    const now = new Date().toISOString().split('T')[0];
    const result = await pool.query(`
      SELECT * FROM promotions 
      WHERE actif = true 
        AND date_debut <= $1 
        AND date_fin >= $1
      ORDER BY created_at DESC
      LIMIT 1
    `, [now]);

    if (result.rows.length === 0) {
      return res.json({ promotion: null });
    }

    res.json({ promotion: result.rows[0] });
  } catch (error) {
    console.error('Erreur promotion active:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Créer une promotion (admin seulement)
router.post('/', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { titre, description, image_url, date_debut, date_fin, actif, frequence } = req.body;

    if (!titre || !description || !date_debut || !date_fin) {
      return res.status(400).json({ error: 'Titre, description, date de début et date de fin sont requis' });
    }

    const result = await pool.query(`
      INSERT INTO promotions (titre, description, image_url, date_debut, date_fin, actif, frequence, created_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      RETURNING *
    `, [titre, description, image_url || null, date_debut, date_fin, actif ?? true, frequence || 'chaque_ouverture']);

    const promotion = result.rows[0];

    res.status(201).json({
      message: 'Promotion créée avec succès',
      promotion: promotion
    });
  } catch (error) {
    console.error('Erreur création promotion:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Activer/désactiver une promotion (admin seulement)
router.patch('/:id/toggle', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const { actif } = req.body;

    const result = await pool.query(
      `UPDATE promotions 
       SET actif = $1, updated_at = CURRENT_TIMESTAMP 
       WHERE id = $2 
       RETURNING *`,
      [actif, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Promotion non trouvée' });
    }

    res.json({
      message: 'Promotion mise à jour',
      promotion: result.rows[0]
    });
  } catch (error) {
    console.error('Erreur toggle promotion:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Supprimer une promotion (admin seulement)
router.delete('/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { id } = req.params;

    const result = await pool.query('DELETE FROM promotions WHERE id = $1 RETURNING *', [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Promotion non trouvée' });
    }

    res.json({ message: 'Promotion supprimée' });
  } catch (error) {
    console.error('Erreur suppression promotion:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

module.exports = router;
