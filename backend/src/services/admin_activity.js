/**
 * Journal d'activité destiné à l'espace administrateur.
 *
 * Aucune passerelle externe n'est utilisée : chaque demande client déposée par
 * `POST /api/locations`, `/api/demandes` ou `/api/devis` laisse une ligne dans
 * `admin_events`. Les écrans admin ouverts sont prévenus immédiatement par le
 * flux SSE, et ceux qui étaient fermés ou hors réseau rattrapent au retour avec
 * `listActivity({ since })`.
 *
 * L'écriture est volontairement non bloquante : un journal indisponible ne doit
 * jamais faire échouer la demande d'un client.
 */
const pool = require('../config/database');

/** Connexions SSE ouvertes, tenues en mémoire du processus. */
const listeners = new Set();

const HEARTBEAT_MS = 25000;
const RETENTION_JOURS = 30;

/**
 * États pour lesquels la demande liée est close : sa ligne du journal peut être
 * retirée. Un rejet reste volontairement protégé, il documente la décision de
 * l'atelier ; tout ce qui est en attente, approuvé sans être livré, en cours ou
 * en retard est refusé.
 */
const STATUTS_CLOS = {
  location: new Set(['termine', 'annulee']),
  vente: new Set(['livree', 'termine']),
  devis: new Set(['termine']),
};

/** Tables métier derrière chaque module du journal. */
const TABLES_DEMANDES = {
  location: 'locations',
  vente: 'demandes_achat',
  devis: 'devis',
};

/** `location:12` → `{ kind: 'location', id: 12 }`, sinon null. */
function cleDemande(eventKey) {
  const [kind, valeur] = String(eventKey ?? '').split(':');
  if (!TABLES_DEMANDES[kind]) return null;

  const id = Number(valeur);
  if (!Number.isSafeInteger(id) || id <= 0) return null;

  return { kind, id };
}

function estClos(kind, statut) {
  const clos = STATUTS_CLOS[kind];
  if (!clos || statut === null || statut === undefined) return false;

  return clos.has(String(statut).toLowerCase());
}

function mapEvent(row, statut = null) {
  const cle = cleDemande(row.event_key);

  return {
    id: Number(row.id),
    kind: row.kind,
    reference: row.reference,
    titre: row.titre,
    demandeur: row.demandeur,
    montant: row.montant === null ? null : Number(row.montant),
    createdAt: row.created_at,
    readAt: row.read_at,
    demandeStatut: statut ?? null,
    // L'écran admin n'affiche la corbeille que sur les demandes closes.
    supprimable: cle ? estClos(cle.kind, statut) : false,
  };
}

function broadcast(row) {
  if (listeners.size === 0) return;

  const charge = `event: activite\ndata: ${JSON.stringify(mapEvent(row))}\n\n`;
  for (const reponse of listeners) {
    try {
      reponse.write(charge);
    } catch (error) {
      listeners.delete(reponse);
    }
  }
}

/**
 * Annonce le retrait d'une ligne : les autres postes admin ouverts l'effacent
 * sans attendre leur prochain rafraîchissement.
 */
function broadcastSuppression(id) {
  if (listeners.size === 0) return;

  const charge = `event: activite-supprimee\ndata: ${JSON.stringify({
    id: Number(id),
    supprime: true,
  })}\n\n`;

  for (const reponse of listeners) {
    try {
      reponse.write(charge);
    } catch (error) {
      listeners.delete(reponse);
    }
  }
}

function subscribe(reponse) {
  listeners.add(reponse);
  return () => listeners.delete(reponse);
}

function connectedListeners() {
  return listeners.size;
}

async function insertEvent(evenement) {
  const { rows } = await pool.query(
    `INSERT INTO admin_events
       (event_key, kind, reference, titre, demandeur, montant, metadata)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     ON CONFLICT (event_key) DO NOTHING
     RETURNING *`,
    [
      evenement.key,
      evenement.kind,
      evenement.reference,
      evenement.titre,
      evenement.demandeur ?? null,
      evenement.montant ?? null,
      evenement.metadata ?? {},
    ],
  );

  const ligne = rows[0] ?? null;
  if (ligne) broadcast(ligne);
  return ligne;
}

/** Écriture tolérante : ne rejette jamais, journalise l'incident. */
async function journaliser(evenement) {
  try {
    return await insertEvent(evenement);
  } catch (error) {
    console.error('Journal activité admin:', error.message);
    return null;
  }
}

async function demandeurLabel(userId) {
  if (!userId) return null;

  try {
    const { rows } = await pool.query(
      'SELECT first_name, last_name, phone FROM users WHERE id = $1',
      [userId],
    );
    const ligne = rows[0];
    if (!ligne) return null;

    const nom = [ligne.first_name, ligne.last_name].filter(Boolean).join(' ');
    return ligne.phone ? `${nom} · ${ligne.phone}` : nom;
  } catch (error) {
    return null;
  }
}

async function recordLocationRequest({ location, userId }) {
  if (!location) return null;

  return journaliser({
    key: `location:${location.id}`,
    kind: 'location',
    reference: location.code,
    titre: location.appareil_nom,
    demandeur: await demandeurLabel(userId ?? location.user_id),
    montant: location.montant_total,
    metadata: {
      dateDebut: location.date_debut,
      dateFin: location.date_fin,
    },
  });
}

async function recordPurchaseRequest({ demande, userId }) {
  if (!demande) return null;

  return journaliser({
    key: `vente:${demande.id}`,
    kind: 'vente',
    reference: demande.code,
    titre: demande.appareil_nom,
    demandeur: await demandeurLabel(userId),
    montant: demande.total,
    metadata: { quantite: demande.quantite },
  });
}

async function recordQuoteRequest({ devis }) {
  if (!devis) return null;

  const titre = devis.service_name?.trim() || 'Demande de devis';
  const description = devis.description?.trim();

  return journaliser({
    key: `devis:${devis.id}`,
    kind: 'devis',
    reference: `DEV-${devis.id}`,
    titre,
    demandeur: [devis.nom, devis.telephone].filter(Boolean).join(' · ') || null,
    montant: devis.montant ?? null,
    metadata: { description: description ?? null },
  });
}

/**
 * Statuts actuels des demandes citées par le journal, en trois requêtes au plus
 * quel que soit le nombre de lignes affichées.
 */
async function statutsDesDemandes(evenements) {
  const idsParModule = { location: [], vente: [], devis: [] };

  for (const ligne of evenements) {
    const cle = cleDemande(ligne.event_key);
    if (cle) idsParModule[cle.kind].push(cle.id);
  }

  const statuts = new Map();

  await Promise.all(
    Object.entries(idsParModule).map(async ([kind, ids]) => {
      if (ids.length === 0) return;

      try {
        const { rows } = await pool.query(
          `SELECT id, statut FROM ${TABLES_DEMANDES[kind]} WHERE id = ANY($1::int[])`,
          [ids],
        );
        for (const ligne of rows) {
          statuts.set(`${kind}:${ligne.id}`, ligne.statut);
        }
      } catch (error) {
        // Le journal reste lisible même si une table métier est indisponible :
        // la corbeille sera simplement absente de ces lignes.
        console.error('Statut des demandes pour le journal:', error.message);
      }
    }),
  );

  return statuts;
}

async function listActivity({ since, limit = 60 } = {}) {
  const params = [];
  let filtre = '';

  if (since) {
    params.push(since);
    filtre = `WHERE created_at > $${params.length}`;
  }

  const taille = Math.min(Math.max(Number(limit) || 60, 1), 200);
  params.push(taille);

  const { rows } = await pool.query(
    `SELECT * FROM admin_events ${filtre}
      ORDER BY created_at DESC
      LIMIT $${params.length}`,
    params,
  );

  const statuts = await statutsDesDemandes(rows);

  return rows.map((ligne) => {
    const cle = cleDemande(ligne.event_key);
    const statut = cle ? statuts.get(`${cle.kind}:${cle.id}`) ?? null : null;
    return mapEvent(ligne, statut);
  });
}

async function activitySummary() {
  const { rows } = await pool.query(
    `SELECT kind, COUNT(*)::int AS total
       FROM admin_events
      WHERE read_at IS NULL
      GROUP BY kind`,
  );

  const unread = { location: 0, vente: 0, devis: 0 };
  let total = 0;

  for (const ligne of rows) {
    unread[ligne.kind] = ligne.total;
    total += ligne.total;
  }

  return { unread, total };
}

async function markEventRead(id, adminId) {
  const { rows } = await pool.query(
    `UPDATE admin_events
        SET read_at = NOW(), read_by = $2
      WHERE id = $1 AND read_at IS NULL
      RETURNING *`,
    [id, adminId ?? null],
  );

  return rows[0] ? mapEvent(rows[0]) : null;
}

async function markAllRead(adminId) {
  const { rowCount } = await pool.query(
    `UPDATE admin_events
        SET read_at = NOW(), read_by = $1
      WHERE read_at IS NULL`,
    [adminId ?? null],
  );

  return rowCount;
}

/**
 * Retire une ligne du journal, à condition que la demande liée soit close.
 *
 * La demande elle-même n'est jamais touchée : seule la ligne d'historique
 * disparaît. Une demande en attente, en cours, en retard ou rejetée est
 * refusée, pour que l'atelier garde la trace de ce qu'il reste à traiter.
 */
async function deleteEvent(id) {
  const { rows } = await pool.query(
    'SELECT * FROM admin_events WHERE id = $1',
    [id],
  );
  const ligne = rows[0];
  if (!ligne) return { introuvable: true };

  const cle = cleDemande(ligne.event_key);
  if (!cle) {
    return {
      refus:
        'La demande d’origine de cette ligne est introuvable : elle ne peut pas être supprimée.',
      statut: null,
    };
  }

  const { rows: demandes } = await pool.query(
    `SELECT statut FROM ${TABLES_DEMANDES[cle.kind]} WHERE id = $1`,
    [cle.id],
  );
  const statut = demandes[0]?.statut ?? null;

  if (!estClos(cle.kind, statut)) {
    return {
      refus: statut
        ? 'Cette demande est encore ouverte : elle ne peut pas être retirée de l’historique.'
        : 'La demande d’origine est introuvable : cette ligne ne peut pas être supprimée.',
      statut,
    };
  }

  await pool.query('DELETE FROM admin_events WHERE id = $1', [id]);
  broadcastSuppression(id);

  return { supprime: true, statut };
}

/**
 * Ménage : le journal n'a pas vocation à grossir indéfiniment. Les événements
 * lus et vieux de plus d'un mois sont supprimés à chaque démarrage de migration.
 */
async function purgeOldEvents(client = pool) {
  const { rowCount } = await client.query(
    `DELETE FROM admin_events
      WHERE read_at IS NOT NULL
        AND read_at < NOW() - INTERVAL '${RETENTION_JOURS} days'`,
  );

  return rowCount;
}

module.exports = {
  HEARTBEAT_MS,
  activitySummary,
  connectedListeners,
  deleteEvent,
  listActivity,
  markAllRead,
  markEventRead,
  purgeOldEvents,
  recordLocationRequest,
  recordPurchaseRequest,
  recordQuoteRequest,
  subscribe,
};
