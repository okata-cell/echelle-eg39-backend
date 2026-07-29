const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const pool = require('../config/database');
const { authMiddleware, adminMiddleware } = require('../middleware/auth');

// Soumettre une demande de devis (public)
router.post('/', [
  body('serviceId').optional().isString(),
  body('serviceName').optional().isString(),
  body('description').optional().isString(),
  body('nom').trim().notEmpty().withMessage('Le nom est requis'),
  body('telephone').optional().isString(),
  body('email').optional().isEmail().withMessage('Email invalide'),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { serviceId, serviceName, description, nom, telephone, email } = req.body;

    const result = await pool.query(
      `INSERT INTO devis (service_id, service_name, description, nom, telephone, email, statut, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, 'nouveau', CURRENT_TIMESTAMP)
       RETURNING *`,
      [serviceId || null, serviceName || null, description || null, nom, telephone || null, email || null]
    );

    const devis = result.rows[0];

    res.status(201).json({
      message: 'Demande de devis soumise avec succès',
      devis: {
        id: devis.id,
        serviceName: devis.service_name,
        nom: devis.nom,
        statut: devis.statut,
        createdAt: devis.created_at,
      }
    });
  } catch (error) {
    console.error('Erreur soumission devis:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Lister les demandes de devis (admin seulement)
router.get('/', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { statut } = req.query;

    let query = 'SELECT * FROM devis';
    const params = [];
    const conditions = [];

    if (statut) {
      params.push(statut);
      conditions.push(`statut = $${params.length}`);
    }

    if (conditions.length > 0) {
      query += ' WHERE ' + conditions.join(' AND ');
    }

    query += ' ORDER BY created_at DESC';

    const result = await pool.query(query, params);

    res.json({ devis: result.rows });
  } catch (error) {
    console.error('Erreur liste devis:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Mettre à jour le statut d'un devis (admin seulement)
router.patch('/:id/statut', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const { statut } = req.body;

    if (!statut || !['nouveau', 'en_cours', 'envoye', 'termine'].includes(statut)) {
      return res.status(400).json({ error: 'Statut invalide' });
    }

    const result = await pool.query(
      `UPDATE devis 
       SET statut = $1, updated_at = CURRENT_TIMESTAMP 
       WHERE id = $2 
       RETURNING *`,
      [statut, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Devis non trouvé' });
    }

    res.json({
      message: 'Statut du devis mis à jour',
      devis: result.rows[0]
    });
  } catch (error) {
    console.error('Erreur mise à jour devis:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Supprimer un devis (admin seulement)
router.delete('/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { id } = req.params;

    const result = await pool.query('DELETE FROM devis WHERE id = $1 RETURNING *', [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Devis non trouvé' });
    }

    res.json({ message: 'Devis supprimé' });
  } catch (error) {
    console.error('Erreur suppression devis:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

module.exports = router;