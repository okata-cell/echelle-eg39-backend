const express = require('express');
const { body, validationResult } = require('express-validator');
const pool = require('../config/database');
const { authMiddleware, adminMiddleware } = require('../middleware/auth');

const router = express.Router();

function parseClientId(value) {
  const id = Number.parseInt(value, 10);
  return Number.isSafeInteger(id) && id > 0 ? id : null;
}

function serializeClient(client) {
  return {
    id: client.id,
    firstName: client.first_name,
    lastName: client.last_name,
    email: client.email,
    phone: client.phone,
    role: client.role || 'client',
    createdAt: client.created_at,
    isActive: client.is_active !== false,
  };
}

router.get('/', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, first_name, last_name, email, phone, role, created_at, is_active
       FROM users
       WHERE role <> 'admin'
       ORDER BY created_at DESC, id DESC`,
    );

    res.set('Cache-Control', 'no-store');
    return res.json({ clients: result.rows.map(serializeClient) });
  } catch (error) {
    console.error('Erreur récupération clients:', error);
    return res.status(500).json({
      error: 'Erreur serveur lors de la récupération des clients',
    });
  }
});

const clientProfileValidators = [
  body('firstName').isString().trim().notEmpty().isLength({ max: 100 })
    .withMessage('Prénom requis (100 caractères maximum)'),
  body('lastName').isString().trim().notEmpty().isLength({ max: 100 })
    .withMessage('Nom requis (100 caractères maximum)'),
  body('email').isString().trim().isEmail().normalizeEmail()
    .isLength({ max: 255 }).withMessage('Adresse e-mail invalide'),
  body('phone').isString().trim().notEmpty().isLength({ min: 8, max: 20 })
    .withMessage('Téléphone requis (8 à 20 caractères)'),
];

router.patch(
  '/:id',
  authMiddleware,
  adminMiddleware,
  clientProfileValidators,
  async (req, res) => {
    const userId = parseClientId(req.params.id);
    if (!userId) {
      return res.status(400).json({ error: 'Identifiant client invalide' });
    }

    const validation = validationResult(req);
    if (!validation.isEmpty()) {
      return res.status(400).json({ error: validation.array()[0].msg });
    }

    const { firstName, lastName, email, phone } = req.body;
    try {
      const duplicate = await pool.query(
        `SELECT id FROM users
         WHERE id <> $1 AND (LOWER(email) = LOWER($2) OR phone = $3)
         LIMIT 1`,
        [userId, email, phone],
      );
      if (duplicate.rows.length > 0) {
        return res.status(409).json({
          error: 'Cet e-mail ou ce téléphone est déjà utilisé par un autre compte.',
        });
      }

      const result = await pool.query(
        `UPDATE users
         SET first_name = $1, last_name = $2, email = $3, phone = $4,
             updated_at = CURRENT_TIMESTAMP
         WHERE id = $5 AND role <> 'admin'
         RETURNING id, first_name, last_name, email, phone, role, created_at, is_active`,
        [firstName.trim(), lastName.trim(), email.trim(), phone.trim(), userId],
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Client introuvable' });
      }

      res.set('Cache-Control', 'no-store');
      return res.json({ client: serializeClient(result.rows[0]) });
    } catch (error) {
      if (error.code === '23505') {
        return res.status(409).json({
          error: 'Cet e-mail ou ce téléphone est déjà utilisé par un autre compte.',
        });
      }
      console.error('Erreur modification client:', error);
      return res.status(500).json({ error: 'Erreur serveur lors de la modification du client' });
    }
  },
);

router.patch('/:id/status', authMiddleware, adminMiddleware, async (req, res) => {
  const userId = parseClientId(req.params.id);
  if (!userId) {
    return res.status(400).json({ error: 'Identifiant client invalide' });
  }
  if (typeof req.body?.isActive !== 'boolean') {
    return res.status(400).json({ error: 'Le statut actif doit être un booléen' });
  }

  try {
    const result = await pool.query(
      `UPDATE users
       SET is_active = $1, updated_at = CURRENT_TIMESTAMP
       WHERE id = $2 AND role <> 'admin'
       RETURNING id, first_name, last_name, email, phone, role, created_at, is_active`,
      [req.body.isActive, userId],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Client introuvable' });
    }

    res.set('Cache-Control', 'no-store');
    return res.json({ client: serializeClient(result.rows[0]) });
  } catch (error) {
    console.error('Erreur changement statut client:', error);
    return res.status(500).json({ error: 'Erreur serveur lors du changement de statut' });
  }
});

module.exports = router;
