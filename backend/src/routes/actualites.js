const express = require('express');
const multer = require('multer');
const router = express.Router();
const pool = require('../config/database');
const { businessToday } = require('../utils/rental_dates');
const { authMiddleware, adminMiddleware } = require('../middleware/auth');
const cloudinaryStorage = require('../services/cloudinary_storage');

// Limites partagées avec le formulaire Flutter : un titre et une description
// courts garantissent qu'une carte d'actualité reste lisible sur l'accueil.
const MAX_TITRE = 80;
const MAX_DESCRIPTION = 240;
const MAX_CORPS = 8000;
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const STATUTS = ['brouillon', 'publiee'];
const allowedContentTypes = new Set(['image/jpeg', 'image/png', 'image/webp']);

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_IMAGE_BYTES, files: 1 },
});

const COLONNES = `
  id, titre, description, corps, image_url, image_storage_path,
  date_publication, statut, epingle, auteur, created_at, updated_at
`;

function parseActualiteImage(req, res, next) {
  upload.single('image')(req, res, (error) => {
    if (!error) return next();
    if (error instanceof multer.MulterError && error.code === 'LIMIT_FILE_SIZE') {
      return res.status(413).json({ error: 'L’image ne doit pas dépasser 5 Mo.' });
    }
    return res.status(400).json({ error: 'Impossible de lire cette image.' });
  });
}

// Vérifie que le contenu binaire correspond bien au type annoncé : un fichier
// renommé en .jpg ne doit pas atteindre le stockage.
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

function storageError(res, error) {
  if (error.code === 'CLOUDINARY_STORAGE_NOT_CONFIGURED') {
    return res.status(503).json({
      error: 'Cloudinary doit être configuré sur le serveur.',
      code: error.code,
    });
  }
  return res.status(500).json({ error: 'Erreur du stockage de l’image' });
}

function texte(value) {
  return value == null ? '' : value.toString().trim();
}

function isIsoDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const timestamp = Date.parse(`${value}T00:00:00.000Z`);
  return Number.isFinite(timestamp) &&
    new Date(timestamp).toISOString().slice(0, 10) === value;
}

function parseId(value) {
  const id = Number.parseInt(value, 10);
  return Number.isInteger(id) && id > 0 ? id : null;
}

// Valide le corps d'une création ou d'une mise à jour et renvoie soit
// `{ error }` pour une réponse 400, soit la charge normalisée.
function lirePayload(body) {
  const titre = texte(body.titre);
  const description = texte(body.description);
  const corps = texte(body.corps);
  const statut = body.statut == null ? 'brouillon' : texte(body.statut);
  const date = body.date_publication == null
    ? businessToday()
    : texte(body.date_publication);
  const epingle = body.epingle == null ? false : body.epingle;

  if (!titre) return { error: 'Le titre est requis.' };
  if (titre.length > MAX_TITRE) {
    return { error: `Le titre ne doit pas dépasser ${MAX_TITRE} caractères.` };
  }
  if (!description) return { error: 'La description est requise.' };
  if (description.length > MAX_DESCRIPTION) {
    return { error: `La description ne doit pas dépasser ${MAX_DESCRIPTION} caractères.` };
  }
  if (corps.length > MAX_CORPS) {
    return { error: `Le corps de l’actualité ne doit pas dépasser ${MAX_CORPS} caractères.` };
  }
  if (!STATUTS.includes(statut)) {
    return { error: 'Le statut doit être « brouillon » ou « publiee ».' };
  }
  if (typeof epingle !== 'boolean') {
    return { error: 'L’épinglage doit être un booléen.' };
  }
  if (!isIsoDate(date)) {
    return { error: 'La date de publication est invalide.' };
  }

  return {
    titre,
    description,
    corps: corps || null,
    statut,
    date,
    epingle,
  };
}

// Liste publique : uniquement les actualités publiées, l'épinglée en tête.
router.get('/', async (req, res) => {
  try {
    const limiteDemandee = Number.parseInt(req.query.limit, 10);
    const limite = Number.isInteger(limiteDemandee)
      ? Math.min(Math.max(limiteDemandee, 1), 50)
      : 20;
    const offsetDemande = Number.parseInt(req.query.offset, 10);
    const offset = Number.isInteger(offsetDemande) && offsetDemande > 0 ? offsetDemande : 0;

    const result = await pool.query(
      `SELECT ${COLONNES}
       FROM actualites
       WHERE statut = 'publiee'
       ORDER BY epingle DESC, date_publication DESC, id DESC
       LIMIT $1 OFFSET $2`,
      [limite, offset],
    );

    return res.json({ actualites: result.rows });
  } catch (error) {
    console.error('Erreur liste actualités:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Liste complète, brouillons compris : réservée au back-office.
router.get('/admin', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT ${COLONNES}
       FROM actualites
       ORDER BY date_publication DESC, id DESC`,
    );
    return res.json({ actualites: result.rows });
  } catch (error) {
    console.error('Erreur liste actualités admin:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Téléversement de la photo d'une actualité.
router.post(
  '/image',
  authMiddleware,
  adminMiddleware,
  parseActualiteImage,
  async (req, res) => {
    if (!req.file) {
      return res.status(400).json({ error: 'Sélectionnez une image à téléverser.' });
    }

    const { buffer, mimetype } = req.file;
    if (!allowedContentTypes.has(mimetype) || !signatureMatchesImage(buffer, mimetype)) {
      return res.status(415).json({ error: 'Formats acceptés : JPEG, PNG ou WebP.' });
    }

    try {
      const uploaded = await cloudinaryStorage.uploadActualiteImage(buffer, mimetype);
      return res.status(201).json(uploaded);
    } catch (error) {
      console.error('Erreur téléversement image actualité:', error);
      return storageError(res, error);
    }
  },
);

// Annulation d'un téléversement si l'enregistrement échoue ensuite.
router.delete('/image', authMiddleware, adminMiddleware, async (req, res) => {
  const storagePath = req.body?.storagePath?.toString();
  if (!storagePath || !storagePath.startsWith('actualites/') || storagePath.includes('..')) {
    return res.status(400).json({ error: 'Chemin de l’image invalide.' });
  }

  try {
    await cloudinaryStorage.deleteActualiteImage(storagePath);
    return res.json({ message: 'Image d’actualité supprimée' });
  } catch (error) {
    console.error('Erreur suppression image actualité:', error);
    return storageError(res, error);
  }
});

// Créer une actualité.
router.post('/', authMiddleware, adminMiddleware, async (req, res) => {
  const payload = lirePayload(req.body);
  if (payload.error) {
    return res.status(400).json({ error: payload.error });
  }

  try {
    const result = await pool.query(
      `INSERT INTO actualites (
         titre, description, corps, image_url, image_storage_path,
         date_publication, statut, epingle, auteur, created_at, updated_at
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
       RETURNING ${COLONNES}`,
      [
        payload.titre,
        payload.description,
        payload.corps,
        texte(req.body.image_url) || null,
        texte(req.body.image_storage_path) || null,
        payload.date,
        payload.statut,
        payload.epingle,
        texte(req.body.auteur) || null,
      ],
    );

    return res.status(201).json({
      message: 'Actualité créée avec succès',
      actualite: result.rows[0],
    });
  } catch (error) {
    console.error('Erreur création actualité:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Modifier une actualité. Les champs image ne sont remplacés que s'ils sont
// explicitement transmis, pour ne pas effacer une photo déjà en place.
router.put('/:id', authMiddleware, adminMiddleware, async (req, res) => {
  const id = parseId(req.params.id);
  if (!id) return res.status(400).json({ error: 'Identifiant invalide.' });

  const payload = lirePayload(req.body);
  if (payload.error) {
    return res.status(400).json({ error: payload.error });
  }

  try {
    const existante = await pool.query(
      'SELECT image_url, image_storage_path FROM actualites WHERE id = $1',
      [id],
    );
    if (existante.rows.length === 0) {
      return res.status(404).json({ error: 'Actualité non trouvée' });
    }

    const remplaceImage = Object.prototype.hasOwnProperty.call(req.body, 'image_url');
    const imageUrl = remplaceImage
      ? texte(req.body.image_url) || null
      : existante.rows[0].image_url;
    const storagePath = remplaceImage
      ? texte(req.body.image_storage_path) || null
      : existante.rows[0].image_storage_path;

    const result = await pool.query(
      `UPDATE actualites
       SET titre = $1,
           description = $2,
           corps = $3,
           image_url = $4,
           image_storage_path = $5,
           date_publication = $6,
           statut = $7,
           epingle = $8,
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $9
       RETURNING ${COLONNES}`,
      [
        payload.titre,
        payload.description,
        payload.corps,
        imageUrl,
        storagePath,
        payload.date,
        payload.statut,
        payload.epingle,
        id,
      ],
    );

    const ancienneImage = existante.rows[0].image_storage_path;
    if (remplaceImage && ancienneImage && ancienneImage !== storagePath) {
      try {
        await cloudinaryStorage.deleteActualiteImage(ancienneImage);
      } catch (error) {
        console.error('Ancienne image d’actualité non nettoyée:', error);
      }
    }

    return res.json({
      message: 'Actualité mise à jour',
      actualite: result.rows[0],
    });
  } catch (error) {
    console.error('Erreur mise à jour actualité:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Publier ou repasser en brouillon depuis la liste.
router.patch('/:id/statut', authMiddleware, adminMiddleware, async (req, res) => {
  const id = parseId(req.params.id);
  if (!id) return res.status(400).json({ error: 'Identifiant invalide.' });

  const statut = texte(req.body.statut);
  if (!STATUTS.includes(statut)) {
    return res.status(400).json({ error: 'Le statut doit être « brouillon » ou « publiee ».' });
  }

  try {
    const result = await pool.query(
      `UPDATE actualites
       SET statut = $1, updated_at = CURRENT_TIMESTAMP
       WHERE id = $2
       RETURNING ${COLONNES}`,
      [statut, id],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Actualité non trouvée' });
    }

    return res.json({
      message: statut === 'publiee' ? 'Actualité publiée' : 'Actualité repassée en brouillon',
      actualite: result.rows[0],
    });
  } catch (error) {
    console.error('Erreur statut actualité:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Épingler ou désépingler l'actualité affichée en tête de l'accueil.
router.patch('/:id/epingle', authMiddleware, adminMiddleware, async (req, res) => {
  const id = parseId(req.params.id);
  if (!id) return res.status(400).json({ error: 'Identifiant invalide.' });

  if (typeof req.body.epingle !== 'boolean') {
    return res.status(400).json({ error: 'L’épinglage doit être un booléen.' });
  }

  try {
    const result = await pool.query(
      `UPDATE actualites
       SET epingle = $1, updated_at = CURRENT_TIMESTAMP
       WHERE id = $2
       RETURNING ${COLONNES}`,
      [req.body.epingle, id],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Actualité non trouvée' });
    }

    return res.json({
      message: req.body.epingle ? 'Actualité épinglée' : 'Actualité désépinglée',
      actualite: result.rows[0],
    });
  } catch (error) {
    console.error('Erreur épinglage actualité:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Supprimer une actualité et sa photo.
router.delete('/:id', authMiddleware, adminMiddleware, async (req, res) => {
  const id = parseId(req.params.id);
  if (!id) return res.status(400).json({ error: 'Identifiant invalide.' });

  try {
    const result = await pool.query(
      'DELETE FROM actualites WHERE id = $1 RETURNING *',
      [id],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Actualité non trouvée' });
    }

    const storagePath = result.rows[0].image_storage_path;
    if (storagePath) {
      try {
        await cloudinaryStorage.deleteActualiteImage(storagePath);
      } catch (error) {
        console.error('Image d’actualité non nettoyée:', error);
      }
    }

    return res.json({ message: 'Actualité supprimée' });
  } catch (error) {
    console.error('Erreur suppression actualité:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

module.exports = router;
