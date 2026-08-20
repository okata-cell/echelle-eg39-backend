const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const pool = require('../config/database');
const { authMiddleware, adminMiddleware } = require('../middleware/auth');

const DEVIS_STATUSES = [
  'en_attente',
  'approuvee',
  'rejetee',
  'en_cours',
  'envoye',
  'termine',
];

function mapDevis(devis) {
  return {
    id: devis.id,
    serviceId: devis.service_id,
    serviceName: devis.service_name,
    description: devis.description,
    nom: devis.nom,
    telephone: devis.telephone,
    email: devis.email,
    statut: devis.statut,
    commentaireAdmin: devis.commentaire_admin,
    createdAt: devis.created_at,
    updatedAt: devis.updated_at,
  };
}

function sendValidationErrors(req, res) {
  const errors = validationResult(req);
  if (errors.isEmpty()) return false;

  res.status(400).json({ errors: errors.array() });
  return true;
}

// Soumettre une demande de devis (public).
router.post('/', [
  body('serviceId').optional().isString(),
  body('serviceName').optional().isString(),
  body('description').optional().isString(),
  body('nom').trim().notEmpty().withMessage('Le nom est requis'),
  body('telephone').optional().isString(),
  body('email')
    .trim()
    .optional({ checkFalsy: true })
    .isEmail()
    .withMessage('Email invalide'),
], async (req, res) => {
  if (sendValidationErrors(req, res)) return;

  try {
    const { serviceId, serviceName, description, nom, telephone, email } = req.body;

    const result = await pool.query(
      `INSERT INTO devis (
        service_id,
        service_name,
        description,
        nom,
        telephone,
        email,
        statut,
        created_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, 'en_attente', CURRENT_TIMESTAMP)
      RETURNING *`,
      [serviceId || null, serviceName || null, description || null, nom, telephone || null, email || null],
    );

    return res.status(201).json({
      message: 'Demande de devis soumise avec succès',
      devis: mapDevis(result.rows[0]),
    });
  } catch (error) {
    console.error('Erreur soumission devis:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Lister les demandes de devis (admin seulement).
router.get('/', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { statut } = req.query;
    let query = 'SELECT * FROM devis';
    const params = [];

    if (statut) {
      params.push(statut);
      query += ` WHERE statut = $${params.length}`;
    }

    query += ' ORDER BY created_at DESC';

    const result = await pool.query(query, params);
    return res.json({ devis: result.rows.map(mapDevis) });
  } catch (error) {
    console.error('Erreur liste devis:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Approuver une demande de devis (admin).
router.patch('/:id/approuver', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const existing = await pool.query(
      'SELECT id, statut FROM devis WHERE id = $1',
      [req.params.id],
    );

    if (existing.rows.length === 0) {
      return res.status(404).json({ error: 'Devis non trouvé' });
    }

    if (!['en_attente', 'nouveau'].includes(existing.rows[0].statut)) {
      return res.status(400).json({
        error: 'Cette demande de devis ne peut plus être approuvée',
      });
    }

    const result = await pool.query(
      `UPDATE devis
       SET statut = 'approuvee', updated_at = CURRENT_TIMESTAMP
       WHERE id = $1
       RETURNING *`,
      [req.params.id],
    );

    return res.json({
      message: 'Demande de devis approuvée',
      devis: mapDevis(result.rows[0]),
    });
  } catch (error) {
    console.error('Erreur approbation devis:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Rejeter une demande de devis (admin).
router.patch('/:id/rejeter', authMiddleware, adminMiddleware, [
  body('raison').optional().trim().isLength({ max: 1000 }).withMessage('Motif trop long'),
], async (req, res) => {
  if (sendValidationErrors(req, res)) return;

  try {
    const raison = String(req.body.raison || 'Demande rejetée').trim();
    const existing = await pool.query(
      'SELECT id, statut FROM devis WHERE id = $1',
      [req.params.id],
    );

    if (existing.rows.length === 0) {
      return res.status(404).json({ error: 'Devis non trouvé' });
    }

    if (!['en_attente', 'nouveau'].includes(existing.rows[0].statut)) {
      return res.status(400).json({
        error: 'Cette demande de devis ne peut plus être rejetée',
      });
    }

    const result = await pool.query(
      `UPDATE devis
       SET statut = 'rejetee',
           commentaire_admin = $1,
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $2
       RETURNING *`,
      [raison || 'Demande rejetée', req.params.id],
    );

    return res.json({
      message: 'Demande de devis rejetée',
      devis: mapDevis(result.rows[0]),
    });
  } catch (error) {
    console.error('Erreur rejet devis:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Modifier le statut d'un devis dans le suivi administratif (admin).
router.patch('/:id/statut', authMiddleware, adminMiddleware, [
  body('statut').isIn(DEVIS_STATUSES).withMessage('Statut invalide'),
  body('commentaire').optional().trim(),
  body('commentaire_admin').optional().trim(),
], async (req, res) => {
  if (sendValidationErrors(req, res)) return;

  try {
    const { statut } = req.body;
    const commentaire = String(
      req.body.commentaire ?? req.body.commentaire_admin ?? '',
    ).trim();

    const result = await pool.query(
      `UPDATE devis
       SET statut = $1,
           commentaire_admin = COALESCE(NULLIF($2, ''), commentaire_admin),
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $3
       RETURNING *`,
      [statut, commentaire, req.params.id],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Devis non trouvé' });
    }

    return res.json({
      message: 'Statut du devis mis à jour',
      devis: mapDevis(result.rows[0]),
    });
  } catch (error) {
    console.error('Erreur mise à jour devis:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Supprimer un devis (admin seulement).
router.delete('/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      'DELETE FROM devis WHERE id = $1 RETURNING id',
      [req.params.id],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Devis non trouvé' });
    }

    return res.json({ message: 'Devis supprimé' });
  } catch (error) {
    console.error('Erreur suppression devis:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

module.exports = router;
