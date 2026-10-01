const express = require('express');
const { randomUUID } = require('node:crypto');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const pool = require('../config/database');
const { authMiddleware, adminMiddleware } = require('../middleware/auth');
const {
  businessToday,
  findBlockingLocation,
  inclusiveRentalDays,
  isDateOnly,
} = require('../utils/rental_dates');
const {
  sendLocationApprovedEmail,
  sendLocationRejectedEmail,
} = require('../services/email_sms_service');

function mapLocation(location) {
  return {
    id: location.id,
    code: location.code,
    clientNom: [location.first_name, location.last_name].filter(Boolean).join(' '),
    clientEmail: location.email,
    clientPhone: location.phone,
    clientTelephone: location.phone,
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

function validateDateRange(dateDebut, dateFin) {
  if (!isDateOnly(dateDebut) || !isDateOnly(dateFin)) {
    return { error: 'Les dates doivent être au format AAAA-MM-JJ.' };
  }
  if (dateDebut < businessToday()) {
    return { error: 'La date de début doit être aujourd’hui ou ultérieure.' };
  }
  if (dateFin < dateDebut) {
    return { error: 'La date de retour doit être égale ou postérieure au début.' };
  }
  return null;
}

async function listLocations(req, res, { adminOnly = false } = {}) {
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

    if (!adminOnly && req.user.role !== 'admin') {
      query += ' WHERE l.user_id = $1';
      params.push(req.user.userId);
    }

    if (statut) {
      query += params.length > 0 ? ' AND' : ' WHERE';
      params.push(statut);
      query += ` l.statut = $${params.length}`;
    }

    query += ' ORDER BY l.created_at DESC';
    const result = await pool.query(query, params);
    res.set('Cache-Control', 'no-store');
    return res.json({ locations: result.rows.map(mapLocation) });
  } catch (error) {
    console.error('Erreur liste locations:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
}

router.get('/admin', authMiddleware, adminMiddleware, (req, res) =>
  listLocations(req, res, { adminOnly: true }),
);
router.get('/', authMiddleware, (req, res) => listLocations(req, res));

// Aperçu de disponibilité par plage. La création revalide toujours sous verrou.
router.get('/disponibilite', async (req, res) => {
  res.set('Cache-Control', 'no-store');
  const appareilId = Number(req.query.appareilId);
  const { dateDebut, dateFin } = req.query;
  const rangeError = validateDateRange(dateDebut, dateFin);
  if (!Number.isSafeInteger(appareilId) || appareilId <= 0 || rangeError) {
    return res.status(400).json({
      disponible: false,
      raison: rangeError?.error ?? 'Identifiant appareil invalide.',
    });
  }

  try {
    const appareilResult = await pool.query(
      'SELECT id, hors_service FROM appareils WHERE id = $1',
      [appareilId],
    );
    if (appareilResult.rows.length === 0) {
      return res.status(404).json({ disponible: false, raison: 'Appareil introuvable.' });
    }
    if (appareilResult.rows[0].hors_service) {
      return res.json({ disponible: false, raison: 'hors_service' });
    }

    const conflit = await findBlockingLocation(pool, {
      appareilId,
      dateDebut,
      dateFin,
      today: businessToday(),
    });
    if (conflit) {
      return res.json({
        disponible: false,
        raison: 'chevauchement',
        dateDebutConflit: conflit.date_debut,
        dateFinConflit: conflit.date_fin,
      });
    }
    return res.json({ disponible: true, raison: null });
  } catch (error) {
    console.error('Erreur vérification disponibilité location:', error);
    return res.status(500).json({ error: 'Impossible de vérifier la disponibilité.' });
  }
});

router.post(
  '/',
  authMiddleware,
  [
    body('appareilId').isInt({ min: 1 }).withMessage('ID appareil requis'),
    body('dateDebut').custom(isDateOnly).withMessage('Date début invalide (AAAA-MM-JJ)'),
    body('dateFin').custom(isDateOnly).withMessage('Date fin invalide (AAAA-MM-JJ)'),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { dateDebut, dateFin, userId } = req.body;
    const appareilId = Number(req.body.appareilId);
    const targetUserId = req.user.role === 'admin' && userId != null
      ? Number(userId)
      : Number(req.user.userId);
    const rangeError = validateDateRange(dateDebut, dateFin);
    if (rangeError) return res.status(400).json(rangeError);
    if (!Number.isSafeInteger(targetUserId) || targetUserId <= 0) {
      return res.status(400).json({ error: 'Identifiant client invalide.' });
    }

    const days = inclusiveRentalDays(dateDebut, dateFin);
    const client = await pool.connect();
    let transactionOpen = false;
    try {
      await client.query('BEGIN');
      transactionOpen = true;

      const appareilResult = await client.query(
        `SELECT id, nom, prix_location, hors_service
           FROM appareils
          WHERE id = $1
          FOR UPDATE`,
        [appareilId],
      );
      if (appareilResult.rows.length === 0) {
        await client.query('ROLLBACK');
        transactionOpen = false;
        return res.status(404).json({ error: 'Appareil introuvable.' });
      }

      const appareil = appareilResult.rows[0];
      if (appareil.hors_service) {
        await client.query('ROLLBACK');
        transactionOpen = false;
        return res.status(409).json({
          code: 'APPAREIL_HORS_SERVICE',
          error: 'Cet appareil est temporairement hors service.',
        });
      }

      const conflit = await findBlockingLocation(client, {
        appareilId,
        dateDebut,
        dateFin,
        today: businessToday(),
      });
      if (conflit) {
        await client.query('ROLLBACK');
        transactionOpen = false;
        return res.status(409).json({
          code: 'PERIODE_INDISPONIBLE',
          error: 'Cette période chevauche une autre réservation de cet appareil.',
          dateDebutConflit: conflit.date_debut,
          dateFinConflit: conflit.date_fin,
        });
      }

      const prixJournalier = Number(appareil.prix_location);
      const montantTotal = prixJournalier * days;
      if (!Number.isSafeInteger(montantTotal) || montantTotal <= 0) {
        await client.query('ROLLBACK');
        transactionOpen = false;
        return res.status(400).json({ error: 'Le montant total calculé est invalide.' });
      }

      const code = `LOC-${Date.now()}-${randomUUID().slice(0, 8)}`;
      const inserted = await client.query(
        `INSERT INTO locations
           (code, user_id, appareil_id, appareil_nom, date_debut, date_fin,
            prix_journalier, montant_total, statut)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'en_attente')
         RETURNING id, code, appareil_nom, date_debut, date_fin, montant_total, statut`,
        [
          code,
          targetUserId,
          appareil.id,
          appareil.nom,
          dateDebut,
          dateFin,
          prixJournalier,
          montantTotal,
        ],
      );
      await client.query('COMMIT');
      transactionOpen = false;

      return res.status(201).json({
        message: 'Demande de location créée - en attente de validation admin.',
        location: {
          id: inserted.rows[0].id,
          code: inserted.rows[0].code,
          appareilNom: inserted.rows[0].appareil_nom,
          dateDebut: inserted.rows[0].date_debut,
          dateFin: inserted.rows[0].date_fin,
          montantTotal: inserted.rows[0].montant_total,
          statut: inserted.rows[0].statut,
        },
      });
    } catch (error) {
      if (transactionOpen) {
        try {
          await client.query('ROLLBACK');
        } catch (rollbackError) {
          console.error('Erreur rollback création location:', rollbackError);
        }
      }
      console.error('Erreur création location:', error);
      return res.status(500).json({ error: 'Erreur serveur.' });
    } finally {
      client.release();
    }
  },
);

// Conserver ce correctif historique, protégé admin, pour les bases anciennes.
router.get('/fix-constraint', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    await pool.query('ALTER TABLE locations DROP CONSTRAINT IF EXISTS locations_statut_check');
    await pool.query(`
      ALTER TABLE locations ADD CONSTRAINT locations_statut_check
      CHECK (statut IN ('en_attente', 'approuvee', 'rejetee', 'en_cours', 'termine', 'en_retard', 'annulee'))
    `);
    return res.json({ message: 'Contrainte des statuts vérifiée.' });
  } catch (error) {
    console.error('Erreur mise à jour contrainte des locations:', error);
    return res.status(500).json({ error: 'Impossible de vérifier la contrainte.' });
  }
});

// Marquer une location en retard n’affecte jamais l’occupation physique.
router.patch('/:id/retard', authMiddleware, adminMiddleware, async (req, res) => {
  const today = businessToday();
  try {
    const result = await pool.query(
      `UPDATE locations
          SET statut = 'en_retard', updated_at = CURRENT_TIMESTAMP
        WHERE id = $1
          AND statut = 'en_cours'
          AND date_fin < $2::date
        RETURNING id, statut, date_fin`,
      [req.params.id, today],
    );
    if (result.rows.length === 0) {
      const existing = await pool.query(
        'SELECT id, statut, date_fin FROM locations WHERE id = $1',
        [req.params.id],
      );
      if (existing.rows.length === 0) {
        return res.status(404).json({ error: 'Location introuvable.' });
      }
      return res.status(409).json({
        error: 'Seule une location en cours après sa date de retour peut être marquée en retard.',
      });
    }
    return res.json({ message: 'Location marquée en retard.', location: result.rows[0] });
  } catch (error) {
    console.error('Erreur marquage retard:', error);
    return res.status(500).json({ error: 'Impossible de marquer cette location en retard.' });
  }
});

// L’admin confirme le retour physique ; la période est libérée par le statut terminé.
router.patch('/:id/terminer', authMiddleware, adminMiddleware, async (req, res) => {
  const client = await pool.connect();
  let transactionOpen = false;
  try {
    await client.query('BEGIN');
    transactionOpen = true;
    const result = await client.query(
      `UPDATE locations
          SET statut = 'termine', updated_at = CURRENT_TIMESTAMP
        WHERE id = $1
          AND statut IN ('en_cours', 'en_retard')
        RETURNING id, appareil_id, statut`,
      [req.params.id],
    );
    if (result.rows.length === 0) {
      const existing = await client.query(
        'SELECT id FROM locations WHERE id = $1',
        [req.params.id],
      );
      await client.query('ROLLBACK');
      transactionOpen = false;
      if (existing.rows.length === 0) {
        return res.status(404).json({ error: 'Location introuvable.' });
      }
      return res.status(409).json({
        error: 'Cette location ne peut pas être terminée dans son état actuel.',
      });
    }

    if (result.rows[0].appareil_id != null) {
      await client.query(
        `UPDATE appareils
            SET disponible = NOT hors_service,
                updated_at = CURRENT_TIMESTAMP
          WHERE id = $1`,
        [result.rows[0].appareil_id],
      );
    }
    await client.query('COMMIT');
    transactionOpen = false;
    return res.json({ message: 'Retour physique confirmé, location terminée.' });
  } catch (error) {
    if (transactionOpen) {
      try {
        await client.query('ROLLBACK');
      } catch (rollbackError) {
        console.error('Erreur rollback retour location:', rollbackError);
      }
    }
    console.error('Erreur confirmation retour:', error);
    return res.status(500).json({ error: 'Impossible de confirmer le retour.' });
  } finally {
    client.release();
  }
});

router.patch('/:id/approuver', authMiddleware, adminMiddleware, async (req, res) => {
  const client = await pool.connect();
  let transactionOpen = false;
  let approvedLocation;
  try {
    await client.query('BEGIN');
    transactionOpen = true;
    const locationResult = await client.query(
      `SELECT l.*, u.first_name, u.last_name, u.email
         FROM locations l
         JOIN users u ON u.id = l.user_id
        WHERE l.id = $1
        FOR UPDATE OF l`,
      [req.params.id],
    );
    if (locationResult.rows.length === 0) {
      await client.query('ROLLBACK');
      transactionOpen = false;
      return res.status(404).json({ error: 'Location introuvable.' });
    }
    const location = locationResult.rows[0];
    if (location.statut !== 'en_attente' && location.statut !== 'approuvee') {
      await client.query('ROLLBACK');
      transactionOpen = false;
      return res.status(409).json({ error: 'Cette location ne peut plus être approuvée.' });
    }
    if (!location.appareil_id) {
      await client.query('ROLLBACK');
      transactionOpen = false;
      return res.status(409).json({ error: 'L’appareil associé à cette location n’existe plus.' });
    }
    if (String(location.date_fin).slice(0, 10) < businessToday()) {
      await client.query('ROLLBACK');
      transactionOpen = false;
      return res.status(409).json({
        error: 'La période demandée est échue. Rejetez cette demande et demandez au client de choisir de nouvelles dates.',
      });
    }

    const appareilResult = await client.query(
      'SELECT id, hors_service FROM appareils WHERE id = $1 FOR UPDATE',
      [location.appareil_id],
    );
    if (appareilResult.rows.length === 0 || appareilResult.rows[0].hors_service) {
      await client.query('ROLLBACK');
      transactionOpen = false;
      return res.status(409).json({ error: 'Appareil actuellement hors service.' });
    }
    const conflit = await findBlockingLocation(client, {
      appareilId: location.appareil_id,
      dateDebut: String(location.date_debut).slice(0, 10),
      dateFin: String(location.date_fin).slice(0, 10),
      today: businessToday(),
      excludeLocationId: location.id,
    });
    if (conflit) {
      await client.query('ROLLBACK');
      transactionOpen = false;
      return res.status(409).json({
        code: 'PERIODE_INDISPONIBLE',
        error: 'Une autre location bloque cette période. Actualisez la file.',
      });
    }

    const updated = await client.query(
      `UPDATE locations
          SET statut = 'en_cours', updated_at = CURRENT_TIMESTAMP
        WHERE id = $1 AND statut IN ('en_attente', 'approuvee')
        RETURNING *`,
      [req.params.id],
    );
    if (updated.rows.length === 0) {
      await client.query('ROLLBACK');
      transactionOpen = false;
      return res.status(409).json({ error: 'La location a changé. Actualisez la file.' });
    }
    approvedLocation = { ...location, ...updated.rows[0] };
    await client.query(
      'UPDATE appareils SET disponible = false, updated_at = CURRENT_TIMESTAMP WHERE id = $1',
      [location.appareil_id],
    );
    await client.query('COMMIT');
    transactionOpen = false;

    sendLocationApprovedEmail(
      location.email,
      `${location.first_name} ${location.last_name}`,
      approvedLocation.code,
      approvedLocation.appareil_nom,
      approvedLocation.date_debut,
      approvedLocation.date_fin,
      approvedLocation.montant_total,
    ).catch((error) => console.error('Erreur envoi email approbation:', error));

    return res.json({ message: 'Location approuvée.', location: approvedLocation });
  } catch (error) {
    if (transactionOpen) {
      try {
        await client.query('ROLLBACK');
      } catch (rollbackError) {
        console.error('Erreur rollback approbation:', rollbackError);
      }
    }
    console.error('Erreur approbation location:', error);
    return res.status(500).json({ error: 'Erreur serveur.' });
  } finally {
    client.release();
  }
});

router.patch('/:id/rejeter', authMiddleware, adminMiddleware, async (req, res) => {
  const reason = String(req.body.raison || 'Demande rejetée').trim();
  try {
    const result = await pool.query(
      `UPDATE locations AS l
          SET statut = 'rejetee', commentaire_admin = $1, updated_at = CURRENT_TIMESTAMP
         FROM users AS u
        WHERE l.id = $2
          AND l.user_id = u.id
          AND l.statut = 'en_attente'
        RETURNING l.*, u.first_name, u.last_name, u.email`,
      [reason || 'Demande rejetée', req.params.id],
    );
    if (result.rows.length === 0) {
      const existing = await pool.query('SELECT id FROM locations WHERE id = $1', [req.params.id]);
      if (existing.rows.length === 0) return res.status(404).json({ error: 'Location introuvable.' });
      return res.status(409).json({ error: 'Seule une demande en attente peut être rejetée.' });
    }
    const location = result.rows[0];
    sendLocationRejectedEmail(
      location.email,
      `${location.first_name} ${location.last_name}`,
      location.code,
      location.appareil_nom,
      reason || 'Demande rejetée',
    ).catch((error) => console.error('Erreur envoi email rejet:', error));
    return res.json({ message: 'Location rejetée.', location });
  } catch (error) {
    console.error('Erreur rejet location:', error);
    return res.status(500).json({ error: 'Erreur serveur.' });
  }
});

router.delete('/:id', authMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      `DELETE FROM locations
        WHERE id = $1
          AND statut IN ('termine', 'rejetee', 'annulee')
          AND ($2::text = 'admin' OR user_id = $3)
        RETURNING id`,
      [req.params.id, req.user.role, req.user.userId],
    );
    if (result.rows.length === 0) {
      const existing = await pool.query('SELECT id FROM locations WHERE id = $1', [req.params.id]);
      if (existing.rows.length === 0) return res.status(404).json({ error: 'Location introuvable.' });
      return res.status(403).json({ error: 'Seules vos locations terminées ou rejetées peuvent être supprimées.' });
    }
    return res.json({ message: 'Location supprimée.' });
  } catch (error) {
    console.error('Erreur suppression location:', error);
    return res.status(500).json({ error: 'Erreur serveur.' });
  }
});

module.exports = router;
