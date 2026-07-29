const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const pool = require('../config/database');
const { authMiddleware, adminMiddleware } = require('../middleware/auth');

// Liste des prolongations
router.get('/', authMiddleware, async (req, res) => {
  try {
    let query = `
      SELECT p.*, l.appareil_nom, l.user_id, u.first_name, u.last_name
      FROM prolongations p
      JOIN locations l ON p.location_id = l.id
      JOIN users u ON l.user_id = u.id
    `;
    const params = [];

    // Client voit seulement ses prolongations
    if (req.user.role === 'client') {
      query += ' WHERE l.user_id = $1';
      params.push(req.user.userId);
    }

    query += ' ORDER BY p.created_at DESC';

    const result = await pool.query(query, params);

    res.json({
      prolongations: result.rows.map(p => ({
        id: p.id,
        code: p.code,
        locationId: p.location_id,
        appareilNom: p.appareil_nom,
        clientNom: `${p.first_name} ${p.last_name}`,
        ancienneDateFin: p.ancienne_date_fin,
        nouvelleDateFin: p.nouvelle_date_fin,
        joursSupplementaires: p.jours_supplementaires,
        coutSupplementaire: p.cout_supplementaire,
        factureNumero: p.facture_numero,
        estPaye: p.est_paye,
        datePaiement: p.date_paiement,
        createdAt: p.created_at
      }))
    });
  } catch (error) {
    console.error('Erreur liste prolongations:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Créer une prolongation (client)
router.post('/', authMiddleware, [
  body('locationId').isInt().withMessage('ID location requis'),
  body('nouvelleDateFin').isISO8601().toDate().withMessage('Date fin invalide'),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { locationId, nouvelleDateFin } = req.body;

    // Récupérer la location
    const locationResult = await pool.query(
      'SELECT * FROM locations WHERE id = $1 AND user_id = $2',
      [locationId, req.user.userId]
    );

    if (locationResult.rows.length === 0) {
      return res.status(404).json({ error: 'Location non trouvée' });
    }

    const location = locationResult.rows[0];

    // Vérifier le nombre de prolongations existantes
    const countResult = await pool.query(
      'SELECT COUNT(*) as count FROM prolongations WHERE location_id = $1',
      [locationId]
    );

    if (parseInt(countResult.rows[0].count) >= 3) {
      return res.status(400).json({ error: 'Maximum 3 prolongations atteintes' });
    }

    // Calculer les détails
    const ancienneFin = new Date(location.date_fin);
    const nouvelleFin = new Date(nouvelleDateFin);
    const joursSupplementaires = Math.ceil((nouvelleFin - ancienneFin) / (1000 * 60 * 60 * 24));
    
    if (joursSupplementaires <= 0 || joursSupplementaires > 30) {
      return res.status(400).json({ error: 'Prolongation invalide (max 30 jours)' });
    }

    const coutSupplementaire = location.prix_journalier * joursSupplementaires;
    const code = `EXT-${Date.now()}`;
    const factureNumero = `INV-EXT-${locationId}-${parseInt(countResult.rows[0].count) + 1}`;

    const result = await pool.query(
      `INSERT INTO prolongations (code, location_id, ancienne_date_fin, nouvelle_date_fin, jours_supplementaires, cout_supplementaire, facture_numero)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [code, locationId, location.date_fin, nouvelleDateFin, joursSupplementaires, coutSupplementaire, factureNumero]
    );

    // Mettre à jour la location
    const nouveauTotal = location.montant_total + coutSupplementaire;
    await pool.query(
      'UPDATE locations SET date_fin = $1, montant_total = $2, updated_at = CURRENT_TIMESTAMP WHERE id = $3',
      [nouvelleDateFin, nouveauTotal, locationId]
    );

    const prolongation = result.rows[0];

    res.status(201).json({
      message: 'Prolongation créée',
      prolongation: {
        id: prolongation.id,
        code: prolongation.code,
        joursSupplementaires: prolongation.jours_supplementaires,
        coutSupplementaire: prolongation.cout_supplementaire,
        nouvelleDateFin: prolongation.nouvelle_date_fin,
        factureNumero: prolongation.facture_numero
      }
    });
  } catch (error) {
    console.error('Erreur création prolongation:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Marquer une prolongation comme payée (admin)
router.patch('/:id/payer', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { id } = req.params;

    const result = await pool.query(
      `UPDATE prolongations
       SET est_paye = true, date_paiement = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
       WHERE id = $1
       RETURNING *`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Prolongation non trouvée' });
    }

    res.json({ message: 'Prolongation marquée comme payée' });
  } catch (error) {
    console.error('Erreur paiement prolongation:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

module.exports = router;