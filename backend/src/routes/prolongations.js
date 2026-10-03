const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const pool = require('../config/database');
const { authMiddleware, adminMiddleware } = require('../middleware/auth');
const {
  businessToday,
  findBlockingLocation,
  inclusiveRentalDays,
  isDateOnly,
  toDateOnly,
} = require('../utils/rental_dates');

router.get('/', authMiddleware, async (req, res) => {
  try {
    let query = `
      SELECT p.*, l.appareil_nom, l.user_id, u.first_name, u.last_name
        FROM prolongations p
        JOIN locations l ON p.location_id = l.id
        JOIN users u ON l.user_id = u.id
    `;
    const params = [];
    if (req.user.role === 'client') {
      query += ' WHERE l.user_id = $1';
      params.push(req.user.userId);
    }
    query += ' ORDER BY p.created_at DESC';
    const result = await pool.query(query, params);
    return res.json({
      prolongations: result.rows.map((item) => ({
        id: item.id,
        code: item.code,
        locationId: item.location_id,
        appareilNom: item.appareil_nom,
        clientNom: `${item.first_name} ${item.last_name}`,
        ancienneDateFin: item.ancienne_date_fin,
        nouvelleDateFin: item.nouvelle_date_fin,
        joursSupplementaires: item.jours_supplementaires,
        coutSupplementaire: item.cout_supplementaire,
        factureNumero: item.facture_numero,
        estPaye: item.est_paye,
        datePaiement: item.date_paiement,
        createdAt: item.created_at,
      })),
    });
  } catch (error) {
    console.error('Erreur liste prolongations:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

router.post(
  '/',
  authMiddleware,
  [
    body('locationId').isInt({ min: 1 }).withMessage('ID location requis'),
    body('nouvelleDateFin').custom(isDateOnly).withMessage('Date fin invalide (AAAA-MM-JJ)'),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    const client = await pool.connect();
    let transactionOpen = false;
    try {
      await client.query('BEGIN');
      transactionOpen = true;
      const locationResult = await client.query(
        `SELECT * FROM locations
          WHERE id = $1 AND user_id = $2
          FOR UPDATE`,
        [req.body.locationId, req.user.userId],
      );
      if (locationResult.rows.length === 0) {
        await client.query('ROLLBACK');
        transactionOpen = false;
        return res.status(404).json({ error: 'Location introuvable.' });
      }
      const location = locationResult.rows[0];
      if (!['en_cours', 'en_retard'].includes(location.statut)) {
        await client.query('ROLLBACK');
        transactionOpen = false;
        return res.status(409).json({ error: 'Seule une location en cours peut être prolongée.' });
      }

      const deviceResult = await client.query(
        'SELECT id FROM appareils WHERE id = $1 FOR UPDATE',
        [location.appareil_id],
      );
      if (deviceResult.rows.length === 0) {
        await client.query('ROLLBACK');
        transactionOpen = false;
        return res.status(409).json({ error: 'L’appareil lié à cette location est introuvable.' });
      }

      const oldEnd = toDateOnly(location.date_fin);
      const rentalStart = toDateOnly(location.date_debut);
      const newEnd = req.body.nouvelleDateFin;
      if (!oldEnd || !rentalStart) {
        await client.query('ROLLBACK');
        transactionOpen = false;
        return res.status(409).json({ error: 'Les dates de cette location sont invalides.' });
      }
      const extraDays = inclusiveRentalDays(oldEnd, newEnd) - 1;
      if (extraDays <= 0 || extraDays > 30) {
        await client.query('ROLLBACK');
        transactionOpen = false;
        return res.status(400).json({ error: 'Prolongation invalide (maximum 30 jours).' });
      }

      const conflict = await findBlockingLocation(client, {
        appareilId: location.appareil_id,
        dateDebut: rentalStart,
        dateFin: newEnd,
        today: businessToday(),
        excludeLocationId: location.id,
      });
      if (conflict) {
        await client.query('ROLLBACK');
        transactionOpen = false;
        return res.status(409).json({
          code: 'PERIODE_INDISPONIBLE',
          error: 'La prolongation chevauche une autre réservation de cet appareil.',
        });
      }

      const countResult = await client.query(
        'SELECT COUNT(*) AS count FROM prolongations WHERE location_id = $1',
        [location.id],
      );
      const extensionCount = Number.parseInt(countResult.rows[0].count, 10);
      if (extensionCount >= 3) {
        await client.query('ROLLBACK');
        transactionOpen = false;
        return res.status(400).json({ error: 'Maximum 3 prolongations atteintes.' });
      }

      const extraCost = Number(location.prix_journalier) * extraDays;
      const newTotal = Number(location.montant_total) + extraCost;
      const extensionCode = `EXT-${Date.now()}`;
      const invoiceNumber = `INV-EXT-${location.id}-${extensionCount + 1}`;
      const inserted = await client.query(
        `INSERT INTO prolongations
           (code, location_id, ancienne_date_fin, nouvelle_date_fin,
            jours_supplementaires, cout_supplementaire, facture_numero)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         RETURNING *`,
        [extensionCode, location.id, oldEnd, newEnd, extraDays, extraCost, invoiceNumber],
      );
      const nextStatus = newEnd < businessToday() ? 'en_retard' : 'en_cours';
      await client.query(
        `UPDATE locations
            SET date_fin = $1,
                montant_total = $2,
                statut = $3,
                updated_at = CURRENT_TIMESTAMP
          WHERE id = $4`,
        [newEnd, newTotal, nextStatus, location.id],
      );
      await client.query('COMMIT');
      transactionOpen = false;
      return res.status(201).json({
        message: 'Prolongation créée.',
        prolongation: {
          id: inserted.rows[0].id,
          code: inserted.rows[0].code,
          joursSupplementaires: inserted.rows[0].jours_supplementaires,
          coutSupplementaire: inserted.rows[0].cout_supplementaire,
          nouvelleDateFin: inserted.rows[0].nouvelle_date_fin,
          factureNumero: inserted.rows[0].facture_numero,
        },
      });
    } catch (error) {
      if (transactionOpen) {
        try {
          await client.query('ROLLBACK');
        } catch (rollbackError) {
          console.error('Erreur rollback prolongation:', rollbackError);
        }
      }
      console.error('Erreur création prolongation:', error);
      return res.status(500).json({ error: 'Erreur serveur' });
    } finally {
      client.release();
    }
  },
);

router.patch('/:id/payer', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      `UPDATE prolongations
          SET est_paye = true,
              date_paiement = CURRENT_TIMESTAMP,
              updated_at = CURRENT_TIMESTAMP
        WHERE id = $1
        RETURNING *`,
      [req.params.id],
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Prolongation introuvable.' });
    return res.json({ message: 'Prolongation marquée comme payée.' });
  } catch (error) {
    console.error('Erreur paiement prolongation:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

module.exports = router;
