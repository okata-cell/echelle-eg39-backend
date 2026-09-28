const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const pool = require('../config/database');
const { authMiddleware, adminMiddleware } = require('../middleware/auth');

// Liste des demandes d'achat.
router.get('/', authMiddleware, async (req, res) => {
  try {
    const { statut } = req.query;
    let query = `
      SELECT d.*, u.first_name, u.last_name, u.email, u.phone
      FROM demandes_achat d
      JOIN users u ON d.user_id = u.id
    `;
    const params = [];

    if (req.user.role === 'client') {
      query += ' WHERE d.user_id = $1';
      params.push(req.user.userId);
    }

    if (statut && req.user.role === 'admin') {
      query += ' WHERE d.statut = $1';
      params.push(statut);
    } else if (statut && req.user.role === 'client') {
      query += ' AND d.statut = $2';
      params.push(statut);
    }

    query += ' ORDER BY d.created_at DESC';
    const result = await pool.query(query, params);

    return res.json({
      demandes: result.rows.map((d) => ({
        id: d.id,
        code: d.code,
        clientNom: `${d.first_name} ${d.last_name}`,
        clientEmail: d.email,
        clientPhone: d.phone,
        appareilNom: d.appareil_nom,
        appareilPrix: d.appareil_prix,
        quantite: d.quantite,
        total: d.total,
        statut: d.statut,
        commentaireAdmin: d.commentaire_admin,
        createdAt: d.created_at,
      })),
    });
  } catch (error) {
    console.error('Erreur liste demandes:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Supprimer une demande terminée, livrée ou rejetée.
router.delete('/:id', authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(
      'SELECT id, user_id, statut FROM demandes_achat WHERE id = $1',
      [id],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Demande non trouvée' });
    }

    const demande = result.rows[0];
    const isOwner = Number(demande.user_id) === Number(req.user.userId);
    if (req.user.role !== 'admin' && !isOwner) {
      return res.status(403).json({ error: 'Non autorisé' });
    }

    if (!['termine', 'livree', 'rejetee'].includes(demande.statut)) {
      return res.status(400).json({
        error: 'Impossible de supprimer une demande en cours ou en attente',
      });
    }

    await pool.query('DELETE FROM demandes_achat WHERE id = $1', [id]);
    return res.json({ message: 'Demande supprimée' });
  } catch (error) {
    console.error('Erreur suppression demande:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Créer une demande d'achat.
router.post('/', authMiddleware, [
  body('appareilId').isInt().withMessage('ID appareil requis'),
  body('quantite').optional().isInt({ min: 1 }).withMessage('Quantité invalide'),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { appareilId, quantite = 1 } = req.body;
    const appareilResult = await pool.query(
      'SELECT * FROM appareils WHERE id = $1',
      [appareilId],
    );

    if (appareilResult.rows.length === 0) {
      return res.status(404).json({ error: 'Appareil non trouvé' });
    }

    const appareil = appareilResult.rows[0];
    const total = appareil.prix_vente * quantite;
    const code = `DA-${Date.now()}`;
    const result = await pool.query(
      `INSERT INTO demandes_achat (code, user_id, appareil_id, appareil_nom, appareil_prix, quantite, total)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [code, req.user.userId, appareilId, appareil.nom, appareil.prix_vente, quantite, total],
    );
    const demande = result.rows[0];

    return res.status(201).json({
      message: 'Demande d’achat créée',
      demande: {
        id: demande.id,
        code: demande.code,
        appareilNom: demande.appareil_nom,
        quantite: demande.quantite,
        total: demande.total,
        statut: demande.statut,
        createdAt: demande.created_at,
      },
    });
  } catch (error) {
    console.error('Erreur création demande:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Modifier le statut d'une demande (admin).
router.patch('/:id/statut', authMiddleware, adminMiddleware, [
  body('statut').isIn(['approuvee', 'rejetee', 'livree', 'termine']).withMessage('Statut invalide'),
  body('commentaire').optional().trim(),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { id } = req.params;
    const { statut, commentaire } = req.body;
    const result = await pool.query(
      `UPDATE demandes_achat
       SET statut = $1, commentaire_admin = $2, updated_at = CURRENT_TIMESTAMP
       WHERE id = $3
       RETURNING *`,
      [statut, commentaire || null, id],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Demande non trouvée' });
    }

    return res.json({ message: 'Statut mis à jour', demande: result.rows[0] });
  } catch (error) {
    console.error('Erreur modification statut:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

module.exports = router;
