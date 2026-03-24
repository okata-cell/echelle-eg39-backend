const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const pool = require('../config/database');
const { authMiddleware, adminMiddleware } = require('../middleware/auth');

// Liste des locations
router.get('/', authMiddleware, async (req, res) => {
  try {
    const { statut } = req.query;
    
    let query = `
      SELECT l.*, u.first_name, u.last_name, u.email, u.phone
      FROM locations l
      JOIN users u ON l.user_id = u.id
    `;
    const params = [];

    // Admin voit tout, client voit seulement ses locations
    if (req.user.role === 'client') {
      query += ' WHERE l.user_id = $1';
      params.push(req.user.userId);
    }

    if (statut) {
      const whereClause = params.length > 0 ? 'AND' : 'WHERE';
      params.push(statut);
      query += ` ${whereClause} l.statut = $${params.length}`;
    }

    query += ' ORDER BY l.created_at DESC';

    const result = await pool.query(query, params);

    res.json({
      locations: result.rows.map(l => ({
        id: l.id,
        code: l.code,
        clientNom: `${l.first_name} ${l.last_name}`,
        clientEmail: l.email,
        clientPhone: l.phone,
        appareilNom: l.appareil_nom,
        dateDebut: l.date_debut,
        dateFin: l.date_fin,
        prixJournalier: l.prix_journalier,
        montantTotal: l.montant_total,
        statut: l.statut,
        commentaireAdmin: l.commentaire_admin,
        createdAt: l.created_at
      }))
    });
  } catch (error) {
    console.error('Erreur liste locations:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Créer une location (admin ou client)
router.post('/', authMiddleware, [
  body('appareilId').isInt().withMessage('ID appareil requis'),
  body('dateDebut').isISO8601().toDate().withMessage('Date début invalide'),
  body('dateFin').isISO8601().toDate().withMessage('Date fin invalide'),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { appareilId, dateDebut, dateFin, userId } = req.body;

    // Admin peut créer pour un autre user, client seulement pour lui-même
    const targetUserId = req.user.role === 'admin' && userId ? userId : req.user.userId;

    // Récupérer les infos de l'appareil
    const appareilResult = await pool.query(
      'SELECT * FROM appareils WHERE id = $1',
      [appareilId]
    );

    if (appareilResult.rows.length === 0) {
      return res.status(404).json({ error: 'Appareil ID invalide' });
    }

    const appareil = appareilResult.rows[0];
    if (!appareil.disponible) {
      console.warn(`⚠️ Location créée pour appareil INDISPONIBLE: ${appareilId} - ${appareil.nom}`);
    }
    
    // Calculer le nombre de jours
    const debut = new Date(dateDebut);
    const fin = new Date(dateFin);
    const jours = Math.ceil((fin - debut) / (1000 * 60 * 60 * 24)) + 1;
    const montantTotal = appareil.prix_location * jours;
    const code = `LOC-${Date.now()}`;

    const result = await pool.query(
      `INSERT INTO locations (code, user_id, appareil_id, appareil_nom, date_debut, date_fin, prix_journalier, montant_total, statut)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'en_attente')
       RETURNING *`,
      [code, targetUserId, appareilId, appareil.nom, dateDebut, dateFin, appareil.prix_location, montantTotal]
    );

    // NE PAS marquer l'appareil comme indisponible automatiquement
    // L'appareil ne sera marqué indisponible que quand l'admin approuve

    const location = result.rows[0];

    res.status(201).json({
      message: 'Location créée en attente de validation',
      location: {
        id: location.id,
        code: location.code,
        appareilNom: location.appareil_nom,
        dateDebut: location.date_debut,
        dateFin: location.date_fin,
        montantTotal: location.montant_total,
        statut: location.statut
      }
    });
  } catch (error) {
    console.error('Erreur création location:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Terminer une location (admin)
router.patch('/:id/terminer', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { id } = req.params;

    const result = await pool.query(
      `UPDATE locations
       SET statut = 'termine', updated_at = CURRENT_TIMESTAMP
       WHERE id = $1
       RETURNING appareil_id`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Location non trouvée' });
    }

    // Rendre l'appareil disponible
    const appareilId = result.rows[0].appareil_id;
    if (appareilId) {
      await pool.query('UPDATE appareils SET disponible = true WHERE id = $1', [appareilId]);
    }

    res.json({ message: 'Location terminée' });
  } catch (error) {
    console.error('Erreur terminer location:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Approuver une location (admin)
router.patch('/:id/approuver', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { id } = req.params;

    const result = await pool.query(
      `UPDATE locations
       SET statut = 'en_cours', updated_at = CURRENT_TIMESTAMP
       WHERE id = $1
       RETURNING *`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Location non trouvée' });
    }

    const location = result.rows[0];

    // Marquer l'appareil comme indisponible
    if (location.appareil_id) {
      await pool.query('UPDATE appareils SET disponible = false WHERE id = $1', [location.appareil_id]);
    }

    res.json({ message: 'Location approuvée', location });
  } catch (error) {
    console.error('Erreur approuver location:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Rejeter une location (admin)
router.patch('/:id/rejeter', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const { raison } = req.body;

    const result = await pool.query(
      `UPDATE locations
       SET statut = 'rejetee', commentaire_admin = $1, updated_at = CURRENT_TIMESTAMP
       WHERE id = $2
       RETURNING *`,
      [raison || 'Demande rejetée', id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Location non trouvée' });
    }

    res.json({ message: 'Location rejetée', location: result.rows[0] });
  } catch (error) {
    console.error('Erreur rejeter location:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

module.exports = router;