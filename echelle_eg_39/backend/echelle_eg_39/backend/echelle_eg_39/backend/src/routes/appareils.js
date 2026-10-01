const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const pool = require('../config/database');
const { authMiddleware, adminMiddleware } = require('../middleware/auth');

function mapAppareil(appareil) {
  return {
    id: appareil.id,
    code: appareil.code,
    nom: appareil.nom,
    type: appareil.type,
    imageUrl: appareil.image_url,
    prixLocation: appareil.prix_location,
    prixVente: appareil.prix_vente,
    disponible: appareil.disponible,
    horsService: appareil.hors_service ?? !appareil.disponible,
    createdAt: appareil.created_at,
  };
}

// Le booléen `disponible` décrit l’état opérationnel manuel de l’appareil.
// Le planning des locations est consulté séparément avec les dates demandées.
router.get('/', async (req, res) => {
  try {
    const { type, disponible } = req.query;
    if (disponible !== undefined && !['true', 'false'].includes(disponible)) {
      return res.status(400).json({ error: 'Filtre de disponibilité invalide.' });
    }

    let query = 'SELECT * FROM appareils';
    const conditions = [];
    const params = [];
    if (type) {
      params.push(type);
      conditions.push(`type = $${params.length}`);
    }
    if (disponible !== undefined) {
      params.push(disponible === 'true');
      conditions.push(`disponible = $${params.length}`);
    }
    if (conditions.length > 0) query += ` WHERE ${conditions.join(' AND ')}`;
    query += ' ORDER BY created_at DESC';

    const result = await pool.query(query, params);
    return res.json({ appareils: result.rows.map(mapAppareil) });
  } catch (error) {
    console.error('Erreur liste appareils:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

router.post(
  '/',
  authMiddleware,
  adminMiddleware,
  [
    body('nom').trim().notEmpty().withMessage('Nom requis'),
    body('type').trim().notEmpty().withMessage('Type requis'),
    body('prixLocation').isInt({ min: 0 }).withMessage('Prix location invalide'),
    body('prixVente').isInt({ min: 0 }).withMessage('Prix vente invalide'),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    try {
      const { nom, type, imageUrl, prixLocation, prixVente } = req.body;
      const code = `APP-${Date.now()}`;
      const result = await pool.query(
        `INSERT INTO appareils
           (code, nom, type, image_url, prix_location, prix_vente)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING *`,
        [code, nom, type, imageUrl || null, prixLocation, prixVente],
      );
      return res.status(201).json({
        message: 'Appareil ajouté',
        appareil: mapAppareil(result.rows[0]),
      });
    } catch (error) {
      console.error('Erreur ajout appareil:', error);
      return res.status(500).json({ error: 'Erreur serveur' });
    }
  },
);

router.put('/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { nom, type, imageUrl, prixLocation, prixVente, disponible } = req.body;
    if (disponible != null && typeof disponible !== 'boolean') {
      return res.status(400).json({ error: 'Le champ disponible doit être booléen.' });
    }
    if (disponible === true) {
      const activeRental = await pool.query(
        `SELECT id FROM locations
          WHERE appareil_id = $1
            AND statut IN ('approuvee', 'en_cours', 'en_retard')
          LIMIT 1`,
        [req.params.id],
      );
      if (activeRental.rows.length > 0) {
        return res.status(409).json({
          error: 'Le retour physique doit être confirmé avant de remettre cet appareil en vente.',
        });
      }
    }

    const result = await pool.query(
      `UPDATE appareils
          SET nom = COALESCE($1, nom),
              type = COALESCE($2, type),
              image_url = COALESCE($3, image_url),
              prix_location = COALESCE($4, prix_location),
              prix_vente = COALESCE($5, prix_vente),
              disponible = COALESCE($6, disponible),
              hors_service = CASE
                WHEN $6::boolean IS NULL THEN hors_service
                ELSE NOT $6::boolean
              END,
              updated_at = CURRENT_TIMESTAMP
        WHERE id = $7
        RETURNING *`,
      [nom, type, imageUrl, prixLocation, prixVente, disponible ?? null, req.params.id],
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Appareil introuvable.' });
    return res.json({ message: 'Appareil modifié.', appareil: mapAppareil(result.rows[0]) });
  } catch (error) {
    console.error('Erreur modification appareil:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

router.delete('/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      'DELETE FROM appareils WHERE id = $1 RETURNING id',
      [req.params.id],
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Appareil introuvable.' });
    return res.json({ message: 'Appareil supprimé' });
  } catch (error) {
    console.error('Erreur suppression appareil:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

module.exports = router;
