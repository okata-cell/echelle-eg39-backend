const express = require('express');
const { body, param, validationResult } = require('express-validator');
const pool = require('../config/database');
const { authMiddleware, adminMiddleware } = require('../middleware/auth');
const { normalizePhone } = require('../utils/identifiers');

const router = express.Router();

// Les anciennes valeurs restent lisibles pour préserver l'historique.
const DEVIS_STATUSES = [
  'en_attente',
  'en_traitement',
  'approuvee',
  'rejetee',
  'en_cours',
  'envoye',
  'acceptee',
  'refusee',
  'termine',
];
const ADMIN_MANAGED_STATUSES = ['en_traitement', 'en_cours', 'termine'];
const DEVIS_TRANSITIONS = {
  en_attente: ['en_traitement'],
  en_traitement: [],
  approuvee: ['en_cours', 'termine'],
  rejetee: [],
  en_cours: ['termine'],
  // Les anciennes offres gardent leurs transitions historiques possibles.
  envoye: ['en_cours', 'termine'],
  acceptee: ['en_cours', 'termine'],
  refusee: [],
  termine: [],
};

const SELECT_DEVIS = `
  SELECT d.*,
         u.email AS client_email,
         u.first_name AS client_first_name,
         u.last_name AS client_last_name
    FROM devis d
    LEFT JOIN users u ON u.id = d.user_id
`;

function mapDevis(devis) {
  return {
    id: devis.id,
    userId: devis.user_id,
    clientEmail: devis.client_email ?? null,
    clientNom: devis.client_first_name
      ? `${devis.client_first_name} ${devis.client_last_name || ''}`.trim()
      : null,
    serviceId: devis.service_id,
    serviceName: devis.service_name,
    description: devis.description,
    nom: devis.nom,
    telephone: devis.telephone,
    email: devis.email,
    statut: devis.statut,
    commentaireAdmin: devis.commentaire_admin ?? null,
    montant: devis.montant ?? null,
    createdAt: devis.created_at,
    updatedAt: devis.updated_at,
  };
}

function sendValidationErrors(req, res) {
  const errors = validationResult(req);
  if (errors.isEmpty()) return false;

  res.status(400).json({ errors: errors.array() });
  return true;
}

function clientMiddleware(req, res, next) {
  if (req.user.role !== 'client') {
    return res.status(403).json({ error: 'Action réservée aux clients' });
  }
  return next();
}

function allowedTransitions(statut) {
  return DEVIS_TRANSITIONS[statut] ?? [];
}

async function transitionStatut(devisId, nextStatut, commentaire) {
  const existing = await pool.query(
    'SELECT id, statut FROM devis WHERE id = $1',
    [devisId],
  );

  if (existing.rows.length === 0) {
    return { status: 404, error: 'Devis non trouvé' };
  }

  const currentStatut = existing.rows[0].statut;
  if (!allowedTransitions(currentStatut).includes(nextStatut)) {
    return {
      status: 409,
      error: 'Cette demande ne peut pas recevoir cette mise à jour de suivi.',
    };
  }

  const updated = await pool.query(
    `UPDATE devis
        SET statut = $1,
            commentaire_admin = COALESCE(NULLIF($2, ''), commentaire_admin),
            updated_at = CURRENT_TIMESTAMP
      WHERE id = $3 AND statut = $4
      RETURNING *`,
    [nextStatut, commentaire || '', devisId, currentStatut],
  );

  if (updated.rows.length === 0) {
    return {
      status: 409,
      error: 'Cette demande vient d’être modifiée. Actualisez la liste.',
    };
  }

  return { devis: updated.rows[0] };
}

async function pendingRequestError(devisId) {
  const existing = await pool.query(
    'SELECT id, user_id, statut FROM devis WHERE id = $1',
    [devisId],
  );
  if (existing.rows.length === 0) {
    return { status: 404, error: 'Demande de devis non trouvée' };
  }
  if (existing.rows[0].user_id == null) {
    return {
      status: 409,
      error: 'Cette demande n’est pas liée à un compte client.',
    };
  }
  if (existing.rows[0].statut === 'en_attente') {
    return {
      status: 409,
      error: 'Placez la demande en examen avant de rendre une décision.',
    };
  }
  if (existing.rows[0].statut !== 'en_traitement') {
    return {
      status: 409,
      error: 'Cette demande a déjà reçu une décision. Actualisez la liste.',
    };
  }
  return {
    status: 409,
    error: 'Cette demande a déjà été traitée. Actualisez la liste.',
  };
}

// Le bouton Envoyer du client crée une demande liée à son compte authentifié.
router.post('/', authMiddleware, clientMiddleware, [
  body('serviceId').optional().isString(),
  body('serviceName').optional().isString(),
  body('description').optional().isString(),
  body('nom').trim().notEmpty().withMessage('Le nom est requis'),
  body('telephone').optional().isString(),
  body('email')
    .trim()
    .optional({ checkFalsy: true })
    .isEmail()
    .withMessage('Email invalide'),
], async (req, res) => {
  if (sendValidationErrors(req, res)) return;

  try {
    const { serviceId, serviceName, description, nom, telephone, email } = req.body;
    const result = await pool.query(
      `INSERT INTO devis (
         user_id, service_id, service_name, description,
         nom, telephone, email, statut, created_at
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7, 'en_attente', CURRENT_TIMESTAMP)
       RETURNING *`,
      [
        req.user.userId,
        serviceId || null,
        serviceName || null,
        description || null,
        nom,
        normalizePhone(telephone) || null,
        email || null,
      ],
    );

    return res.status(201).json({
      message: 'Demande de devis soumise avec succès',
      devis: mapDevis(result.rows[0]),
      lieAuCompte: true,
    });
  } catch (error) {
    console.error('Erreur soumission devis:', error.name || 'Erreur inconnue');
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Lister les demandes de devis (administration uniquement).
router.get('/', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const statuts = String(req.query.statut || '')
      .split(',')
      .map((value) => value.trim())
      .filter(Boolean);

    if (statuts.some((statut) => !DEVIS_STATUSES.includes(statut))) {
      return res.status(400).json({ error: 'Un ou plusieurs statuts sont invalides.' });
    }

    const params = [];
    let query = SELECT_DEVIS;
    if (statuts.length > 0) {
      params.push(statuts);
      query += ' WHERE d.statut = ANY($1::varchar[])';
    }
    query += ' ORDER BY d.created_at DESC';

    const result = await pool.query(query, params);
    res.set('Cache-Control', 'private, no-store');
    return res.json({ devis: result.rows.map(mapDevis) });
  } catch (error) {
    console.error('Erreur liste devis:', error.name || 'Erreur inconnue');
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Lister uniquement les demandes associées au compte connecté.
router.get('/me', authMiddleware, clientMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      `${SELECT_DEVIS} WHERE d.user_id = $1 ORDER BY d.created_at DESC`,
      [req.user.userId],
    );
    res.set('Cache-Control', 'private, no-store');
    return res.json({ devis: result.rows.map(mapDevis) });
  } catch (error) {
    console.error('Erreur liste devis du client:', error.name || 'Erreur inconnue');
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Le client peut retirer uniquement une demande refusée ou terminée.
router.delete('/me/:id', authMiddleware, clientMiddleware, [
  param('id').isInt({ min: 1 }).withMessage('Identifiant invalide'),
], async (req, res) => {
  if (sendValidationErrors(req, res)) return;

  try {
    const deleted = await pool.query(
      `DELETE FROM devis
        WHERE id = $1 AND user_id = $2 AND statut IN ('rejetee', 'termine')
        RETURNING id`,
      [req.params.id, req.user.userId],
    );
    if (deleted.rows.length > 0) {
      return res.json({ message: 'Demande de devis supprimée.' });
    }

    const owned = await pool.query(
      'SELECT statut FROM devis WHERE id = $1 AND user_id = $2',
      [req.params.id, req.user.userId],
    );
    if (owned.rows.length === 0) {
      return res.status(404).json({ error: 'Devis non trouvé.' });
    }
    return res.status(409).json({
      error: 'Cette demande ne peut être supprimée qu’après un refus ou la fin du suivi.',
    });
  } catch (error) {
    console.error('Erreur suppression devis client:', error.name || 'Erreur inconnue');
    return res.status(500).json({ error: 'Impossible de supprimer cette demande.' });
  }
});

// Approuver une demande en examen et communiquer le montant au client.
router.patch('/:id/approuver', authMiddleware, adminMiddleware, [
  param('id').isInt({ min: 1 }).withMessage('Identifiant invalide'),
  body('montant')
    .isInt({ min: 1, max: Number.MAX_SAFE_INTEGER })
    .toInt()
    .withMessage('Le montant doit être un entier positif en FCFA.'),
], async (req, res) => {
  if (sendValidationErrors(req, res)) return;

  try {
    const updated = await pool.query(
      `UPDATE devis
          SET statut = 'approuvee', montant = $1, updated_at = CURRENT_TIMESTAMP
        WHERE id = $2 AND statut = 'en_traitement' AND user_id IS NOT NULL
        RETURNING *`,
      [req.body.montant, req.params.id],
    );

    if (updated.rows.length === 0) {
      const issue = await pendingRequestError(req.params.id);
      return res.status(issue.status).json({ error: issue.error });
    }

    res.set('Cache-Control', 'private, no-store');
    return res.json({
      message: 'Devis approuvé et montant communiqué au client.',
      devis: mapDevis(updated.rows[0]),
    });
  } catch (error) {
    console.error('Erreur approbation devis:', error.name || 'Erreur inconnue');
    return res.status(500).json({ error: 'Impossible d’approuver le devis.' });
  }
});

// Rejeter une demande avec un motif obligatoire visible dans Mes devis.
router.patch('/:id/rejeter', authMiddleware, adminMiddleware, [
  param('id').isInt({ min: 1 }).withMessage('Identifiant invalide'),
  body('raison')
    .exists()
    .withMessage('Le motif du rejet est obligatoire.')
    .bail()
    .isString()
    .withMessage('Le motif doit être du texte.')
    .bail()
    .trim()
    .notEmpty()
    .withMessage('Le motif du rejet est obligatoire.')
    .isLength({ max: 1000 })
    .withMessage('Le motif ne peut pas dépasser 1000 caractères.'),
], async (req, res) => {
  if (sendValidationErrors(req, res)) return;

  try {
    const updated = await pool.query(
      `UPDATE devis
          SET statut = 'rejetee', commentaire_admin = $1,
              updated_at = CURRENT_TIMESTAMP
        WHERE id = $2 AND statut = 'en_traitement' AND user_id IS NOT NULL
        RETURNING *`,
      [req.body.raison, req.params.id],
    );

    if (updated.rows.length === 0) {
      const issue = await pendingRequestError(req.params.id);
      return res.status(issue.status).json({ error: issue.error });
    }

    res.set('Cache-Control', 'private, no-store');
    return res.json({
      message: 'Demande rejetée. Le motif a été communiqué au client.',
      devis: mapDevis(updated.rows[0]),
    });
  } catch (error) {
    console.error('Erreur rejet devis:', error.name || 'Erreur inconnue');
    return res.status(500).json({ error: 'Impossible de rejeter le devis.' });
  }
});

// Modifier le suivi après approbation. Les décisions initiales passent
// exclusivement par /approuver (avec montant) ou /rejeter (avec motif).
router.patch('/:id/statut', authMiddleware, adminMiddleware, [
  param('id').isInt({ min: 1 }).withMessage('Identifiant invalide'),
  body('statut')
    .isIn(ADMIN_MANAGED_STATUSES)
    .withMessage('Utilisez les actions approuver ou rejeter pour une demande en attente.'),
  body('commentaire').optional().trim().isLength({ max: 1000 }),
  body('commentaire_admin').optional().trim().isLength({ max: 1000 }),
], async (req, res) => {
  if (sendValidationErrors(req, res)) return;

  try {
    const commentaire = String(
      req.body.commentaire ?? req.body.commentaire_admin ?? '',
    ).trim();
    const outcome = await transitionStatut(
      req.params.id,
      req.body.statut,
      commentaire,
    );
    if (outcome.error) {
      return res.status(outcome.status).json({ error: outcome.error });
    }

    return res.json({
      message: 'Suivi du devis mis à jour.',
      devis: mapDevis(outcome.devis),
    });
  } catch (error) {
    console.error('Erreur mise à jour devis:', error.name || 'Erreur inconnue');
    return res.status(500).json({ error: 'Impossible de mettre à jour le suivi.' });
  }
});

// Supprimer une demande. Les colonnes de stockage historique ne sont pas
// modifiées par ce workflow simplifié.
router.delete('/:id', authMiddleware, adminMiddleware, [
  param('id').isInt({ min: 1 }).withMessage('Identifiant invalide'),
], async (req, res) => {
  if (sendValidationErrors(req, res)) return;

  try {
    const result = await pool.query(
      'DELETE FROM devis WHERE id = $1 RETURNING id',
      [req.params.id],
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Devis non trouvé' });
    }
    return res.json({ message: 'Devis supprimé.' });
  } catch (error) {
    console.error('Erreur suppression devis:', error.name || 'Erreur inconnue');
    return res.status(500).json({ error: 'Impossible de supprimer le devis.' });
  }
});

module.exports = router;
