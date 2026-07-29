const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const pool = require('../config/database');
const { authMiddleware, adminMiddleware } = require('../middleware/auth');

// Liste des appareils (accessible à tous)
router.get('/', async (req, res) => {
  try {
    const { type, disponible } = req.query;
    
    let query = 'SELECT * FROM appareils';
    const params = [];
    const conditions = [];

    if (type) {
      params.push(type);
      conditions.push(`type = $${params.length}`);
    }

    if (disponible !== undefined) {
      params.push(disponible === 'true');
      conditions.push(`disponible = $${params.length}`);
    }

    if (conditions.length > 0) {
      query += ' WHERE ' + conditions.join(' AND ');
    }

    query += ' ORDER BY created_at DESC';

    const result = await pool.query(query, params);

    res.json({
      appareils: result.rows.map(a => ({
        id: a.id,
        code: a.code,
        nom: a.nom,
        type: a.type,
        imageUrl: a.image_url,
        prixLocation: a.prix_location,
        prixVente: a.prix_vente,
        disponible: a.disponible,
        createdAt: a.created_at
      }))
    });
  } catch (error) {
    console.error('Erreur liste appareils:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Ajouter un appareil (admin seulement)
router.post('/', authMiddleware, adminMiddleware, [
  body('nom').trim().notEmpty().withMessage('Nom requis'),
  body('type').trim().notEmpty().withMessage('Type requis'),
  body('prixLocation').isInt({ min: 0 }).withMessage('Prix location invalide'),
  body('prixVente').isInt({ min: 0 }).withMessage('Prix vente invalide'),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { nom, type, imageUrl, prixLocation, prixVente } = req.body;
    const code = `APP-${Date.now()}`;

    const result = await pool.query(
      `INSERT INTO appareils (code, nom, type, image_url, prix_location, prix_vente)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [code, nom, type, imageUrl || null, prixLocation, prixVente]
    );

    const appareil = result.rows[0];

    res.status(201).json({
      message: 'Appareil ajouté',
      appareil: {
        id: appareil.id,
        code: appareil.code,
        nom: appareil.nom,
        type: appareil.type,
        imageUrl: appareil.image_url,
        prixLocation: appareil.prix_location,
        prixVente: appareil.prix_vente,
        disponible: appareil.disponible
      }
    });
  } catch (error) {
    console.error('Erreur ajout appareil:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Modifier un appareil (admin seulement)
router.put('/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const { nom, type, imageUrl, prixLocation, prixVente, disponible } = req.body;

    const result = await pool.query(
      `UPDATE appareils 
       SET nom = COALESCE($1, nom),
           type = COALESCE($2, type),
           image_url = COALESCE($3, image_url),
           prix_location = COALESCE($4, prix_location),
           prix_vente = COALESCE($5, prix_vente),
           disponible = COALESCE($6, disponible),
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $7
       RETURNING *`,
      [nom, type, imageUrl, prixLocation, prixVente, disponible, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Appareil non trouvé' });
    }

    const appareil = result.rows[0];

    res.json({
      message: 'Appareil modifié',
      appareil: {
        id: appareil.id,
        code: appareil.code,
        nom: appareil.nom,
        type: appareil.type,
        imageUrl: appareil.image_url,
        prixLocation: appareil.prix_location,
        prixVente: appareil.prix_vente,
        disponible: appareil.disponible
      }
    });
  } catch (error) {
    console.error('Erreur modification appareil:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Supprimer un appareil (admin seulement)
router.delete('/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { id } = req.params;

    const result = await pool.query('DELETE FROM appareils WHERE id = $1 RETURNING *', [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Appareil non trouvé' });
    }

    res.json({ message: 'Appareil supprimé' });
  } catch (error) {
    console.error('Erreur suppression appareil:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

module.exports = router;