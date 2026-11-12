const assert = require('node:assert/strict');
const express = require('express');
const jwt = require('jsonwebtoken');
const { after, before, test } = require('node:test');

process.env.JWT_SECRET = 'test-only-activity-secret';

const pool = require('../src/config/database');
const activiteRouter = require('../src/routes/admin_activity');

const app = express();
app.use(express.json());
app.use('/api/admin/activity', activiteRouter);

let server;
let baseUrl;

const TABLES = {
  locations: 'location',
  demandes_achat: 'vente',
  devis: 'devis',
};

function tokenAdmin() {
  return jwt.sign({ userId: 1, role: 'admin' }, process.env.JWT_SECRET);
}

function entete() {
  return {
    Authorization: `Bearer ${tokenAdmin()}`,
    'Content-Type': 'application/json',
  };
}

function ligne({ id, key, kind, reference = 'LOC-1', titre = 'Station totale' }) {
  return {
    id,
    event_key: key,
    kind,
    reference,
    titre,
    demandeur: 'Silva Okata · +228 90 94 94 39',
    montant: 60000,
    metadata: {},
    created_at: '2026-11-11T10:00:00.000Z',
    read_at: '2026-11-11T11:00:00.000Z',
  };
}

/** Base simulée : journal + statuts des demandes liées. */
function baseSimulee({ events = [], statuts = {} } = {}) {
  const etat = { events, statuts, supprimes: [] };

  pool.query = async (sql, values = []) => {
    const requete = sql.replace(/\s+/g, ' ').trim();

    if (/SELECT kind, COUNT\(\*\)::int AS total FROM admin_events/.test(requete)) {
      return { rows: [] };
    }
    if (/SELECT \* FROM admin_events WHERE id = \$1/.test(requete)) {
      return { rows: etat.events.filter((item) => item.id === values[0]) };
    }
    if (/SELECT \* FROM admin_events/.test(requete)) {
      return { rows: etat.events };
    }
    if (/DELETE FROM admin_events WHERE id = \$1/.test(requete)) {
      etat.supprimes.push(values[0]);
      return { rows: [], rowCount: 1 };
    }

    const lot = requete.match(
      /SELECT id, statut FROM (locations|demandes_achat|devis) WHERE id = ANY/,
    );
    if (lot) {
      const table = etat.statuts[TABLES[lot[1]]] ?? {};
      return {
        rows: values[0]
          .filter((id) => table[id])
          .map((id) => ({ id, statut: table[id] })),
      };
    }

    const unique = requete.match(
      /SELECT statut FROM (locations|demandes_achat|devis) WHERE id = \$1/,
    );
    if (unique) {
      const statut = (etat.statuts[TABLES[unique[1]]] ?? {})[values[0]];
      return { rows: statut ? [{ statut }] : [] };
    }

    throw new Error(`Requête inattendue: ${requete}`);
  };

  return etat;
}

before(async () => {
  await new Promise((resolve) => {
    server = app.listen(0, () => {
      baseUrl = `http://127.0.0.1:${server.address().port}/api/admin/activity`;
      resolve();
    });
  });
});

after(async () => {
  await new Promise((resolve) => server.close(resolve));
});

test('la liste signale les lignes dont la demande est close', async () => {
  baseSimulee({
    events: [
      ligne({ id: 1, key: 'location:12', kind: 'location' }),
      ligne({
        id: 2,
        key: 'vente:8',
        kind: 'vente',
        reference: 'DA-8',
        titre: 'GPS Leica',
      }),
    ],
    statuts: { location: { 12: 'termine' }, vente: { 8: 'en_attente' } },
  });

  const reponse = await fetch(baseUrl, { headers: entete() });
  assert.equal(reponse.status, 200);

  const corps = await reponse.json();
  assert.equal(corps.events[0].demandeStatut, 'termine');
  assert.equal(corps.events[0].supprimable, true);
  assert.equal(corps.events[1].demandeStatut, 'en_attente');
  assert.equal(corps.events[1].supprimable, false);
});

test('une location terminée quitte l’historique', async () => {
  const etat = baseSimulee({
    events: [ligne({ id: 1, key: 'location:12', kind: 'location' })],
    statuts: { location: { 12: 'termine' } },
  });

  const reponse = await fetch(`${baseUrl}/1`, {
    method: 'DELETE',
    headers: entete(),
  });

  assert.equal(reponse.status, 204);
  assert.deepEqual(etat.supprimes, [1]);
});

test('une location annulée quitte l’historique', async () => {
  const etat = baseSimulee({
    events: [ligne({ id: 4, key: 'location:31', kind: 'location' })],
    statuts: { location: { 31: 'annulee' } },
  });

  const reponse = await fetch(`${baseUrl}/4`, {
    method: 'DELETE',
    headers: entete(),
  });

  assert.equal(reponse.status, 204);
  assert.deepEqual(etat.supprimes, [4]);
});

test('une demande en cours ne peut pas être supprimée', async () => {
  const etat = baseSimulee({
    events: [ligne({ id: 2, key: 'location:9', kind: 'location' })],
    statuts: { location: { 9: 'en_cours' } },
  });

  const reponse = await fetch(`${baseUrl}/2`, {
    method: 'DELETE',
    headers: entete(),
  });

  assert.equal(reponse.status, 409);
  const corps = await reponse.json();
  assert.match(corps.error, /encore ouverte/i);
  assert.equal(corps.statut, 'en_cours');
  assert.deepEqual(etat.supprimes, []);
});

test('une demande en attente ne peut pas être supprimée', async () => {
  const etat = baseSimulee({
    events: [ligne({ id: 3, key: 'vente:8', kind: 'vente' })],
    statuts: { vente: { 8: 'en_attente' } },
  });

  const reponse = await fetch(`${baseUrl}/3`, {
    method: 'DELETE',
    headers: entete(),
  });

  assert.equal(reponse.status, 409);
  assert.deepEqual(etat.supprimes, []);
});

test('un devis rejeté reste consultable', async () => {
  const etat = baseSimulee({
    events: [ligne({ id: 5, key: 'devis:21', kind: 'devis' })],
    statuts: { devis: { 21: 'rejetee' } },
  });

  const reponse = await fetch(`${baseUrl}/5`, {
    method: 'DELETE',
    headers: entete(),
  });

  assert.equal(reponse.status, 409);
  assert.deepEqual(etat.supprimes, []);
});

test('une vente livrée quitte l’historique', async () => {
  const etat = baseSimulee({
    events: [ligne({ id: 6, key: 'vente:14', kind: 'vente' })],
    statuts: { vente: { 14: 'livree' } },
  });

  const reponse = await fetch(`${baseUrl}/6`, {
    method: 'DELETE',
    headers: entete(),
  });

  assert.equal(reponse.status, 204);
  assert.deepEqual(etat.supprimes, [6]);
});

test('une ligne déjà supprimée renvoie 404', async () => {
  baseSimulee({ events: [] });

  const reponse = await fetch(`${baseUrl}/999`, {
    method: 'DELETE',
    headers: entete(),
  });

  assert.equal(reponse.status, 404);
});

test('un client ne peut pas supprimer une ligne du journal', async () => {
  baseSimulee({
    events: [ligne({ id: 1, key: 'location:12', kind: 'location' })],
    statuts: { location: { 12: 'termine' } },
  });

  const reponse = await fetch(`${baseUrl}/1`, {
    method: 'DELETE',
    headers: {
      Authorization: `Bearer ${jwt.sign(
        { userId: 42, role: 'client' },
        process.env.JWT_SECRET,
      )}`,
    },
  });

  assert.equal(reponse.status, 403);
});
