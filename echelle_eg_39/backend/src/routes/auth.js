const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');
const pool = require('../config/database');
const { authMiddleware } = require('../middleware/auth');

// Inscription
router.post('/register', [
  body('firstName').trim().notEmpty().withMessage('Prénom requis'),
  body('lastName').trim().notEmpty().withMessage('Nom requis'),
  body('email').isEmail().normalizeEmail().withMessage('Email invalide'),
  body('phone').trim().notEmpty().withMessage('Téléphone requis'),
  body('password').isLength({ min: 6 }).withMessage('Mot de passe minimum 6 caractères')
    .matches(/[a-zA-Z]/).withMessage('Doit contenir des lettres')
    .matches(/[0-9]/).withMessage('Doit contenir des chiffres'),
], async (req, res) => {
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
    const phone = String(req.body.phone).trim();
    const password = req.body.password;

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
    console.log('Utilisateur créé avec succès - ID:', user.id);

    // Générer le token JWT avec valeur par défaut
    const jwtSecret = process.env.JWT_SECRET || 'echelle-eg39-secret-key-2024';
    const token = jwt.sign(
      { userId: user.id, email: user.email, role: user.role },
      jwtSecret,
      { expiresIn: '30d' }
    );

    res.status(201).json({
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
    });
  } catch (error) {
    console.error('Erreur inscription complète:', error);
    
    // Messages d'erreur spécifiques selon le type d'erreur
    if (error.code === '23505') {
      // PostgreSQL unique violation
      return res.status(400).json({ error: 'Email ou téléphone déjà utilisé (doublon)' });
    }
    
    if (error.code === 'ECONNREFUSED') {
      return res.status(500).json({ error: 'Base de données non disponible' });
    }
    
    if (error.code === '23502') {
      // PostgreSQL not null violation
      return res.status(400).json({ error: 'Un champ requis est manquant' });
    }
    
    // Erreur générique mais avec détail en log
    res.status(500).json({ error: 'Erreur serveur lors de l\'inscription' });
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

    // Chercher l'utilisateur par email ou téléphone
    const result = await pool.query(
      'SELECT * FROM users WHERE email = $1 OR phone = $1',
      [identifier]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Identifiants invalides' });
    }

    const user = result.rows[0];

    // Vérifier le mot de passe
    const isValidPassword = await bcrypt.compare(password, user.password_hash);
    if (!isValidPassword) {
      return res.status(401).json({ error: 'Identifiants invalides' });
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