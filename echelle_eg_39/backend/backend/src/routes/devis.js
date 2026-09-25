const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const pool = require('../config/database');
const { authMiddleware, adminMiddleware, optionalAuthMiddleware } = require('../middleware/auth');
const { normalizePhone } = require('../utils/identifiers');

const DEVIS_STATUSES = [
  'en_attente',
  'approuvee',
  'rejetee',
  'en_cours',
  'envoye',
  'termine',
];

// Transitions autorisées : clé = statut courant, valeur = statuts atteignables.
// termines et rejetee sont définitifs.
const DEVIS_TRANSITIONS = {
  en_attente: ['approuvee', 'rejetee'],
  approuvee: ['en_cours', 'envoye', 'termine'],
  en_cours: ['envoye', 'termine'],
  envoye: ['termine'],
  termine: [],
  rejetee: [],
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
    clientEmail: devis.client_email,
    clientNom: devis.client_first_name
      ? `${devis.client_first_name} ${devis.client_last_name}`.trim()
      : null,
    serviceId: devis.service_id,
    serviceName: devis.service_name,
    description: devis.description,
    nom: devis.nom,
    telephone: devis.telephone,
    email: devis.email,
    statut: devis.statut,
    commentaireAdmin: devis.commentaire_admin,
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

function allowedTransitions(statut) {
  return DEVIS_TRANSITIONS[statut] ?? [];
}

// Applique une transition de statut en respectant DEVIS_TRANSITIONS.
// Retourne { error, status } en cas de refus, sinon null.
async function transitionStatut(devisId, nextStatut, commentaire) {
  const existing = await pool.query(
    'SELECT id, statut FROM devis WHERE id = $1',
    [devisId],
  );

  if (existing.rows.length === 0) {
    return { status: 404, error: 'Devis non trouvé' };
  }

  const currentStatut = existing.rows[0].statut;
  if (currentStatut === nextStatut) {
    return { status: 400, error: `Le devis est déjà au statut « ${nextStatut} »` };
  }

  const allowed = allowedTransitions(currentStatut);
  if (!allowed.includes(nextStatut)) {
    return {
      status: 400,
      error: allowed.length
        ? `Transition impossible depuis « ${currentStatut} ». Statuts autorisés : ${allowed.join(', ')}.`
        : `Transition impossible depuis « ${currentStatut} » : ce devis est clôturé.`,
    };
  }

  const result = await pool.query(
    `UPDATE devis
     SET statut = $1,
         commentaire_admin = COALESCE(NULLIF($2, ''), commentaire_admin),
         updated_at = CURRENT_TIMESTAMP
     WHERE id = $3 AND statut = $4
     RETURNING id`,
    [nextStatut, commentaire || '', devisId, currentStatut],
  );

  if (result.rows.length === 0) {
    return {
      status: 409,
      error: 'Ce devis a été modifié entre-temps. Actualisez la liste.',
    };
  }

  const updated = await pool.query(`${SELECT_DEVIS} WHERE d.id = $1`, [devisId]);
  return { devis: updated.rows[0] };
}

// Soumettre une demande de devis.
// La route reste publique : si un jeton valide est fourni, le devis est rattaché au compte.
router.post('/', optionalAuthMiddleware, [
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
    const userId = req.user?.userId ?? null;
    const normalizedTelephone = normalizePhone(telephone) || null;

    const result = await pool.query(
      `INSERT INTO devis (
        user_id,
        service_id,
        service_name,
        description,
        nom,
        telephone,
        email,
        statut,
        created_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, 'en_attente', CURRENT_TIMESTAMP)
      RETURNING *`,
      [
        userId,
        serviceId || null,
        serviceName || null,
        description || null,
        nom,
        normalizedTelephone,
        email || null,
      ],
    );

    return res.status(201).json({
      message: 'Demande de devis soumise avec succès',
      devis: mapDevis(result.rows[0]),
      lieAuCompte: Boolean(userId),
    });
  } catch (error) {
    console.error('Erreur soumission devis:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Lister les demandes de devis (admin seulement).
router.get('/', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { statut } = req.query;
    const params = [];
    let query = SELECT_DEVIS;

    const statuts = String(statut || '')
      .split(',')
      .map((value) => value.trim())
      .filter(Boolean);

    if (statuts.length > 0) {
      const invalides = statuts.filter((value) => !DEVIS_STATUSES.includes(value));
      if (invalides.length > 0) {
        return res.status(400).json({ error: `Statut invalide : ${invalides.join(', ')}` });
      }

      params.push(statuts);
      query += ` WHERE d.statut = ANY($${params.length}::varchar[])`;
    }

    query += ' ORDER BY d.created_at DESC';

    const result = await pool.query(query, params);
    return res.json({ devis: result.rows.map(mapDevis) });
  } catch (error) {
    console.error('Erreur liste devis:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Lister les devis rattachés au compte connecté.
router.get('/me', authMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      `${SELECT_DEVIS} WHERE d.user_id = $1 ORDER BY d.created_at DESC`,
      [req.user.userId],
    );
    return res.json({ devis: result.rows.map(mapDevis) });
  } catch (error) {
    console.error('Erreur liste devis du client:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Approuver une demande de devis (admin).
router.patch('/:id/approuver', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const outcome = await transitionStatut(req.params.id, 'approuvee', '');
    if (outcome.error) {
      return res.status(outcome.status).json({ error: outcome.error });
    }

    return res.json({
      message: 'Demande de devis approuvée',
      devis: mapDevis(outcome.devis),
    });
  } catch (error) {
    console.error('Erreur approbation devis:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Rejeter une demande de devis (admin).
router.patch('/:id/rejeter', authMiddleware, adminMiddleware, [
  body('raison').optional().trim().isLength({ max: 1000 }).withMessage('Motif trop long'),
], async (req, res) => {
  if (sendValidationErrors(req, res)) return;

  try {
    const raison = String(req.body.raison || '').trim() || 'Demande rejetée';
    const outcome = await transitionStatut(req.params.id, 'rejetee', raison);
    if (outcome.error) {
      return res.status(outcome.status).json({ error: outcome.error });
    }

    return res.json({
      message: 'Demande de devis rejetée',
      devis: mapDevis(outcome.devis),
    });
  } catch (error) {
    console.error('Erreur rejet devis:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Modifier le statut d'un devis dans le suivi administratif (admin).
router.patch('/:id/statut', authMiddleware, adminMiddleware, [
  body('statut').isIn(DEVIS_STATUSES).withMessage('Statut invalide'),
  body('commentaire').optional().trim(),
  body('commentaire_admin').optional().trim(),
], async (req, res) => {
  if (sendValidationErrors(req, res)) return;

  try {
    const { statut } = req.body;
    const commentaire = String(
      req.body.commentaire ?? req.body.commentaire_admin ?? '',
    ).trim();

    const outcome = await transitionStatut(req.params.id, statut, commentaire);
    if (outcome.error) {
      return res.status(outcome.status).json({ error: outcome.error });
    }

    return res.json({
      message: 'Statut du devis mis à jour',
      devis: mapDevis(outcome.devis),
    });
  } catch (error) {
    console.error('Erreur mise à jour devis:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Supprimer un devis (admin seulement).
router.delete('/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      'DELETE FROM devis WHERE id = $1 RETURNING id',
      [req.params.id],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Devis non trouvé' });
    }

    return res.json({ message: 'Devis supprimé' });
  } catch (error) {
    console.error('Erreur suppression devis:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

module.exports = router;
