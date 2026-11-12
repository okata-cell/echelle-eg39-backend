const express = require('express');
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');
const pool = require('../config/database');
const { authMiddleware } = require('../middleware/auth');
const { createLoginThrottle } = require('../middleware/login_throttle');
const {
  hachageARenforcer,
  hasherMotDePasse,
  verifierMotDePasse: verifierHachage,
} = require('../utils/password_hash');
const {
  REGLES: REGLES_MOT_DE_PASSE,
  verifierMotDePasse: verifierPolitique,
} = require('../utils/password_policy');
const {
  generateRecoveryCode,
  hashRecoveryCode,
  matchesRecoveryCodeHash,
} = require('../utils/recovery_code');
const {
  normalizeEmail,
  normalizePhone,
  normalizeIdentifier,
  getPhoneCandidates,
} = require('../utils/identifiers');
const { hashIdentifiers } = require('../utils/identifier_hash');
const {
  chiffrerContact,
  contactsDuCompte,
  empreinteContact,
} = require('../utils/contact_crypto');
const { revokeAccount } = require('../services/session_revocation');
const {
  TEMPORARY_PASSWORD_DISPLAY_SECONDS,
  generateTemporaryPassword,
} = require('../utils/temporary_password');

const router = express.Router();
// Quatre échecs bloquent le compte 24 h ; une connexion réussie remet à zéro.
const loginThrottle = createLoginThrottle();
// Le code de récupération fait 8 caractères : on limite les essais pour qu'il
// ne puisse pas être deviné par répétition. Blocage court, le temps que la
// personne vérifie son code plutôt que de la pénaliser une journée.
const recoveryThrottle = createLoginThrottle({
  keyField: 'contact',
  maxAttempts: 6,
  blockMs: 15 * 60 * 1000,
});

/** Message de blocage, avec le délai réel pour que l'écran puisse l'afficher. */
function refusTropDeTentatives(res, throttle, retryAfter) {
  res.set('Retry-After', String(retryAfter));
  return res.status(429).json({
    code: 'TOO_MANY_ATTEMPTS',
    retryAfterSeconds: retryAfter,
    error:
      'Trop de tentatives de connexion. Ce compte est bloqué temporairement, réessayez plus tard.',
  });
}

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

/**
 * Nom, e-mail et téléphone du compte : la politique refuse un mot de passe qui
 * reprend ces éléments personnels. Une lecture impossible ne bloque pas la
 * validation, elle la rend seulement moins exigeante.
 */
async function chargerIdentite(userId) {
  try {
    const { rows } = await pool.query(
      `SELECT first_name, last_name, email, phone, email_cipher, phone_cipher
         FROM users WHERE id = $1`,
      [userId],
    );
    const ligne = rows[0];
    if (!ligne) return {};

    // L'identité peut être chiffrée : la politique compare le mot de passe à
    // l'e-mail et au téléphone en clair.
    const contacts = contactsDuCompte(ligne);
    return {
      firstName: ligne.first_name,
      lastName: ligne.last_name,
      email: contacts.email,
      phone: contacts.phone,
    };
  } catch (error) {
    return {};
  }
}

function firstValidationError(req, res) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    res.status(400).json({ errors: errors.array() });
    return true;
  }
  return false;
}


// Récupération de mot de passe sans e-mail ni SMS.
//
// L'identité est prouvée par le code de récupération remis à l'inscription :
// connaître une adresse ne suffit pas à prendre un compte. Le serveur renvoie
// alors un mot de passe temporaire que l'application affiche deux minutes.
router.post('/forgot-password', [
  body('contact').trim().notEmpty().withMessage('Email ou téléphone requis'),
  body('contactType').trim().notEmpty().withMessage('Type de contact requis (email ou phone)'),
  body('recoveryCode').trim().notEmpty().withMessage('Code de récupération requis'),
], async (req, res) => {
  if (firstValidationError(req, res)) return;

  const contactType = String(req.body.contactType).trim().toLowerCase();
  if (!['email', 'phone'].includes(contactType)) {
    return res.status(400).json({ error: 'Type de contact invalide (email ou phone)' });
  }

  const retryAfter = recoveryThrottle.retryAfterSeconds(req);
  if (retryAfter > 0) {
    res.set('Retry-After', String(retryAfter));
    return res.status(429).json({
      code: 'TOO_MANY_ATTEMPTS',
      retryAfterSeconds: retryAfter,
      error:
        'Trop d’essais avec ce code de récupération. Réessayez dans quelques minutes.',
    });
  }

  if (!hashRecoveryCode(req.body.recoveryCode)) {
    return res.status(400).json({
      code: 'RECOVERY_CODE_INVALID',
      error: 'Code de récupération incomplet : 8 caractères attendus.',
    });
  }

  const contact = String(req.body.contact).trim();

  try {
    // Lecture mixte : les comptes hérités sont retrouvés par leur coordonnée en
    // clair, les comptes chiffrés par l'empreinte.
    const empreinte = empreinteContact(contact);
    const userResult = contactType === 'email'
      ? await pool.query(
          `SELECT id, recovery_code_hash FROM users
            WHERE LOWER(email) = $1 OR email_bidx = $2`,
          [normalizeEmail(contact), empreinte],
        )
      : await pool.query(
          `SELECT id, recovery_code_hash FROM users
            WHERE phone = ANY($1::text[]) OR phone_bidx = $2`,
          [getPhoneCandidates(contact), empreinte],
        );

    // Message unique : il ne doit révéler ni l'existence du compte, ni la
    // validité du code.
    const refusal = {
      code: 'RECOVERY_DENIED',
      error: 'Identifiant ou code de récupération incorrect.',
    };

    const user = userResult.rows[0];
    if (
      !user ||
      !matchesRecoveryCodeHash(req.body.recoveryCode, user.recovery_code_hash)
    ) {
      recoveryThrottle.registerFailure(req);
      return res.status(400).json(refusal);
    }

    recoveryThrottle.reset(req);

    // Identité prouvée par le code de récupération : aucun e-mail ni SMS n'est
    // envoyé. Le mot de passe temporaire est haché ici et renvoyé une seule
    // fois à l'application, qui l'affiche deux minutes.
    const temporaryPassword = generateTemporaryPassword();
    const temporaryHash = await hasherMotDePasse(temporaryPassword);
    await pool.query(
      `UPDATE users
          SET password_hash = $1,
              must_change_password = TRUE,
              updated_at = CURRENT_TIMESTAMP
        WHERE id = $2`,
      [temporaryHash, user.id],
    );

    const tempToken = jwt.sign(
      { userId: user.id, type: 'password_reset' },
      getJwtSecret(),
      { expiresIn: '15min' },
    );

    return res.json({
      success: true,
      message:
        'Code de récupération vérifié. Voici votre mot de passe temporaire.',
      temporaryPassword,
      displaySeconds: TEMPORARY_PASSWORD_DISPLAY_SECONDS,
      tempToken,
    });
  } catch (error) {
    return sendAuthError(res, error, '❌ Erreur forgot-password');
  }
});

// Ancienne étape « code reçu par e-mail ou SMS » : supprimée. Une application
// encore à jour reçoit 410 et doit se mettre à jour pour utiliser le code de
// récupération.
router.post('/verify-code', (req, res) => {
  res.status(410).json({
    code: 'CODE_CHANNEL_REMOVED',
    error:
      'Cette étape a été remplacée : mettez l’application à jour et utilisez votre code de récupération.',
  });
});

// Réinitialiser le mot de passe avec le token temporaire.
router.post('/reset-password', [
  body('tempToken').trim().notEmpty().withMessage('Token requis'),
  body('newPassword')
    .isString()
    .withMessage('Nouveau mot de passe requis')
    .notEmpty()
    .withMessage('Nouveau mot de passe requis'),
], async (req, res) => {
  if (firstValidationError(req, res)) return;

  try {
    const decoded = jwt.verify(req.body.tempToken, getJwtSecret());
    if (decoded.type !== 'password_reset') {
      return res.status(401).json({ error: 'Token invalide' });
    }

    const nouveauMotDePasse = String(req.body.newPassword);
    const politique = verifierPolitique(
      nouveauMotDePasse,
      await chargerIdentite(decoded.userId),
    );
    if (!politique.valide) {
      return res.status(400).json({
        code: 'PASSWORD_TOO_WEAK',
        error: politique.message,
        rules: REGLES_MOT_DE_PASSE,
      });
    }

    const hashedPassword = await hasherMotDePasse(nouveauMotDePasse);
    // Le client choisit lui-même son mot de passe : plus rien à remplacer.
    const result = await pool.query(
      `UPDATE users
          SET password_hash = $1,
              must_change_password = FALSE,
              updated_at = CURRENT_TIMESTAMP
        WHERE id = $2
        RETURNING id`,
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

// Remplacer le mot de passe temporaire par un mot de passe choisi.
//
// La session en cours prouve que le client connaît déjà le mot de passe
// temporaire : il n'a donc pas à le ressaisir. La route n'accepte que les
// comptes effectivement marqués comme « mot de passe à remplacer ».
router.post('/change-temporary-password', authMiddleware, [
  body('newPassword')
    .isString()
    .withMessage('Nouveau mot de passe requis')
    .notEmpty()
    .withMessage('Nouveau mot de passe requis'),
], async (req, res) => {
  if (firstValidationError(req, res)) return;

  const userId = req.user.userId;
  const newPassword = String(req.body.newPassword);

  try {
    const found = await pool.query(
      'SELECT id, must_change_password FROM users WHERE id = $1',
      [userId],
    );

    if (found.rows.length === 0) {
      return res.status(404).json({ error: 'Compte introuvable' });
    }

    if (found.rows[0].must_change_password !== true) {
      return res.status(409).json({
        code: 'NO_TEMPORARY_PASSWORD',
        error: 'Aucun mot de passe temporaire à remplacer sur ce compte.',
      });
    }

    const politique = verifierPolitique(newPassword, await chargerIdentite(userId));
    if (!politique.valide) {
      return res.status(400).json({
        code: 'PASSWORD_TOO_WEAK',
        error: politique.message,
        rules: REGLES_MOT_DE_PASSE,
      });
    }

    const hashedPassword = await hasherMotDePasse(newPassword);
    await pool.query(
      `UPDATE users
          SET password_hash = $1,
              must_change_password = FALSE,
              updated_at = CURRENT_TIMESTAMP
        WHERE id = $2`,
      [hashedPassword, userId],
    );

    return res.json({
      success: true,
      message: 'Votre mot de passe est enregistré.',
    });
  } catch (error) {
    return sendAuthError(res, error, '❌ Erreur changement mot de passe temporaire');
  }
});

// Inscription.
router.post('/register', [
  body('firstName').trim().notEmpty().withMessage('Prénom requis'),
  body('lastName').trim().notEmpty().withMessage('Nom requis'),
  body('email').isEmail().withMessage('Email invalide'),
  body('phone').trim().notEmpty().withMessage('Téléphone requis'),
  // La solidité est vérifiée plus bas, avec l'identité : la politique refuse un
  // mot de passe qui reprend le nom, l'e-mail ou le téléphone.
  body('password')
    .isString()
    .withMessage('Mot de passe requis')
    .notEmpty()
    .withMessage('Mot de passe requis'),
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

  const politique = verifierPolitique(password, {
    firstName,
    lastName,
    email,
    phone,
  });
  if (!politique.valide) {
    return res.status(400).json({
      code: 'PASSWORD_TOO_WEAK',
      error: politique.message,
      rules: REGLES_MOT_DE_PASSE,
    });
  }

  try {
    // Unicité contrôlée champ par champ : l'écran peut alors désigner la case à
    // corriger au lieu d'un « email ou téléphone déjà utilisé » ambigu.
    // Empreintes calculées une fois : elles servent au contrôle d'unicité puis
    // à l'écriture. Elles ne sont pas réversibles et ne quittent pas le serveur.
    const emailBidx = empreinteContact(email);
    const phoneBidx = empreinteContact(phone);
    const emailCipher = chiffrerContact(email);
    const phoneCipher = chiffrerContact(phone);

    const [emailExiste, phoneExiste] = await Promise.all([
      pool.query(
        `SELECT id FROM users
          WHERE LOWER(email) = $1 OR email_bidx = $2 LIMIT 1`,
        [email, emailBidx],
      ),
      pool.query(
        `SELECT id FROM users
          WHERE phone = ANY($1::text[]) OR phone_bidx = $2 LIMIT 1`,
        [getPhoneCandidates(phone), phoneBidx],
      ),
    ]);

    const champsPris = [];
    if (emailExiste.rows.length > 0) champsPris.push('email');
    if (phoneExiste.rows.length > 0) champsPris.push('phone');

    if (champsPris.length > 0) {
      const message = champsPris.length === 2
        ? 'Cet e-mail et ce numéro de téléphone sont déjà utilisés.'
        : champsPris[0] === 'email'
          ? 'Cette adresse e-mail est déjà utilisée.'
          : 'Ce numéro de téléphone est déjà utilisé.';

      return res.status(409).json({
        code: 'IDENTIFIER_TAKEN',
        fields: champsPris,
        error: message,
      });
    }

    // Les inscriptions publiques créent toujours des comptes clients.
    // Le compte administrateur est provisionné séparément par la migration.
    const role = 'client';
    const hashedPassword = await hasherMotDePasse(password);

    // Code de récupération : remis une seule fois au client à la création du
    // compte, seule son empreinte est conservée. C'est lui qui remplace l'envoi
    // d'un code par e-mail ou SMS.
    const recoveryCode = generateRecoveryCode();
    const recoveryCodeHash = hashRecoveryCode(recoveryCode);

    // Les coordonnées ne vont plus en clair : les colonnes héritées restent
    // vides, le chiffré sert à l'affichage et l'empreinte à la recherche.
    const result = await pool.query(
      `INSERT INTO users
         (first_name, last_name, email, phone, password_hash, role,
          recovery_code_hash, email_cipher, phone_cipher, email_bidx, phone_bidx)
       VALUES ($1, $2, NULL, NULL, $3, $4, $5, $6, $7, $8, $9)
       RETURNING id, first_name, last_name, role, created_at`,
      [
        firstName,
        lastName,
        hashedPassword,
        role,
        recoveryCodeHash,
        emailCipher,
        phoneCipher,
        emailBidx,
        phoneBidx,
      ],
    );
    const user = result.rows[0];
    const token = jwt.sign(
      // L'e-mail part dans le jeton même s'il n'est pas stocké en clair : il
      // vient de la saisie, pas de la base.
      { userId: user.id, email, role: user.role },
      getJwtSecret(),
      { expiresIn: '30d' },
    );

    return res.status(201).json({
      message: 'Inscription réussie',
      user: {
        id: user.id,
        firstName: user.first_name,
        lastName: user.last_name,
        email,
        phone,
        role: user.role,
        mustChangePassword: false,
      },
      // Affiché une seule fois dans l'application : sans lui, pas de
      // récupération possible sans passer par l'administration.
      recoveryCode,
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

  const retryAfter = loginThrottle.retryAfterSeconds(req);
  if (retryAfter > 0) {
    return refusTropDeTentatives(res, loginThrottle, retryAfter);
  }

  const identifier = normalizeIdentifier(req.body.identifier);
  const password = String(req.body.password);

  try {
    // Lecture mixte : un compte hérité est trouvé par sa coordonnée en clair,
    // un compte chiffré par son empreinte. Les deux requêtes ne renvoient rien
    // de plus que ce que le serveur savait déjà.
    const empreintesTelephone = identifier.phoneCandidates
      .map((candidat) => empreinteContact(candidat))
      .filter((valeur) => valeur !== null);

    const result = await pool.query(
      `SELECT * FROM users
        WHERE LOWER(email) = $1
           OR phone = ANY($2::text[])
           OR email_bidx = $3
           OR phone_bidx = ANY($4::text[])`,
      [
        identifier.email,
        identifier.phoneCandidates,
        empreinteContact(identifier.email),
        empreintesTelephone,
      ],
    );

    if (result.rows.length === 0) {
      // Le compte a peut-être été supprimé : ses coordonnées ont été effacées,
      // seules leurs empreintes subsistent. On répond alors explicitement,
      // plutôt que « identifiant introuvable », qui laisse croire à une faute de
      // frappe le lendemain d'une suppression volontaire.
      const deletedHashes = hashIdentifiers([
        identifier.email,
        ...identifier.phoneCandidates,
      ]);

      const deleted =
        deletedHashes.length === 0
          ? { rows: [] }
          : await pool.query(
              `SELECT id FROM users
                WHERE deleted_at IS NOT NULL
                  AND (deleted_email_hash = ANY($1::text[])
                       OR deleted_phone_hash = ANY($1::text[]))
                LIMIT 1`,
              [deletedHashes],
            );

      if (deleted.rows.length > 0) {
        // Un compte supprimé n'est pas une tentative de devinette de mot de
        // passe : il ne consomme pas le quota de connexion.
        return res.status(403).json({
          code: 'ACCOUNT_DELETED',
          error: 'Ce compte a été supprimé. Vous pouvez en créer un nouveau.',
        });
      }

      loginThrottle.registerFailure(req);
      return res.status(401).json({
        code: 'IDENTIFIER_NOT_FOUND',
        error: 'Email ou téléphone introuvable',
      });
    }

    const user = result.rows[0];

    // Filet de sécurité : un compte marqué supprimé ne doit jamais ouvrir de
    // session, quelle que soit la façon dont il a été retrouvé.
    if (user.deleted_at) {
      return res.status(403).json({
        code: 'ACCOUNT_DELETED',
        error: 'Ce compte a été supprimé. Vous pouvez en créer un nouveau.',
      });
    }

    if (
      !user.password_hash ||
      !(await verifierHachage(password, user.password_hash))
    ) {
      loginThrottle.registerFailure(req);
      // Le message ne révèle pas le nombre d'essais restants, mais prévient
      // qu'un blocage vient de tomber.
      const bloque = loginThrottle.retryAfterSeconds(req) > 0;
      return res.status(401).json({
        code: 'INVALID_PASSWORD',
        error: bloque
          ? 'Mot de passe incorrect. Ce compte est désormais bloqué 24 heures.'
          : 'Mot de passe incorrect',
      });
    }

    loginThrottle.reset(req);

    // Hachage hérité : réécrit au format courant dès la première connexion
    // réussie. Le mot de passe lui-même n'est pas modifié, la personne ne voit
    // rien et garde ses coordonnées intactes.
    if (hachageARenforcer(user.password_hash)) {
      try {
        await pool.query(
          `UPDATE users
              SET password_hash = $1, updated_at = CURRENT_TIMESTAMP
            WHERE id = $2`,
          [await hasherMotDePasse(password), user.id],
        );
      } catch (error) {
        console.error('Renforcement du hachage:', error.message);
      }
    }

    // Coordonnées relues selon leur forme de stockage : clair pour un compte
    // hérité, déchiffrées pour un compte récent.
    const contacts = contactsDuCompte(user);

    const token = jwt.sign(
      { userId: user.id, email: contacts.email, role: user.role },
      getJwtSecret(),
      { expiresIn: '30d' },
    );

    return res.json({
      message: 'Connexion réussie',
      user: {
        id: user.id,
        firstName: user.first_name,
        lastName: user.last_name,
        email: contacts.email,
        phone: contacts.phone,
        role: user.role,
        // Vrai après une récupération : l'application impose alors de choisir
        // un mot de passe définitif.
        mustChangePassword: user.must_change_password === true,
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
      `SELECT id, first_name, last_name, email, phone, email_cipher,
              phone_cipher, role, created_at, must_change_password
         FROM users WHERE id = $1`,
      [req.user.userId],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Utilisateur non trouvé' });
    }

    const user = result.rows[0];
    const contacts = contactsDuCompte(user);
    return res.json({
      id: user.id,
      firstName: user.first_name,
      lastName: user.last_name,
      email: contacts.email,
      phone: contacts.phone,
      role: user.role,
      createdAt: user.created_at,
      mustChangePassword: user.must_change_password === true,
    });
  } catch (error) {
    return sendAuthError(res, error, '❌ Erreur profil');
  }
});

// Suppression du compte par son titulaire — exigence Google Play.
//
// Le compte est anonymisé plutôt que supprimé de la base : les pièces
// commerciales (locations, devis) restent nécessaires à la comptabilité de
// l’entreprise, mais plus aucune donnée personnelle n’y est rattachée. Les
// contenus propres au client (messages de support, centres d’intérêt, note de
// l’application, code de réinitialisation) sont réellement effacés.
//
// Le mot de passe est exigé : la suppression ne doit pas pouvoir être déclenchée
// depuis un téléphone laissé ouvert.
router.delete(
  '/account',
  authMiddleware,
  [body('password').notEmpty().withMessage('Mot de passe requis pour confirmer')],
  async (req, res) => {
    if (firstValidationError(req, res)) return;

    const userId = req.user.userId;
    const password = String(req.body.password);

    let client;
    try {
      client = await pool.connect();
    } catch (error) {
      console.error('❌ Erreur connexion base (suppression):', error);
      return res
        .status(503)
        .json({ error: 'Service indisponible. Réessayez plus tard.' });
    }

    try {
      await client.query('BEGIN');

      // email et phone sont lus avant neutralisation : leurs empreintes servent
      // ensuite à reconnaître la personne si elle retente une connexion.
      const found = await client.query(
        `SELECT id, role, password_hash, email, phone, email_cipher, phone_cipher
           FROM users WHERE id = $1 FOR UPDATE`,
        [userId],
      );

      if (found.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Compte introuvable' });
      }

      const user = found.rows[0];

      // Le compte d’administration est provisionné par la migration : le
      // supprimer depuis l’application couperait la gestion de la boutique.
      if (user.role === 'admin') {
        await client.query('ROLLBACK');
        return res.status(403).json({
          error: 'Le compte administrateur ne peut pas être supprimé depuis l’application',
        });
      }

      if (
        !user.password_hash ||
        !(await verifierHachage(password, user.password_hash))
      ) {
        await client.query('ROLLBACK');
        return res.status(401).json({
          code: 'INVALID_PASSWORD',
          error: 'Mot de passe incorrect',
        });
      }

      // Contenus personnels : effacement définitif.
      await client.query('DELETE FROM profile_support_messages WHERE user_id = $1', [
        userId,
      ]);
      await client.query(
        'DELETE FROM profile_training_interests WHERE user_id = $1',
        [userId],
      );
      await client.query('DELETE FROM profile_app_ratings WHERE user_id = $1', [
        userId,
      ]);
      await client.query('DELETE FROM password_reset_codes WHERE user_id = $1', [
        userId,
      ]);
      await client.query('DELETE FROM clients WHERE user_id = $1', [userId]);

      // Devis : la trace commerciale demeure, les coordonnées disparaissent.
      await client.query(
        `UPDATE devis
            SET nom = 'Compte supprimé', telephone = NULL, email = NULL,
                updated_at = CURRENT_TIMESTAMP
          WHERE user_id = $1`,
        [userId],
      );

      // Compte : identité remplacée par des valeurs neutres, mot de passe rendu
      // inutilisable, e-mail et téléphone libérés pour une future inscription.
      // Seules leurs empreintes restent, pour répondre « compte supprimé ».
      const neutralHash = await hasherMotDePasse(crypto.randomUUID());
      // Coordonnées relues puis effacées, chiffré compris : après suppression,
      // plus aucune adresse ni numéro, en clair ou illisible, ne subsiste.
      const contacts = contactsDuCompte(user);
      const deletedEmailHash = hashIdentifiers([contacts.email])[0] || null;
      const deletedPhoneHash = hashIdentifiers([contacts.phone])[0] || null;
      await client.query(
        `UPDATE users
            SET first_name = 'Compte',
                last_name = 'supprimé',
                email = $2,
                phone = $3,
                password_hash = $4,
                is_active = FALSE,
                deleted_at = CURRENT_TIMESTAMP,
                deleted_email_hash = $5,
                deleted_phone_hash = $6,
                email_cipher = NULL,
                phone_cipher = NULL,
                email_bidx = NULL,
                phone_bidx = NULL,
                avatar_data = NULL,
                avatar_mime_type = NULL,
                updated_at = CURRENT_TIMESTAMP
          WHERE id = $1`,
        [
          userId,
          `supprime+${userId}@echelle-eg39.invalid`,
          `+00000${userId}`,
          neutralHash,
          deletedEmailHash,
          deletedPhoneHash,
        ],
      );

      await client.query('COMMIT');

      // Le jeton utilisé pour cette requête (et ceux des autres appareils)
      // cesse d'être accepté dès maintenant.
      revokeAccount(userId, 'deleted');

      return res.json({
        success: true,
        message: 'Votre compte a été supprimé.',
      });
    } catch (error) {
      try {
        await client.query('ROLLBACK');
      } catch (_) {
        // La transaction est peut-être déjà fermée : l’erreur d’origine prime.
      }
      return sendAuthError(res, error, '❌ Erreur suppression de compte');
    } finally {
      client.release();
    }
  },
);

module.exports = router;
