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

function mapEvent(row) {
  return {
    id: Number(row.id),
    kind: row.kind,
    reference: row.reference,
    titre: row.titre,
    demandeur: row.demandeur,
    montant: row.montant === null ? null : Number(row.montant),
    createdAt: row.created_at,
    readAt: row.read_at,
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

  return rows.map(mapEvent);
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
  listActivity,
  markAllRead,
  markEventRead,
  purgeOldEvents,
  recordLocationRequest,
  recordPurchaseRequest,
  recordQuoteRequest,
  subscribe,
};
