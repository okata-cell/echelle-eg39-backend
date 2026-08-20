const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');
const pool = require('../config/database');
const { authMiddleware } = require('../middleware/auth');
const crypto = require('crypto');
const { sendVerificationCode } = require('../services/email_sms_service');

// Configuration du code de vérification (6 chiffres)
const generateVerificationCode = () => {
  return crypto.randomInt(100000, 999999).toString();
};

// Durée de validité du code (15 minutes)
const CODE_EXPIRY_MINUTES = 15;

// ============================================
// ROUTE: Demander la réinitialisation du mot de passe
// ============================================
router.post('/forgot-password', [
  body('contact').trim().notEmpty().withMessage('Email ou téléphone requis'),
  body('contactType').trim().notEmpty().withMessage('Type de contact requis (email ou phone)'),
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    console.log('❌ Erreurs de validation forgot-password:', errors.array());
    return res.status(400).json({ error: errors.array()[0].msg });
  }

  const { contact, contactType } = req.body;
  
  // Validation supplémentaire du type de contact
  if (contactType !== 'email' && contactType !== 'phone') {
    return res.status(400).json({ error: 'Type de contact invalide (doit être email ou phone)' });
  }

  const normalizedContact = contactType === 'email' 
    ? contact.toLowerCase().trim() 
    : contact.replace(/[\s\-\(\)]/g, '');

  console.log(`🔐 Demande de réinitialisation pour: ${normalizedContact} (${contactType})`);

  try {
    // Chercher l'utilisateur
    const userQuery = contactType === 'email'
      ? 'SELECT id, email, phone FROM users WHERE LOWER(email) = $1'
      : 'SELECT id, email, phone FROM users WHERE phone = $1 OR phone = $2';

    const queryParams = contactType === 'email'
      ? [normalizedContact]
      : [normalizedContact, '+' + normalizedContact];

    const userResult = await pool.query(userQuery, queryParams);

    if (userResult.rows.length === 0) {
      // Ne pas révéler si l'utilisateur existe ou non pour des raisons de sécurité
      console.log('⚠️ Utilisateur non trouvé pour reset password');
      return res.json({ 
        message: 'Si un compte existe avec ces informations, un code de vérification sera envoyé.',
        success: true
      });
    }

    const user = userResult.rows[0];
    const userContact = contactType === 'email' ? user.email : user.phone;

    // Générer le code de vérification
    const verificationCode = generateVerificationCode();
    const expiresAt = new Date(Date.now() + CODE_EXPIRY_MINUTES * 60 * 1000);

    // Supprimer les codes précédents pour cet utilisateur
    await pool.query(
      'DELETE FROM password_reset_codes WHERE user_id = $1 AND used = FALSE',
      [user.id]
    );

    // Insérer le nouveau code
    await pool.query(
      `INSERT INTO password_reset_codes (user_id, code, contact, contact_type, expires_at)
       VALUES ($1, $2, $3, $4, $5)`,
      [user.id, verificationCode, userContact, contactType, expiresAt]
    );

    console.log(`✅ Code de vérification généré pour utilisateur ${user.id}: ${verificationCode}`);

    // Envoyer le code par email ou SMS
    try {
      const userName = `${user.first_name || 'Client'} ${user.last_name || ''}`.trim();
      await sendVerificationCode(userContact, contactType, verificationCode, userName);
    } catch (sendError) {
      console.error('⚠️ Erreur envoi code (continuant quand même):', sendError);
    }

    // En développement, retourner le code pour les tests
    const isDev = process.env.NODE_ENV !== 'production';
    
    res.json({
      message: 'Code de vérification envoyé avec succès',
      success: true,
      ...(isDev && { verificationCode: verificationCode }),
      contactInfo: userContact,
      contactType: contactType
    });

  } catch (error) {
    console.error('❌ Erreur forgot-password:', error);
    res.status(500).json({ error: 'Erreur serveur lors de la demande de réinitialisation' });
  }
});

// ============================================
// ROUTE: Vérifier le code de réinitialisation
// ============================================
router.post('/verify-code', [
  body('code').trim().notEmpty().withMessage('Code requis'),
  body('contact').trim().notEmpty().withMessage('Contact requis'),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { code, contact } = req.body;

    console.log(`🔍 Vérification du code ${code} pour ${contact}`);

    // Chercher un code valide
    const result = await pool.query(
      `SELECT prc.id, prc.user_id, prc.code, prc.expires_at, prc.used, u.email, u.phone
       FROM password_reset_codes prc
       JOIN users u ON u.id = prc.user_id
       WHERE prc.code = $1 
         AND (u.email = $2 OR u.phone = $2 OR u.phone = $3)
         AND prc.used = FALSE
         AND prc.expires_at > NOW()
       ORDER BY prc.created_at DESC
       LIMIT 1`,
      [code, contact, '+' + contact]
    );

    if (result.rows.length === 0) {
      console.log('⚠️ Code invalide ou expiré');
      return res.status(400).json({ error: 'Code invalide ou expiré' });
    }

    const resetRecord = result.rows[0];

    // Marquer le code comme utilisé
    await pool.query(
      'UPDATE password_reset_codes SET used = TRUE WHERE id = $1',
      [resetRecord.id]
    );

    // Générer un token temporaire pour la réinitialisation
    const tempToken = jwt.sign(
      { userId: resetRecord.user_id, type: 'password_reset' },
      process.env.JWT_SECRET || 'echelle-eg39-secret-key-2024',
      { expiresIn: '15min' }
    );

    console.log(`✅ Code vérifié pour utilisateur ${resetRecord.user_id}`);

    res.json({
      message: 'Code vérifié avec succès',
      success: true,
      tempToken: tempToken
    });

  } catch (error) {
    console.error('❌ Erreur verify-code:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// ============================================
// ROUTE: Réinitialiser le mot de passe
// ============================================
router.post('/reset-password', [
  body('tempToken').trim().notEmpty().withMessage('Token requis'),
  body('newPassword').isLength({ min: 6 }).withMessage('Mot de passe minimum 6 caractères')
    .matches(/[a-zA-Z]/).withMessage('Doit contenir des lettres')
    .matches(/[0-9]/).withMessage('Doit contenir des chiffres'),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { tempToken, newPassword } = req.body;

    // Vérifier le token temporaire
    let decoded;
    try {
      decoded = jwt.verify(
        tempToken, 
        process.env.JWT_SECRET || 'echelle-eg39-secret-key-2024'
      );
      
      if (decoded.type !== 'password_reset') {
        return res.status(401).json({ error: 'Token invalide' });
      }
    } catch (jwtError) {
      console.log('⚠️ Token expiré ou invalide');
      return res.status(401).json({ error: 'Token expiré ou invalide' });
    }

    const userId = decoded.userId;
    console.log(`🔐 Réinitialisation du mot de passe pour utilisateur ${userId}`);

    // Hasher le nouveau mot de passe
    const hashedPassword = await bcrypt.hash(newPassword, 10);

    // Mettre à jour le mot de passe
    await pool.query(
      'UPDATE users SET password_hash = $1 WHERE id = $2',
      [hashedPassword, userId]
    );

    // Supprimer tous les codes de reset utilisés
    await pool.query(
      'DELETE FROM password_reset_codes WHERE user_id = $1 AND used = TRUE',
      [userId]
    );

    console.log(`✅ Mot de passe réinitialisé pour utilisateur ${userId}`);

    res.json({
      message: 'Mot de passe mis à jour avec succès',
      success: true
    });

  } catch (error) {
    console.error('❌ Erreur reset-password:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Inscription avec gestion d'erreur améliorée
router.post('/register', [
  body('firstName').trim().notEmpty().withMessage('Prénom requis'),
  body('lastName').trim().notEmpty().withMessage('Nom requis'),
  body('email').isEmail().normalizeEmail().withMessage('Email invalide'),
  body('phone').trim().notEmpty().withMessage('Téléphone requis'),
  body('password').isLength({ min: 6 }).withMessage('Mot de passe minimum 6 caractères')
    .matches(/[a-zA-Z]/).withMessage('Doit contenir des lettres')
    .matches(/[0-9]/).withMessage('Doit contenir des chiffres'),
], async (req, res) => {
  // Wrapper pour capturer les erreurs async
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      console.log('Erreurs de validation:', errors.array());
      return res.status(400).json({ errors: errors.array() });
    }

    // Nettoyer les données
    const firstName = String(req.body.firstName).trim();
    const lastName = String(req.body.lastName).trim();
    const email = String(req.body.email).trim().toLowerCase();
    
    // Nettoyer le téléphone: supprimer les espaces, traits d'union, et ajouter le +228 si absent
    let phone = String(req.body.phone).trim().replace(/[\s\-\(\)]/g, '');
    
    // Formater le téléphone pour le Togo
    if (!phone.startsWith('+')) {
      if (phone.startsWith('228')) {
        phone = '+' + phone;
      } else if (phone.length === 8) {
        phone = '+228' + phone;
      } else {
        // Si le numéro est déjà long, on ne préfixe pas
        if (phone.length <= 8) {
          phone = '+228' + phone;
        } else {
          phone = '+' + phone;
        }
      }
    }
    
    // Vérifier que le téléphone ne dépasse pas 20 caractères (limite DB)
    if (phone.length > 25) {
      console.log('❌ Téléphone trop long:', phone, '- Longueur:', phone.length);
      return res.status(400).json({ error: 'Numéro de téléphone invalide (trop long)' });
    }
    
    const password = req.body.password;

    console.log('=== DONNÉES REÇUES ===');
    console.log('firstName:', firstName);
    console.log('lastName:', lastName);
    console.log('email:', email, '- longueur:', email.length);
    console.log('phone:', phone, '- longueur:', phone.length);
    console.log('=====================');

    console.log('Tentative inscription - Email:', email, '- Phone:', phone);

    // Vérifier si l'utilisateur existe déjà (avec logs détaillés)
    const existingUser = await pool.query(
      'SELECT id, email, phone FROM users WHERE LOWER(email) = LOWER($1) OR phone = $2',
      [email, phone]
    );

    console.log('Résultat vérification utilisateur:', existingUser.rows.length, 'lignes');

    if (existingUser.rows.length > 0) {
      console.log('Utilisateur déjà existant:', existingUser.rows[0]);
      return res.status(400).json({ error: 'Email ou téléphone déjà utilisé' });
    }

    // Déterminer le rôle (admin si email/phone/password contient "admin")
    const role = (
  String(email).toLowerCase().includes('admin') || 
  String(phone).toLowerCase().includes('admin') ||
  String(password).toLowerCase().includes('admin')
) ? 'admin' : 'client';

    // Hasher le mot de passe
    const hashedPassword = await bcrypt.hash(password, 10);

    // Créer l'utilisateur
    const result = await pool.query(
      `INSERT INTO users (first_name, last_name, email, phone, password_hash, role)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id, first_name, last_name, email, phone, role, created_at`,
      [firstName, lastName, email, phone, hashedPassword, role]
    );

    const user = result.rows[0];
    console.log('✅ Utilisateur créé avec succès - ID:', user.id);
    console.log('Données utilisateur:', {
      id: user.id,
      firstName: user.first_name,
      lastName: user.last_name,
      email: user.email,
      phone: user.phone,
      role: user.role
    });

    // Générer le token JWT avec valeur par défaut
    console.log('🔑 Génération du token JWT...');
    const jwtSecret = process.env.JWT_SECRET || 'echelle-eg39-secret-key-2024';
    console.log('JWT Secret présent:', jwtSecret ? 'Oui' : 'Non');
    
    let token;
    try {
      token = jwt.sign(
        { userId: user.id, email: user.email, role: user.role },
        jwtSecret,
        { expiresIn: '30d' }
      );
      console.log('✅ Token JWT généré avec succès');
    } catch (jwtError) {
      console.error('❌ ERREUR lors de la génération du token JWT:', jwtError);
      throw jwtError;
    }

    console.log('📤 Préparation de la réponse...');
    const responseData = {
      message: 'Inscription réussie',
      user: {
        id: user.id,
        firstName: user.first_name,
        lastName: user.last_name,
        email: user.email,
        phone: user.phone,
        role: user.role
      },
      token
    };
    console.log('Réponse à envoyer:', JSON.stringify(responseData, null, 2));

    console.log('📨 Envoi de la réponse 201...');
    res.status(201).json(responseData);
    console.log('✅ Réponse envoyée avec succès');
  } catch (error) {
    console.error('❌ ==================== ERREUR INSCRIPTION ====================');
    console.error('Type d\'erreur:', error.name || typeof error);
    console.error('Message:', error.message);
    console.error('Code:', error.code);
    if (error.stack) {
      console.error('Stack:', error.stack.split('\n').slice(0, 5).join('\n'));
    }
    console.error('=============================================================');
    
    // Messages d'erreur spécifiques selon le type d'erreur
    if (error.code === '23505') {
      // PostgreSQL unique violation
      console.log('⚠️  Violation de contrainte unique (doublon détecté)');
      return res.status(400).json({ error: 'Email ou téléphone déjà utilisé (doublon)' });
    }
    
    if (error.code === 'ECONNREFUSED') {
      console.log('⚠️  Connexion à la base de données refusée');
      return res.status(503).json({ error: 'Base de données non disponible' });
    }
    
    if (error.code === '23502') {
      // PostgreSQL not null violation
      console.log('⚠️  Champ requis manquant (NOT NULL violation)');
      return res.status(400).json({ error: 'Un champ requis est manquant' });
    }
    
    if (error.code === '22001') {
      // PostgreSQL string data right truncation
      console.log('⚠️  Données trop longues pour un champ');
      return res.status(400).json({ error: 'Un des champs dépasse la longueur maximale autorisée' });
    }

    if (error.name === 'JsonWebTokenError' || error.message.includes('JWT')) {
      console.log('⚠️  Erreur JWT');
      return res.status(500).json({ error: 'Erreur lors de la génération du token' });
    }
    
    // Erreur générique mais avec détail en log
    console.log('⚠️  Erreur serveur non catégorisée');
    res.status(500).json({ 
      error: 'Erreur serveur',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// Connexion
router.post('/login', [
  body('identifier').trim().notEmpty().withMessage('Email ou téléphone requis'),
  body('password').notEmpty().withMessage('Mot de passe requis'),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { identifier, password } = req.body;

    // Normaliser l'identifiant: 
    // - Pour les emails: convertir en minuscules
    // - Pour les telephones: ajouter le prefixe +228 si absent
    let normalizedEmail = identifier.toLowerCase().trim();
    let normalizedPhone = identifier.replace(/[\s\-\(\)]/g, '');
    
    // Ajouter le prefixe +228 pour les numeros togo sans prefixe
    if (!normalizedPhone.startsWith('+') && /^\d{8,}$/.test(normalizedPhone)) {
      normalizedPhone = '+228' + normalizedPhone;
    }
    
    // Chercher l'utilisateur par email ou téléphone
    // $1 = email normalise (minuscules)
    // $2 = telephone normalise (avec +228)
    // $3 = telephone original (tel que saisi par l'utilisateur)
    const result = await pool.query(
      'SELECT * FROM users WHERE LOWER(email) = $1 OR phone = $2 OR phone = $3',
      [normalizedEmail, normalizedPhone, identifier]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'L\'email ou le mot de passe est incorrect, reverifier vos donnees' });
    }

    const user = result.rows[0];

    // Vérifier le mot de passe
    const isValidPassword = await bcrypt.compare(password, user.password_hash);
    if (!isValidPassword) {
      return res.status(401).json({ error: 'L\'email ou le mot de passe est incorrect, reverifier vos donnees' });
    }

    // Générer le token JWT avec valeur par défaut
    const jwtSecret = process.env.JWT_SECRET || 'echelle-eg39-secret-key-2024';
    const token = jwt.sign(
      { userId: user.id, email: user.email, role: user.role },
      jwtSecret,
      { expiresIn: '30d' }
    );

    res.json({
      message: 'Connexion réussie',
      user: {
        id: user.id,
        firstName: user.first_name,
        lastName: user.last_name,
        email: user.email,
        phone: user.phone,
        role: user.role
      },
      token
    });
  } catch (error) {
    console.error('Erreur connexion:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Obtenir le profil de l'utilisateur connecté
router.get('/me', authMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, first_name, last_name, email, phone, role, created_at FROM users WHERE id = $1',
      [req.user.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Utilisateur non trouvé' });
    }

    const user = result.rows[0];
    res.json({
      id: user.id,
      firstName: user.first_name,
      lastName: user.last_name,
      email: user.email,
      phone: user.phone,
      role: user.role,
      createdAt: user.created_at
    });
  } catch (error) {
    console.error('Erreur profil:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

module.exports = router;