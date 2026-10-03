const RENTAL_BLOCKING_STATUSES = Object.freeze([
  'en_attente',
  'approuvee',
  'en_cours',
  'en_retard',
]);

const RENTAL_OPEN_ENDED_STATUSES = Object.freeze([
  'approuvee',
  'en_cours',
  'en_retard',
]);

const RENTAL_APPROVAL_BLOCKING_STATUSES = Object.freeze([
  'approuvee',
  'en_cours',
  'en_retard',
]);

function isDateOnly(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return false;
  }

  const parsed = new Date(`${value}T00:00:00.000Z`);
  return Number.isFinite(parsed.getTime()) &&
    parsed.toISOString().slice(0, 10) === value;
}

// pg parses PostgreSQL DATE columns into local-time JavaScript Date objects.
// Keep their calendar day instead of stringifying them ("Thu Oct 08 ...").
function toDateOnly(value) {
  if (value instanceof Date) {
    if (!Number.isFinite(value.getTime())) return null;
    const year = String(value.getFullYear()).padStart(4, '0');
    const month = String(value.getMonth() + 1).padStart(2, '0');
    const day = String(value.getDate()).padStart(2, '0');
    const dateOnly = `${year}-${month}-${day}`;
    return isDateOnly(dateOnly) ? dateOnly : null;
  }

  return isDateOnly(value) ? value : null;
}

function businessToday(now = new Date()) {
  const values = Object.fromEntries(
    new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Africa/Lome',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    })
      .formatToParts(now)
      .filter((part) => part.type !== 'literal')
      .map((part) => [part.type, part.value]),
  );

  return `${values.year}-${values.month}-${values.day}`;
}

function inclusiveRentalDays(dateDebut, dateFin) {
  if (!isDateOnly(dateDebut) || !isDateOnly(dateFin) || dateFin < dateDebut) {
    return 0;
  }

  const start = Date.parse(`${dateDebut}T00:00:00.000Z`);
  const end = Date.parse(`${dateFin}T00:00:00.000Z`);
  return Math.floor((end - start) / 86_400_000) + 1;
}

async function findBlockingLocation(
  db,
  {
    appareilId,
    dateDebut,
    dateFin,
    today,
    excludeLocationId = null,
    blockingStatuses = RENTAL_BLOCKING_STATUSES,
  },
) {
  const result = await db.query(
    `SELECT id, code, statut, date_debut, date_fin
       FROM locations
      WHERE appareil_id = $1
        AND statut = ANY($2::text[])
        AND ($3::integer IS NULL OR id <> $3)
        AND date_debut <= $4::date
        AND (
          date_fin >= $5::date
          OR (statut = ANY($6::text[]) AND date_fin < $7::date)
        )
      ORDER BY date_debut, id
      LIMIT 1`,
    [
      appareilId,
      blockingStatuses,
      excludeLocationId,
      dateFin,
      dateDebut,
      RENTAL_OPEN_ENDED_STATUSES,
      today,
    ],
  );

  return result.rows[0] ?? null;
}

module.exports = {
  RENTAL_BLOCKING_STATUSES,
  RENTAL_OPEN_ENDED_STATUSES,
  RENTAL_APPROVAL_BLOCKING_STATUSES,
  businessToday,
  findBlockingLocation,
  inclusiveRentalDays,
  isDateOnly,
  toDateOnly,
};
