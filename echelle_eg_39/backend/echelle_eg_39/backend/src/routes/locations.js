const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const pool = require('../config/database');
const { authMiddleware, adminMiddleware } = require('../middleware/auth');

function mapLocation(location) {
  return {
    id: location.id,
    code: location.code,
    clientNom: `${location.first_name} ${location.last_name}`,
    clientEmail: location.email,
    clientPhone: location.phone,
    appareilId: location.appareil_id,
    appareilNom: location.appareil_nom,
    appareilType: location.appareil_type,
    imageUrl: location.appareil_image_url,
    dateDebut: location.date_debut,
    dateFin: location.date_fin,
    prixJournalier: location.prix_journalier,
    montantTotal: location.montant_total,
    statut: location.statut,
    commentaireAdmin: location.commentaire_admin,
    createdAt: location.created_at,
  };
}

// Liste des locations.
router.get('/', authMiddleware, async (req, res) => {
  try {
    const { statut } = req.query;
    let query = `
      SELECT l.*, u.first_name, u.last_name, u.email, u.phone,
             a.type AS appareil_type, a.image_url AS appareil_image_url
      FROM locations l
      JOIN users u ON l.user_id = u.id
      LEFT JOIN appareils a ON l.appareil_id = a.id
    `;
    const params = [];

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
    return res.json({ locations: result.rows.map(mapLocation) });
  } catch (error) {
    console.error('Erreur liste locations:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Créer une demande de location en attente de validation admin.
router.post('/', authMiddleware, [
  body('appareilId').isInt().withMessage('ID appareil requis'),
  body('dateDebut').isISO8601().withMessage('Date début invalide'),
  body('dateFin').isISO8601().withMessage('Date fin invalide'),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { appareilId, dateDebut, dateFin, userId } = req.body;
    const targetUserId = req.user.role === 'admin' && userId
      ? Number(userId)
      : req.user.userId;
    const dateDebutClean = String(dateDebut).split('T')[0];
    const dateFinClean = String(dateFin).split('T')[0];
    const debut = new Date(`${dateDebutClean}T00:00:00Z`);
    const fin = new Date(`${dateFinClean}T00:00:00Z`);

    if (Number.isNaN(debut.getTime()) || Number.isNaN(fin.getTime()) || fin < debut) {
      return res.status(400).json({ error: 'Période de location invalide' });
    }

    const appareilResult = await pool.query(
      'SELECT * FROM appareils WHERE id = $1',
      [appareilId],
    );
    if (appareilResult.rows.length === 0) {
      return res.status(404).json({ error: 'Appareil non trouvé' });
    }

    const appareil = appareilResult.rows[0];
    if (!appareil.disponible) {
      return res.status(409).json({ error: 'Appareil non disponible' });
    }

    const jours = Math.floor((fin - debut) / (1000 * 60 * 60 * 24)) + 1;
    const montantTotal = appareil.prix_location * jours;
    const code = `LOC-${Date.now()}`;
    const result = await pool.query(
      `INSERT INTO locations
        (code, user_id, appareil_id, appareil_nom, date_debut, date_fin,
         prix_journalier, montant_total, statut)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'en_attente')
       RETURNING *`,
      [
        code,
        targetUserId,
        appareil.id,
        appareil.nom,
        dateDebutClean,
        dateFinClean,
        appareil.prix_location,
        montantTotal,
      ],
    );
    const location = result.rows[0];

    return res.status(201).json({
      message: 'Demande de location créée - en attente de validation admin',
      location: {
        id: location.id,
        code: location.code,
        appareilNom: location.appareil_nom,
        dateDebut: location.date_debut,
        dateFin: location.date_fin,
        montantTotal: location.montant_total,
        statut: location.statut,
      },
    });
  } catch (error) {
    console.error('Erreur création location:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Terminer une location (admin).
router.patch('/:id/terminer', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      `UPDATE locations
       SET statut = 'termine', updated_at = CURRENT_TIMESTAMP
       WHERE id = $1
       RETURNING appareil_id`,
      [req.params.id],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Location non trouvée' });
    }

    if (result.rows[0].appareil_id) {
      await pool.query(
        'UPDATE appareils SET disponible = true WHERE id = $1',
        [result.rows[0].appareil_id],
      );
    }

    return res.json({ message: 'Location terminée' });
  } catch (error) {
    console.error('Erreur terminer location:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Approuver une location (admin).
router.patch('/:id/approuver', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const locationResult = await pool.query(
      'SELECT * FROM locations WHERE id = $1',
      [req.params.id],
    );
    if (locationResult.rows.length === 0) {
      return res.status(404).json({ error: 'Location non trouvée' });
    }

    const location = locationResult.rows[0];
    if (['termine', 'rejetee'].includes(location.statut)) {
      return res.status(400).json({ error: 'Cette location ne peut plus être approuvée' });
    }

    if (location.appareil_id) {
      const appareilResult = await pool.query(
        'SELECT disponible FROM appareils WHERE id = $1',
        [location.appareil_id],
      );
      if (appareilResult.rows.length === 0) {
        return res.status(404).json({ error: 'Appareil non trouvé' });
      }
      if (!appareilResult.rows[0].disponible && location.statut !== 'en_cours') {
        return res.status(409).json({ error: 'Appareil déjà réservé' });
      }
    }

    const result = await pool.query(
      `UPDATE locations
       SET statut = 'en_cours', updated_at = CURRENT_TIMESTAMP
       WHERE id = $1
       RETURNING *`,
      [req.params.id],
    );

    if (location.appareil_id) {
      await pool.query(
        'UPDATE appareils SET disponible = false WHERE id = $1',
        [location.appareil_id],
      );
    }

    return res.json({ message: 'Location approuvée', location: result.rows[0] });
  } catch (error) {
    console.error('Erreur approbation location:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Rejeter une location (admin).
router.patch('/:id/rejeter', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const raison = String(req.body.raison || 'Demande rejetée').trim();
    const locationResult = await pool.query(
      'SELECT id, appareil_id, statut FROM locations WHERE id = $1',
      [req.params.id],
    );
    if (locationResult.rows.length === 0) {
      return res.status(404).json({ error: 'Location non trouvée' });
    }

    const location = locationResult.rows[0];
    if (location.statut === 'termine') {
      return res.status(400).json({ error: 'Une location terminée ne peut pas être rejetée' });
    }

    const result = await pool.query(
      `UPDATE locations
       SET statut = 'rejetee', commentaire_admin = $1, updated_at = CURRENT_TIMESTAMP
       WHERE id = $2
       RETURNING *`,
      [raison || 'Demande rejetée', req.params.id],
    );

    if (location.appareil_id) {
      await pool.query(
        'UPDATE appareils SET disponible = true WHERE id = $1',
        [location.appareil_id],
      );
    }

    return res.json({ message: 'Location rejetée', location: result.rows[0] });
  } catch (error) {
    console.error('Erreur rejet location:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Supprimer une location terminée ou rejetée (propriétaire ou admin).
router.delete('/:id', authMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, user_id, appareil_id, statut FROM locations WHERE id = $1',
      [req.params.id],
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Location non trouvée' });
    }

    const location = result.rows[0];
    const isOwner = Number(location.user_id) === Number(req.user.userId);
    if (req.user.role !== 'admin' && !isOwner) {
      return res.status(403).json({ error: 'Non autorisé' });
    }
    if (!['termine', 'rejetee'].includes(location.statut)) {
      return res.status(400).json({
        error: 'Impossible de supprimer une location en cours ou en attente',
      });
    }

    if (location.appareil_id) {
      await pool.query(
        'UPDATE appareils SET disponible = true WHERE id = $1',
        [location.appareil_id],
      );
    }
    await pool.query('DELETE FROM locations WHERE id = $1', [req.params.id]);
    return res.json({ message: 'Location supprimée' });
  } catch (error) {
    console.error('Erreur suppression location:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

module.exports = router;
