const express = require('express');
const router = express.Router();
const { body, param, validationResult } = require('express-validator');
const pool = require('../config/database');
const { authMiddleware, adminMiddleware } = require('../middleware/auth');
const { normalizePhone } = require('../utils/identifiers');

const DEVIS_STATUSES = [
  'en_attente',
  'approuvee',
  'rejetee',
  'en_cours',
  'envoye',
  'acceptee',
  'refusee',
  'termine',
];
const ADMIN_MANAGED_STATUSES = [
  'en_attente',
  'approuvee',
  'rejetee',
  'en_cours',
  'termine',
];
const CLIENT_DECISIONS = ['acceptee', 'refusee'];

// Transitions autorisées : clé = statut courant, valeur = statuts atteignables.
// termines et rejetee sont définitifs.
const DEVIS_TRANSITIONS = {
  en_attente: ['approuvee', 'rejetee'],
  approuvee: ['en_cours', 'envoye', 'termine'],
  en_cours: ['envoye', 'termine'],
  envoye: ['termine'],
  acceptee: ['en_cours', 'termine'],
  refusee: [],
  termine: [],
  rejetee: [],
};

const SELECT_DEVIS = `
  SELECT d.*,
         u.email AS client_email,
         u.first_name AS client_first_name,
         u.last_name AS client_last_name,
         CASE
           WHEN d.date_validite IS NOT NULL
             AND d.date_validite < (CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Lome')::date
           THEN TRUE ELSE FALSE
         END AS offre_expiree
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
    montant: devis.montant,
    dateValidite: toDateOnly(devis.date_validite),
    documentUrl: devis.document_url,
    offreEmiseAt: devis.offre_emise_at,
    clientReponduAt: devis.client_repondu_at,
    offreExpiree: devis.offre_expiree === true,
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

function clientMiddleware(req, res, next) {
  if (req.user.role !== 'client') {
    return res.status(403).json({ error: 'Action réservée aux clients' });
  }
  return next();
}

function isValidDateOnly(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = new Date(`${value}T00:00:00.000Z`);
  return !Number.isNaN(parsed.getTime()) && parsed.toISOString().slice(0, 10) === value;
}

function toDateOnly(value) {
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return `${value.getFullYear()}-${String(value.getMonth() + 1).padStart(2, '0')}-${String(value.getDate()).padStart(2, '0')}`;
  }
  const text = value?.toString() ?? '';
  const match = text.match(/^(\d{4}-\d{2}-\d{2})/);
  return match ? match[1] : value ?? null;
}

function businessToday() {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Africa/Lome', year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(new Date());
  const values = Object.fromEntries(parts.map(({ type, value }) => [type, value]));
  return `${values.year}-${values.month}-${values.day}`;
}

function isValidHttpsDocument(value) {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && Boolean(url.hostname) && !url.username && !url.password;
  } catch (_) {
    return false;
  }
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

// Soumettre une demande de devis : un compte client est obligatoire.
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

// Émettre une offre chiffrée avec un PDF hébergé sur un stockage durable externe.
router.patch('/:id/offre', authMiddleware, adminMiddleware, [
  param('id').isInt({ min: 1 }).withMessage('Identifiant invalide'),
  body('montant')
    .isInt({ min: 1, max: Number.MAX_SAFE_INTEGER })
    .toInt()
    .withMessage('Le montant doit être un entier positif en FCFA'),
  body('dateValidite')
    .custom(isValidDateOnly)
    .withMessage('La date de validité doit être au format AAAA-MM-JJ'),
  body('documentUrl')
    .trim()
    .isLength({ min: 1, max: 2048 })
    .custom(isValidHttpsDocument)
    .withMessage('Le document doit être accessible via une URL HTTPS valide'),
  body('commentaireAdmin').optional().trim().isLength({ max: 1000 }),
], async (req, res) => {
  if (sendValidationErrors(req, res)) return;

  const { montant, dateValidite, documentUrl } = req.body;
  if (dateValidite < businessToday()) {
    return res.status(400).json({ error: 'La date de validité ne peut pas être passée' });
  }

  try {
    const updated = await pool.query(
      `UPDATE devis
       SET statut = 'envoye', montant = $1, date_validite = $2::date,
           document_url = $3, offre_emise_at = CURRENT_TIMESTAMP,
           client_repondu_at = NULL,
           commentaire_admin = COALESCE(NULLIF($5, ''), commentaire_admin),
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $4 AND user_id IS NOT NULL
         AND $2::date >= (CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Lome')::date
         AND (statut IN ('en_attente', 'approuvee')
              OR (statut = 'envoye' AND client_repondu_at IS NULL))
       RETURNING id`,
      [montant, dateValidite, documentUrl, req.params.id, req.body.commentaireAdmin || ''],
    );

    if (updated.rows.length === 0) {
      const existing = await pool.query(
        'SELECT id, user_id, statut, client_repondu_at FROM devis WHERE id = $1',
        [req.params.id],
      );
      if (existing.rows.length === 0) {
        return res.status(404).json({ error: 'Demande de devis non trouvée' });
      }
      const devis = existing.rows[0];
      if (devis.user_id == null) {
        return res.status(409).json({ error: 'Cette demande n’est pas liée à un compte client' });
      }
      if (devis.statut === 'envoye' && devis.client_repondu_at != null) {
        return res.status(409).json({ error: 'Le client a déjà répondu à cette offre' });
      }
      return res.status(409).json({ error: 'Cette demande ne peut plus recevoir d’offre' });
    }

    const result = await pool.query(`${SELECT_DEVIS} WHERE d.id = $1`, [req.params.id]);
    return res.json({
      message: 'Offre de devis envoyée au client',
      devis: mapDevis(result.rows[0]),
    });
  } catch (error) {
    console.error('Erreur émission devis:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Répondre à une offre reçue : seule la personne propriétaire peut décider.
router.patch('/:id/reponse', authMiddleware, clientMiddleware, [
  param('id').isInt({ min: 1 }).withMessage('Identifiant invalide'),
  body('decision').isIn(CLIENT_DECISIONS).withMessage('Décision invalide'),
], async (req, res) => {
  if (sendValidationErrors(req, res)) return;

  try {
    const { decision } = req.body;
    const updated = await pool.query(
      `UPDATE devis
       SET statut = $1, client_repondu_at = CURRENT_TIMESTAMP,
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $2 AND user_id = $3 AND statut = 'envoye'
         AND date_validite >= (CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Lome')::date
       RETURNING id`,
      [decision, req.params.id, req.user.userId],
    );

    if (updated.rows.length === 0) {
      const existing = await pool.query(
        'SELECT user_id, statut, date_validite FROM devis WHERE id = $1',
        [req.params.id],
      );
      if (existing.rows.length === 0 || String(existing.rows[0].user_id) !== String(req.user.userId)) {
        return res.status(404).json({ error: 'Offre de devis non trouvée' });
      }
      const devis = existing.rows[0];
      if (!devis.date_validite || toDateOnly(devis.date_validite) < businessToday()) {
        return res.status(409).json({ error: 'La validité de cette offre est expirée' });
      }
      return res.status(409).json({ error: 'Cette offre a déjà reçu une réponse ou n’est plus active' });
    }

    const result = await pool.query(`${SELECT_DEVIS} WHERE d.id = $1`, [req.params.id]);
    return res.json({
      message: decision === 'acceptee' ? 'Devis accepté' : 'Devis refusé',
      devis: mapDevis(result.rows[0]),
    });
  } catch (error) {
    console.error('Erreur réponse client au devis:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Approuver une demande de devis (ancien client API, conservé pour compatibilité).
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
  body('statut').isIn(ADMIN_MANAGED_STATUSES).withMessage('Statut invalide'),
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
