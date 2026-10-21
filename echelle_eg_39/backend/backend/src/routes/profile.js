const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');
const pool = require('../config/database');
const { authMiddleware, adminMiddleware } = require('../middleware/auth');
const { normalizeEmail, normalizePhone, getPhoneCandidates } = require('../utils/identifiers');

const router = express.Router();
const MAX_AVATAR_BYTES = 1024 * 1024;
const MAX_ATTACHMENT_BYTES = 2 * 1024 * 1024;
const MAX_ATTACHMENT_COUNT = 3;
const MAX_PROFILE_TEXT = 5000;
const SUPPORT_STATUSES = ['nouveau', 'en_traitement', 'termine', 'ferme'];
const TRAINING_STATUSES = ['nouveau', 'contacte', 'inscrit', 'termine', 'annule'];
const TRAINING_NAMES = new Set([
  'Initiation GPS',
  'Perfectionnement Théodolite',
  'Stations totales',
  'Calcul topographique',
]);

function accountTokenRequired(req, res, next) {
  if (req.user?.type) {
    return res.status(401).json({ error: 'Reconnectez-vous pour accéder à votre profil.' });
  }
  if (!Number.isSafeInteger(Number(req.user?.userId)) || Number(req.user.userId) <= 0) {
    return res.status(401).json({ error: 'Session invalide. Reconnectez-vous.' });
  }
  return next();
}

function sendValidationError(req, res) {
  const errors = validationResult(req);
  if (errors.isEmpty()) return false;
  res.status(400).json({ error: errors.array()[0].msg });
  return true;
}

function parsePositiveId(value) {
  const id = Number.parseInt(value, 10);
  return Number.isSafeInteger(id) && id > 0 ? id : null;
}

function publicProfile(row) {
  const avatar = row.avatar_data;
  return {
    id: row.id,
    firstName: row.first_name,
    lastName: row.last_name,
    email: row.email,
    phone: row.phone,
    role: row.role,
    createdAt: row.created_at,
    company: row.entreprise || '',
    address: row.adresse || '',
    city: row.ville || '',
    country: row.pays || 'Togo',
    avatarData: avatar
      ? Buffer.isBuffer(avatar)
        ? avatar.toString('base64')
        : Buffer.from(avatar).toString('base64')
      : null,
    avatarMimeType: row.avatar_mime_type || null,
  };
}

const PROFILE_SELECT = `
  SELECT u.id, u.first_name, u.last_name, u.email, u.phone, u.role, u.created_at,
         u.avatar_data, u.avatar_mime_type,
         c.entreprise, c.adresse, c.ville, c.pays
  FROM users u
  LEFT JOIN clients c ON c.user_id = u.id
`;

function decodeImage(image) {
  if (!image || typeof image !== 'object' || Array.isArray(image)) {
    return { error: 'Image invalide.' };
  }
  const allowedTypes = new Set(['image/jpeg', 'image/png', 'image/webp']);
  if (!allowedTypes.has(image.mimeType) || typeof image.data !== 'string') {
    return { error: 'Formats acceptés : JPEG, PNG et WebP.' };
  }

  const maxBase64Length = Math.ceil(MAX_ATTACHMENT_BYTES / 3) * 4 + 4;
  if (image.data.length === 0 || image.data.length > maxBase64Length) {
    return { error: 'Le fichier image dépasse la taille autorisée.' };
  }

  let bytes;
  try {
    bytes = Buffer.from(image.data, 'base64');
  } catch (_) {
    return { error: 'Contenu image invalide.' };
  }
  if (
    bytes.length === 0 ||
    bytes.toString('base64').replace(/=+$/, '') !== image.data.replace(/=+$/, '')
  ) {
    return { error: 'Contenu image invalide.' };
  }

  const isJpeg = bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  const isPng = bytes.length >= 8 && bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
  const isWebp =
    bytes.length >= 12 &&
    bytes.toString('ascii', 0, 4) === 'RIFF' &&
    bytes.toString('ascii', 8, 12) === 'WEBP';
  const contentMatches =
    (image.mimeType === 'image/jpeg' && isJpeg) ||
    (image.mimeType === 'image/png' && isPng) ||
    (image.mimeType === 'image/webp' && isWebp);
  if (!contentMatches) return { error: 'Le contenu ne correspond pas au format annoncé.' };
  return { bytes, mimeType: image.mimeType };
}

function profileImageFromRequest(req) {
  const decoded = decodeImage(req.body?.image);
  if (decoded.error) return decoded;
  if (decoded.bytes.length > MAX_AVATAR_BYTES) {
    return { error: 'La photo de profil doit peser 1 Mo maximum.' };
  }
  return decoded;
}

async function transaction(work) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await work(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

router.get('/me', authMiddleware, accountTokenRequired, async (req, res) => {
  try {
    const result = await pool.query(
      `${PROFILE_SELECT} WHERE u.id = $1`,
      [Number(req.user.userId)],
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Utilisateur introuvable.' });
    }
    res.set('Cache-Control', 'no-store');
    return res.json({ profile: publicProfile(result.rows[0]) });
  } catch (error) {
    console.error('Erreur lecture profil:', error);
    return res.status(500).json({ error: 'Impossible de charger le profil.' });
  }
});

router.patch('/me', authMiddleware, accountTokenRequired, [
  body('firstName').isString().trim().notEmpty().isLength({ max: 100 }).withMessage('Le prénom est requis (100 caractères maximum).'),
  body('lastName').isString().trim().notEmpty().isLength({ max: 100 }).withMessage('Le nom est requis (100 caractères maximum).'),
  body('email').isString().trim().isEmail().withMessage('Adresse e-mail invalide.'),
  body('phone').isString().trim().isLength({ min: 8, max: 20 }).withMessage('Téléphone requis (8 à 20 caractères).'),
  body('company').optional().isString().isLength({ max: 255 }).withMessage('Nom de l’entreprise trop long.'),
  body('address').optional().isString().isLength({ max: 2000 }).withMessage('Adresse trop longue.'),
  body('city').optional().isString().isLength({ max: 100 }).withMessage('Ville trop longue.'),
  body('country').optional().isString().isLength({ max: 100 }).withMessage('Pays trop long.'),
  body('currentPassword').optional().isString().isLength({ max: 200 }),
], async (req, res) => {
  if (sendValidationError(req, res)) return;

  const userId = Number(req.user.userId);
  const firstName = String(req.body.firstName).trim();
  const lastName = String(req.body.lastName).trim();
  const email = normalizeEmail(req.body.email);
  const phone = normalizePhone(req.body.phone);
  if (!phone || phone.length > 20) {
    return res.status(400).json({ error: 'Numéro de téléphone invalide.' });
  }

  try {
    const profile = await transaction(async (client) => {
      const currentResult = await client.query(
        'SELECT id, first_name, last_name, email, phone, password_hash, role FROM users WHERE id = $1 FOR UPDATE',
        [userId],
      );
      if (currentResult.rows.length === 0) {
        const error = new Error('Utilisateur introuvable.');
        error.statusCode = 404;
        throw error;
      }
      const current = currentResult.rows[0];
      const contactChanged =
        email !== normalizeEmail(current.email) || phone !== current.phone;
      if (contactChanged) {
        const currentPassword = String(req.body.currentPassword || '');
        if (!currentPassword || !(await bcrypt.compare(currentPassword, current.password_hash))) {
          const error = new Error('Mot de passe actuel incorrect ou manquant.');
          error.statusCode = 401;
          throw error;
        }
      }

      const duplicate = await client.query(
        `SELECT id FROM users
         WHERE id <> $1 AND (LOWER(email) = $2 OR phone = ANY($3::text[]))
         LIMIT 1`,
        [userId, email, getPhoneCandidates(phone)],
      );
      if (duplicate.rows.length > 0) {
        const error = new Error('Cet e-mail ou ce téléphone est déjà utilisé par un autre compte.');
        error.statusCode = 409;
        throw error;
      }

      await client.query(
        `UPDATE users
         SET first_name = $1, last_name = $2, email = $3, phone = $4,
             updated_at = CURRENT_TIMESTAMP
         WHERE id = $5`,
        [firstName, lastName, email, phone, userId],
      );
      await client.query(
        `INSERT INTO clients (user_id, entreprise, adresse, ville, pays)
         VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT (user_id) DO UPDATE SET
           entreprise = EXCLUDED.entreprise,
           adresse = EXCLUDED.adresse,
           ville = EXCLUDED.ville,
           pays = EXCLUDED.pays,
           updated_at = CURRENT_TIMESTAMP`,
        [
          userId,
          String(req.body.company || '').trim() || null,
          String(req.body.address || '').trim() || null,
          String(req.body.city || '').trim() || null,
          String(req.body.country || 'Togo').trim() || 'Togo',
        ],
      );
      const refreshed = await client.query(
        `${PROFILE_SELECT} WHERE u.id = $1`,
        [userId],
      );
      return publicProfile(refreshed.rows[0]);
    });

    const secret = process.env.JWT_SECRET?.trim();
    if (!secret) return res.status(503).json({ error: 'Service d’authentification indisponible.' });
    const token = jwt.sign(
      { userId, email: profile.email, role: profile.role },
      secret,
      { expiresIn: '30d' },
    );
    res.set('Cache-Control', 'no-store');
    return res.json({ profile, token });
  } catch (error) {
    if (error.statusCode) return res.status(error.statusCode).json({ error: error.message });
    if (error.code === '23505') {
      return res.status(409).json({ error: 'Cet e-mail ou ce téléphone est déjà utilisé par un autre compte.' });
    }
    console.error('Erreur modification profil:', error);
    return res.status(500).json({ error: 'Impossible d’enregistrer le profil.' });
  }
});

router.post('/password', authMiddleware, accountTokenRequired, [
  body('currentPassword').isString().notEmpty().withMessage('Mot de passe actuel requis.'),
  body('newPassword')
    .isString()
    .isLength({ min: 6, max: 200 }).withMessage('Mot de passe minimum 6 caractères.')
    .matches(/[a-zA-Z]/).withMessage('Le mot de passe doit contenir des lettres.')
    .matches(/[0-9]/).withMessage('Le mot de passe doit contenir des chiffres.'),
], async (req, res) => {
  if (sendValidationError(req, res)) return;
  try {
    const result = await pool.query(
      'SELECT password_hash FROM users WHERE id = $1',
      [Number(req.user.userId)],
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Utilisateur introuvable.' });
    if (!(await bcrypt.compare(String(req.body.currentPassword), result.rows[0].password_hash))) {
      return res.status(401).json({ error: 'Mot de passe actuel incorrect.' });
    }
    const passwordHash = await bcrypt.hash(String(req.body.newPassword), 10);
    await pool.query(
      'UPDATE users SET password_hash = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2',
      [passwordHash, Number(req.user.userId)],
    );
    return res.json({ message: 'Mot de passe mis à jour.' });
  } catch (error) {
    console.error('Erreur changement mot de passe:', error);
    return res.status(500).json({ error: 'Impossible de modifier le mot de passe.' });
  }
});

router.put('/me/avatar', authMiddleware, accountTokenRequired, async (req, res) => {
  const image = profileImageFromRequest(req);
  if (image.error) return res.status(400).json({ error: image.error });
  try {
    const result = await pool.query(
      `UPDATE users SET avatar_data = $1, avatar_mime_type = $2,
       updated_at = CURRENT_TIMESTAMP WHERE id = $3 RETURNING id`,
      [image.bytes, image.mimeType, Number(req.user.userId)],
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Utilisateur introuvable.' });
    const profileResult = await pool.query(`${PROFILE_SELECT} WHERE u.id = $1`, [Number(req.user.userId)]);
    res.set('Cache-Control', 'no-store');
    return res.json({ profile: publicProfile(profileResult.rows[0]) });
  } catch (error) {
    console.error('Erreur photo de profil:', error);
    return res.status(500).json({ error: 'Impossible d’enregistrer la photo.' });
  }
});

router.delete('/me/avatar', authMiddleware, accountTokenRequired, async (req, res) => {
  try {
    await pool.query(
      `UPDATE users SET avatar_data = NULL, avatar_mime_type = NULL,
       updated_at = CURRENT_TIMESTAMP WHERE id = $1`,
      [Number(req.user.userId)],
    );
    return res.json({ message: 'Photo de profil supprimée.' });
  } catch (error) {
    console.error('Erreur suppression photo profil:', error);
    return res.status(500).json({ error: 'Impossible de supprimer la photo.' });
  }
});

router.post('/support-messages', authMiddleware, accountTokenRequired, [
  body('message').isString().trim().notEmpty().isLength({ max: MAX_PROFILE_TEXT }).withMessage('Le message est requis (5 000 caractères maximum).'),
  body('attachments').optional().isArray({ max: MAX_ATTACHMENT_COUNT }).withMessage('Ajoutez 3 images maximum.'),
], async (req, res) => {
  if (sendValidationError(req, res)) return;
  const attachments = (req.body.attachments || []).map(decodeImage);
  const invalidImage = attachments.find((image) => image.error);
  if (invalidImage) return res.status(400).json({ error: invalidImage.error });
  const totalBytes = attachments.reduce((sum, image) => sum + image.bytes.length, 0);
  if (totalBytes > MAX_ATTACHMENT_BYTES) {
    return res.status(400).json({ error: 'Le total des images ne peut pas dépasser 2 Mo.' });
  }

  try {
    const message = await transaction(async (client) => {
      const inserted = await client.query(
        `INSERT INTO profile_support_messages (user_id, message)
         VALUES ($1, $2) RETURNING id, created_at`,
        [Number(req.user.userId), String(req.body.message).trim()],
      );
      const saved = inserted.rows[0];
      for (const image of attachments) {
        await client.query(
          `INSERT INTO support_message_attachments (support_message_id, mime_type, image_data, byte_size)
           VALUES ($1, $2, $3, $4)`,
          [saved.id, image.mimeType, image.bytes, image.bytes.length],
        );
      }
      return saved;
    });
    return res.status(201).json({
      message: 'Votre message a été transmis au support.',
      supportMessage: { id: message.id, createdAt: message.created_at },
    });
  } catch (error) {
    console.error('Erreur envoi support:', error);
    return res.status(500).json({ error: 'Impossible d’envoyer le message au support.' });
  }
});

router.post('/training-interests', authMiddleware, accountTokenRequired, [
  body('trainingName').isString().trim().notEmpty().isLength({ max: 150 }).withMessage('Formation requise.'),
  body('message').optional().isString().isLength({ max: 2000 }).withMessage('Message trop long.'),
], async (req, res) => {
  if (sendValidationError(req, res)) return;
  const trainingName = String(req.body.trainingName).trim();
  if (!TRAINING_NAMES.has(trainingName)) return res.status(400).json({ error: 'Formation inconnue.' });
  try {
    const result = await pool.query(
      `INSERT INTO profile_training_interests (user_id, training_name, message)
       VALUES ($1, $2, $3) RETURNING id, status, created_at`,
      [Number(req.user.userId), trainingName, String(req.body.message || '').trim() || null],
    );
    return res.status(201).json({ interest: result.rows[0] });
  } catch (error) {
    console.error('Erreur demande formation:', error);
    return res.status(500).json({ error: 'Impossible d’enregistrer la demande de formation.' });
  }
});

router.post('/ratings', authMiddleware, accountTokenRequired, [
  body('rating').isInt({ min: 1, max: 5 }).withMessage('La note doit être comprise entre 1 et 5.'),
  body('comment').optional().isString().isLength({ max: 1000 }).withMessage('Commentaire trop long.'),
], async (req, res) => {
  if (sendValidationError(req, res)) return;
  try {
    const result = await pool.query(
      `INSERT INTO profile_app_ratings (user_id, rating, comment)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id) DO UPDATE SET
         rating = EXCLUDED.rating,
         comment = EXCLUDED.comment,
         updated_at = CURRENT_TIMESTAMP
       RETURNING id, rating, comment, created_at, updated_at`,
      [Number(req.user.userId), Number(req.body.rating), String(req.body.comment || '').trim() || null],
    );
    return res.status(201).json({ rating: result.rows[0] });
  } catch (error) {
    console.error('Erreur évaluation application:', error);
    return res.status(500).json({ error: 'Impossible d’enregistrer l’évaluation.' });
  }
});

router.get('/admin/support-messages', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT sm.id, sm.message, sm.status, sm.created_at,
              u.first_name, u.last_name, u.email, u.phone,
              COALESCE(json_agg(json_build_object(
                'id', a.id,
                'mimeType', a.mime_type,
                'byteSize', a.byte_size
              )) FILTER (WHERE a.id IS NOT NULL), '[]'::json) AS attachments
       FROM profile_support_messages sm
       JOIN users u ON u.id = sm.user_id
       LEFT JOIN support_message_attachments a ON a.support_message_id = sm.id
       GROUP BY sm.id, u.id
       ORDER BY sm.created_at DESC LIMIT 200`,
    );
    res.set('Cache-Control', 'no-store');
    return res.json({ messages: result.rows });
  } catch (error) {
    console.error('Erreur lecture support admin:', error);
    return res.status(500).json({ error: 'Impossible de charger les messages de support.' });
  }
});

router.get('/admin/support-messages/:id/attachments/:attachmentId', authMiddleware, adminMiddleware, async (req, res) => {
  const messageId = parsePositiveId(req.params.id);
  const attachmentId = parsePositiveId(req.params.attachmentId);
  if (!messageId || !attachmentId) return res.status(400).json({ error: 'Identifiant de pièce jointe invalide.' });
  try {
    const result = await pool.query(
      `SELECT id, mime_type, image_data FROM support_message_attachments
       WHERE id = $1 AND support_message_id = $2`,
      [attachmentId, messageId],
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Pièce jointe introuvable.' });
    const attachment = result.rows[0];
    res.set('Cache-Control', 'no-store');
    return res.json({
      attachment: {
        id: attachment.id,
        mimeType: attachment.mime_type,
        data: attachment.image_data.toString('base64'),
      },
    });
  } catch (error) {
    console.error('Erreur lecture pièce jointe support:', error);
    return res.status(500).json({ error: 'Impossible de charger la pièce jointe.' });
  }
});

router.patch('/admin/support-messages/:id/status', authMiddleware, adminMiddleware, [
  body('status').isIn(SUPPORT_STATUSES).withMessage('Statut de support invalide.'),
], async (req, res) => {
  if (sendValidationError(req, res)) return;
  try {
    const result = await pool.query(
      `UPDATE profile_support_messages
       SET status = $1, updated_at = CURRENT_TIMESTAMP
       WHERE id = $2
       RETURNING id, status, updated_at`,
      [req.body.status, req.params.id],
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Message introuvable.' });
    return res.json({ message: result.rows[0] });
  } catch (error) {
    console.error('Erreur statut support:', error);
    return res.status(500).json({ error: 'Impossible de modifier le statut.' });
  }
});

router.get('/admin/training-interests', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT ti.id, ti.training_name, ti.message, ti.status, ti.created_at,
              u.first_name, u.last_name, u.email, u.phone
       FROM profile_training_interests ti
       JOIN users u ON u.id = ti.user_id
       ORDER BY ti.created_at DESC LIMIT 200`,
    );
    res.set('Cache-Control', 'no-store');
    return res.json({ interests: result.rows });
  } catch (error) {
    console.error('Erreur lecture demandes formation:', error);
    return res.status(500).json({ error: 'Impossible de charger les demandes de formation.' });
  }
});

router.patch('/admin/training-interests/:id/status', authMiddleware, adminMiddleware, [
  body('status').isIn(TRAINING_STATUSES).withMessage('Statut de formation invalide.'),
], async (req, res) => {
  if (sendValidationError(req, res)) return;
  try {
    const result = await pool.query(
      `UPDATE profile_training_interests
       SET status = $1, updated_at = CURRENT_TIMESTAMP
       WHERE id = $2
       RETURNING id, status, updated_at`,
      [req.body.status, req.params.id],
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Demande introuvable.' });
    return res.json({ interest: result.rows[0] });
  } catch (error) {
    console.error('Erreur statut demande formation:', error);
    return res.status(500).json({ error: 'Impossible de modifier le statut.' });
  }
});

router.get('/admin/ratings', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT r.id, r.rating, r.comment, r.created_at, r.updated_at,
              u.first_name, u.last_name, u.email
       FROM profile_app_ratings r
       JOIN users u ON u.id = r.user_id
       ORDER BY r.updated_at DESC LIMIT 200`,
    );
    res.set('Cache-Control', 'no-store');
    return res.json({ ratings: result.rows });
  } catch (error) {
    console.error('Erreur lecture évaluations:', error);
    return res.status(500).json({ error: 'Impossible de charger les évaluations.' });
  }
});

module.exports = router;
