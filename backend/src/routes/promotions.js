const express = require('express');
const multer = require('multer');
const router = express.Router();
const pool = require('../config/database');
const { businessToday } = require('../utils/rental_dates');
const { authMiddleware, adminMiddleware } = require('../middleware/auth');
const firebaseStorage = require('../services/firebase_storage');

const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const allowedContentTypes = new Set(['image/jpeg', 'image/png', 'image/webp']);
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_IMAGE_BYTES, files: 1 },
});

function parsePromotionImage(req, res, next) {
  upload.single('image')(req, res, (error) => {
    if (!error) return next();
    if (error instanceof multer.MulterError && error.code === 'LIMIT_FILE_SIZE') {
      return res.status(413).json({ error: 'L’image ne doit pas dépasser 5 Mo.' });
    }
    return res.status(400).json({ error: 'Impossible de lire cette image.' });
  });
}

function signatureMatchesImage(buffer, contentType) {
  if (contentType === 'image/jpeg') {
    return buffer.length >= 3 && buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff;
  }
  if (contentType === 'image/png') {
    return buffer.length >= 8 && buffer.subarray(0, 8).equals(
      Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    );
  }
  if (contentType === 'image/webp') {
    return buffer.length >= 12 &&
      buffer.toString('ascii', 0, 4) === 'RIFF' &&
      buffer.toString('ascii', 8, 12) === 'WEBP';
  }
  return false;
}

function firebaseStorageError(res, error) {
  if (error.code === 'FIREBASE_STORAGE_NOT_CONFIGURED') {
    return res.status(503).json({
      error: 'Firebase Storage doit être configuré sur le serveur.',
      code: error.code,
    });
  }
  return res.status(500).json({ error: 'Erreur du stockage de l’image' });
}

// Récupérer toutes les promotions (admin seulement).
router.get('/', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT * FROM promotions
      ORDER BY created_at DESC
    `);
    return res.json({ promotions: result.rows });
  } catch (error) {
    console.error('Erreur liste promotions:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Récupérer la promotion active (public - pour le popup client).
router.get('/active', async (req, res) => {
  try {
    const now = businessToday();
    const result = await pool.query(`
      SELECT * FROM promotions
      WHERE actif = true
        AND date_debut <= $1
        AND date_fin >= $1
      ORDER BY created_at DESC
      LIMIT 1
    `, [now]);

    if (result.rows.length === 0) {
      return res.json({ promotion: null });
    }

    return res.json({ promotion: result.rows[0] });
  } catch (error) {
    console.error('Erreur promotion active:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Image de campagne : upload réservé à un administrateur authentifié.
router.post(
  '/image',
  authMiddleware,
  adminMiddleware,
  parsePromotionImage,
  async (req, res) => {
    if (!req.file) {
      return res.status(400).json({ error: 'Sélectionnez une image à téléverser.' });
    }

    const { buffer, mimetype } = req.file;
    if (!allowedContentTypes.has(mimetype) || !signatureMatchesImage(buffer, mimetype)) {
      return res.status(415).json({
        error: 'Formats acceptés : JPEG, PNG ou WebP.',
      });
    }

    try {
      const uploaded = await firebaseStorage.uploadPromotionImage(buffer, mimetype);
      return res.status(201).json(uploaded);
    } catch (error) {
      console.error('Erreur téléversement image promotion:', error);
      return firebaseStorageError(res, error);
    }
  },
);

// Annuler le téléversement si l’enregistrement de la campagne échoue.
router.delete('/image', authMiddleware, adminMiddleware, async (req, res) => {
  const storagePath = req.body?.storagePath?.toString();
  if (!storagePath || !storagePath.startsWith('promotions/') || storagePath.includes('..')) {
    return res.status(400).json({ error: 'Chemin de l’image invalide.' });
  }

  try {
    await firebaseStorage.deletePromotionImage(storagePath);
    return res.json({ message: 'Image de promotion supprimée' });
  } catch (error) {
    console.error('Erreur suppression image promotion:', error);
    return firebaseStorageError(res, error);
  }
});

// Créer une promotion (admin seulement).
router.post('/', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const {
      description,
      image_url,
      image_storage_path,
      date_debut,
      date_fin,
      actif,
      frequence,
    } = req.body;

    if (!description?.toString().trim() || !date_debut || !date_fin) {
      return res.status(400).json({
        error: 'Description, date de début et date de fin sont requises.',
      });
    }

    const isValidDate = (value) => {
      if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
        return false;
      }
      const timestamp = Date.parse(`${value}T00:00:00.000Z`);
      return Number.isFinite(timestamp) &&
        new Date(timestamp).toISOString().slice(0, 10) === value;
    };
    if (!isValidDate(date_debut) || !isValidDate(date_fin) || date_fin < date_debut) {
      return res.status(400).json({ error: 'La période de promotion est invalide.' });
    }

    const frequencies = ['chaque_ouverture', 'une_fois_par_jour', 'une_seule_fois'];
    if (frequence != null && !frequencies.includes(frequence)) {
      return res.status(400).json({ error: 'Fréquence de promotion invalide.' });
    }
    if (actif != null && typeof actif !== 'boolean') {
      return res.status(400).json({ error: 'Le statut actif doit être booléen.' });
    }

    const result = await pool.query(`
      INSERT INTO promotions (
        titre, description, image_url, image_storage_path,
        date_debut, date_fin, actif, frequence, created_at, updated_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      RETURNING *
    `, [
      'Offre du moment',
      description.toString().trim(),
      image_url || null,
      image_storage_path || null,
      date_debut,
      date_fin,
      actif ?? true,
      frequence || 'chaque_ouverture',
    ]);

    return res.status(201).json({
      message: 'Promotion créée avec succès',
      promotion: result.rows[0],
    });
  } catch (error) {
    console.error('Erreur création promotion:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Activer/désactiver une promotion (admin seulement).
router.patch('/:id/toggle', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const { actif } = req.body;
    if (typeof actif !== 'boolean') {
      return res.status(400).json({ error: 'Le statut actif doit être booléen.' });
    }

    const result = await pool.query(
      `UPDATE promotions
       SET actif = $1, updated_at = CURRENT_TIMESTAMP
       WHERE id = $2
       RETURNING *`,
      [actif, id],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Promotion non trouvée' });
    }

    return res.json({ message: 'Promotion mise à jour', promotion: result.rows[0] });
  } catch (error) {
    console.error('Erreur toggle promotion:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Supprimer une promotion et nettoyer son fichier si le Storage est disponible.
router.delete('/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      'DELETE FROM promotions WHERE id = $1 RETURNING *',
      [req.params.id],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Promotion non trouvée' });
    }

    const storagePath = result.rows[0].image_storage_path;
    if (storagePath) {
      try {
        await firebaseStorage.deletePromotionImage(storagePath);
      } catch (error) {
        console.error('Image promotion non nettoyée:', error);
      }
    }

    return res.json({ message: 'Promotion supprimée' });
  } catch (error) {
    console.error('Erreur suppression promotion:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

module.exports = router;
