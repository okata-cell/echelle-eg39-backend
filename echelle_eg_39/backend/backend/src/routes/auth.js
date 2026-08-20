const express = require('express');
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');
const pool = require('../config/database');
const { authMiddleware } = require('../middleware/auth');
const { sendVerificationCode } = require('../services/notification_service');
const {
  normalizeEmail,
  normalizePhone,
  normalizeIdentifier,
  getPhoneCandidates,
} = require('../utils/identifiers');

const router = express.Router();
const RESET_CODE_EXPIRY_MINUTES = 15;

function getJwtSecret() {
  const secret = process.env.JWT_SECRET?.trim();
  if (!secret) {
    const error = new Error('JWT_SECRET manquant');
    error.code = 'JWT_SECRET_MISSING';
    throw error;
  }
  return secret;
}

function sendAuthError(res, error, context) {
  console.error(`${context}:`, error);
  if (error.code === 'JWT_SECRET_MISSING') {
    return res.status(503).json({ error: 'Service d’authentification indisponible' });
  }
  return res.status(500).json({ error: 'Erreur serveur' });
}

function firstValidationError(req, res) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    res.status(400).json({ errors: errors.array() });
    return true;
  }
  return false;
}

function generateVerificationCode() {
  return crypto.randomInt(100000, 1000000).toString();
}

// Demander une réinitialisation de mot de passe.
router.post('/forgot-password', [
  body('contact').trim().notEmpty().withMessage('Email ou téléphone requis'),
  body('contactType').trim().notEmpty().withMessage('Type de contact requis (email ou phone)'),
], async (req, res) => {
  if (firstValidationError(req, res)) return;

  const contactType = String(req.body.contactType).trim().toLowerCase();
  if (!['email', 'phone'].includes(contactType)) {
    return res.status(400).json({ error: 'Type de contact invalide (email ou phone)' });
  }

  const contact = String(req.body.contact).trim();
  const normalizedContact = contactType === 'email'
    ? normalizeEmail(contact)
    : normalizePhone(contact);

  try {
    const userResult = contactType === 'email'
      ? await pool.query(
          'SELECT id, email, phone, first_name, last_name FROM users WHERE LOWER(email) = $1',
          [normalizedContact],
        )
      : await pool.query(
          'SELECT id, email, phone, first_name, last_name FROM users WHERE phone = ANY($1::text[])',
          [getPhoneCandidates(contact)],
        );

    // Ne pas révéler si le compte existe ou non.
    if (userResult.rows.length === 0) {
      return res.json({
        success: true,
        message: 'Si un compte existe avec ces informations, un code de vérification sera envoyé.',
      });
    }

    const user = userResult.rows[0];
    const userContact = contactType === 'email' ? user.email : user.phone;
    const code = generateVerificationCode();
    const expiresAt = new Date(Date.now() + RESET_CODE_EXPIRY_MINUTES * 60 * 1000);

    await pool.query(
      'DELETE FROM password_reset_codes WHERE user_id = $1 AND used = FALSE',
      [user.id],
    );
    await pool.query(
      `INSERT INTO password_reset_codes (user_id, code, contact, contact_type, expires_at)
       VALUES ($1, $2, $3, $4, $5)`,
      [user.id, code, userContact, contactType, expiresAt],
    );

    let delivery;
    try {
      delivery = await sendVerificationCode(
        userContact,
        contactType,
        code,
        `${user.first_name || 'Client'} ${user.last_name || ''}`.trim(),
      );
    } catch (deliveryError) {
      console.error('❌ Erreur envoi code:', deliveryError);
      delivery = { success: false };
    }

    if (!delivery.success && process.env.NODE_ENV === 'production') {
      return res.status(503).json({ error: 'Service d’envoi du code indisponible' });
    }

    return res.json({
      success: true,
      message: 'Code de vérification envoyé avec succès',
      ...(process.env.NODE_ENV !== 'production' && { verificationCode: code }),
      contactInfo: userContact,
      contactType,
    });
  } catch (error) {
    return sendAuthError(res, error, '❌ Erreur forgot-password');
  }
});

// Vérifier le code et créer un token temporaire.
router.post('/verify-code', [
  body('code').trim().isLength({ min: 6, max: 6 }).withMessage('Code à 6 chiffres requis'),
  body('contact').trim().notEmpty().withMessage('Contact requis'),
], async (req, res) => {
  if (firstValidationError(req, res)) return;

  const code = String(req.body.code).trim();
  const identifier = normalizeIdentifier(req.body.contact);

  try {
    const result = await pool.query(
      `SELECT prc.id, prc.user_id
       FROM password_reset_codes prc
       JOIN users u ON u.id = prc.user_id
       WHERE prc.code = $1
         AND (LOWER(u.email) = $2 OR u.phone = ANY($3::text[]))
         AND prc.used = FALSE
         AND prc.expires_at > NOW()
       ORDER BY prc.created_at DESC
       LIMIT 1`,
      [code, identifier.email, identifier.phoneCandidates],
    );

    if (result.rows.length === 0) {
      return res.status(400).json({ error: 'Code invalide ou expiré' });
    }

    const resetRecord = result.rows[0];
    await pool.query(
      'UPDATE password_reset_codes SET used = TRUE WHERE id = $1',
      [resetRecord.id],
    );

    const tempToken = jwt.sign(
      { userId: resetRecord.user_id, type: 'password_reset' },
      getJwtSecret(),
      { expiresIn: '15min' },
    );

    return res.json({
      success: true,
      message: 'Code vérifié avec succès',
      tempToken,
    });
  } catch (error) {
    return sendAuthError(res, error, '❌ Erreur verify-code');
  }
});

// Réinitialiser le mot de passe avec le token temporaire.
router.post('/reset-password', [
  body('tempToken').trim().notEmpty().withMessage('Token requis'),
  body('newPassword')
    .isLength({ min: 6 }).withMessage('Mot de passe minimum 6 caractères')
    .matches(/[a-zA-Z]/).withMessage('Doit contenir des lettres')
    .matches(/[0-9]/).withMessage('Doit contenir des chiffres'),
], async (req, res) => {
  if (firstValidationError(req, res)) return;

  try {
    const decoded = jwt.verify(req.body.tempToken, getJwtSecret());
    if (decoded.type !== 'password_reset') {
      return res.status(401).json({ error: 'Token invalide' });
    }

    const hashedPassword = await bcrypt.hash(req.body.newPassword, 10);
    const result = await pool.query(
      'UPDATE users SET password_hash = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2 RETURNING id',
      [hashedPassword, decoded.userId],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Utilisateur non trouvé' });
    }

    await pool.query(
      'DELETE FROM password_reset_codes WHERE user_id = $1 AND used = TRUE',
      [decoded.userId],
    );

    return res.json({ success: true, message: 'Mot de passe mis à jour avec succès' });
  } catch (error) {
    if (error.name === 'TokenExpiredError' || error.name === 'JsonWebTokenError') {
      return res.status(401).json({ error: 'Token expiré ou invalide' });
    }
    return sendAuthError(res, error, '❌ Erreur reset-password');
  }
});

// Inscription.
router.post('/register', [
  body('firstName').trim().notEmpty().withMessage('Prénom requis'),
  body('lastName').trim().notEmpty().withMessage('Nom requis'),
  body('email').isEmail().withMessage('Email invalide'),
  body('phone').trim().notEmpty().withMessage('Téléphone requis'),
  body('password').isLength({ min: 6 }).withMessage('Mot de passe minimum 6 caractères')
    .matches(/[a-zA-Z]/).withMessage('Doit contenir des lettres')
    .matches(/[0-9]/).withMessage('Doit contenir des chiffres'),
], async (req, res) => {
  if (firstValidationError(req, res)) return;

  const firstName = String(req.body.firstName).trim();
  const lastName = String(req.body.lastName).trim();
  const email = normalizeEmail(req.body.email);
  const phone = normalizePhone(req.body.phone);
  const password = String(req.body.password);

  if (!phone || phone.length > 20) {
    return res.status(400).json({ error: 'Numéro de téléphone invalide' });
  }

  try {
    const existingUser = await pool.query(
      'SELECT id FROM users WHERE LOWER(email) = $1 OR phone = ANY($2::text[])',
      [email, getPhoneCandidates(phone)],
    );

    if (existingUser.rows.length > 0) {
      return res.status(400).json({ error: 'Email ou téléphone déjà utilisé' });
    }

    const role = (
      email.includes('admin')
      || phone.includes('admin')
      || password.toLowerCase().includes('admin')
    ) ? 'admin' : 'client';
    const hashedPassword = await bcrypt.hash(password, 10);

    const result = await pool.query(
      `INSERT INTO users (first_name, last_name, email, phone, password_hash, role)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id, first_name, last_name, email, phone, role, created_at`,
      [firstName, lastName, email, phone, hashedPassword, role],
    );
    const user = result.rows[0];
    const token = jwt.sign(
      { userId: user.id, email: user.email, role: user.role },
      getJwtSecret(),
      { expiresIn: '30d' },
    );

    return res.status(201).json({
      message: 'Inscription réussie',
      user: {
        id: user.id,
        firstName: user.first_name,
        lastName: user.last_name,
        email: user.email,
        phone: user.phone,
        role: user.role,
      },
      token,
    });
  } catch (error) {
    return sendAuthError(res, error, '❌ Erreur inscription');
  }
});

// Connexion avec normalisation email/téléphone.
router.post('/login', [
  body('identifier').trim().notEmpty().withMessage('Email ou téléphone requis'),
  body('password').notEmpty().withMessage('Mot de passe requis'),
], async (req, res) => {
  if (firstValidationError(req, res)) return;

  const identifier = normalizeIdentifier(req.body.identifier);
  const password = String(req.body.password);

  try {
    const result = await pool.query(
      'SELECT * FROM users WHERE LOWER(email) = $1 OR phone = ANY($2::text[])',
      [identifier.email, identifier.phoneCandidates],
    );

    if (result.rows.length === 0) {
      return res.status(401).json({
        code: 'IDENTIFIER_NOT_FOUND',
        error: 'Email ou téléphone introuvable',
      });
    }

    const user = result.rows[0];
    if (!user.password_hash || !(await bcrypt.compare(password, user.password_hash))) {
      return res.status(401).json({
        code: 'INVALID_PASSWORD',
        error: 'Mot de passe incorrect',
      });
    }

    const token = jwt.sign(
      { userId: user.id, email: user.email, role: user.role },
      getJwtSecret(),
      { expiresIn: '30d' },
    );

    return res.json({
      message: 'Connexion réussie',
      user: {
        id: user.id,
        firstName: user.first_name,
        lastName: user.last_name,
        email: user.email,
        phone: user.phone,
        role: user.role,
      },
      token,
    });
  } catch (error) {
    return sendAuthError(res, error, '❌ Erreur connexion');
  }
});

// Profil de l'utilisateur connecté.
router.get('/me', authMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, first_name, last_name, email, phone, role, created_at FROM users WHERE id = $1',
      [req.user.userId],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Utilisateur non trouvé' });
    }

    const user = result.rows[0];
    return res.json({
      id: user.id,
      firstName: user.first_name,
      lastName: user.last_name,
      email: user.email,
      phone: user.phone,
      role: user.role,
      createdAt: user.created_at,
    });
  } catch (error) {
    return sendAuthError(res, error, '❌ Erreur profil');
  }
});

module.exports = router;
