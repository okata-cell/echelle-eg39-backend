const assert = require('node:assert/strict');
const express = require('express');
const { after, before, test } = require('node:test');

process.env.JWT_SECRET = 'test-only-register-secret';

const pool = require('../src/config/database');
const authRouter = require('../src/routes/auth');

const app = express();
app.use(express.json());
app.use('/api/auth', authRouter);

let server;
let baseUrl;

const COMPTE = {
  firstName: 'Afi',
  lastName: 'Koffi',
  email: 'Afi.Koffi@Example.com',
  phone: '+22890000000',
  password: 'Chantier#2026',
};

function inscription(payload) {
  return fetch(`${baseUrl}/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
}

/** Base simulée : indique si l'e-mail et/ou le téléphone sont déjà pris. */
function baseSimulee({ emailPris = false, phonePris = false } = {}) {
  const etat = { requetes: [], insere: null };

  pool.query = async (query, params = []) => {
    const requete = query.replace(/\s+/g, ' ').trim();
    etat.requetes.push(requete);

    if (/LOWER\(email\) = \$1 OR email_bidx = \$2/.test(requete)) {
      return { rows: emailPris ? [{ id: 1 }] : [] };
    }
    if (/phone = ANY\(\$1::text\[\]\) OR phone_bidx = \$2/.test(requete)) {
      return { rows: phonePris ? [{ id: 2 }] : [] };
    }
    if (/INSERT INTO users/.test(requete)) {
      etat.insere = params;
      etat.requeteInsert = requete;
      return {
        rows: [
          {
            id: 11,
            first_name: params[0],
            last_name: params[1],
            role: 'client',
            created_at: '2026-11-12T10:00:00.000Z',
          },
        ],
      };
    }

    throw new Error(`Requête inattendue : ${requete}`);
  };

  return etat;
}

before(async () => {
  await new Promise((resolve) => {
    server = app.listen(0, () => {
      baseUrl = `http://127.0.0.1:${server.address().port}/api/auth`;
      resolve();
    });
  });
});

after(async () => {
  await new Promise((resolve) => server.close(resolve));
});

test('un mot de passe trop faible est refusé avant toute écriture', async () => {
  const etat = baseSimulee();

  for (const faible of ['1234AZER', 'azerty1234', 'Court1!']) {
    const reponse = await inscription({ ...COMPTE, password: faible });
    const corps = await reponse.json();

    assert.equal(reponse.status, 400, faible);
    assert.equal(corps.code, 'PASSWORD_TOO_WEAK');
    assert.match(corps.rules, /10 caractères minimum/);
  }

  // Aucune requête n'a dû atteindre la base.
  assert.deepEqual(etat.requetes, []);
});

test('une adresse e-mail déjà utilisée est refusée et désignée', async () => {
  baseSimulee({ emailPris: true });

  const reponse = await inscription(COMPTE);
  const corps = await reponse.json();

  assert.equal(reponse.status, 409);
  assert.equal(corps.code, 'IDENTIFIER_TAKEN');
  assert.deepEqual(corps.fields, ['email']);
  assert.equal(corps.error, 'Cette adresse e-mail est déjà utilisée.');
});

test('un numéro déjà utilisé est refusé et désigné', async () => {
  baseSimulee({ phonePris: true });

  const reponse = await inscription({
    ...COMPTE,
    email: 'nouveau@example.com',
  });
  const corps = await reponse.json();

  assert.equal(reponse.status, 409);
  assert.deepEqual(corps.fields, ['phone']);
  assert.equal(corps.error, 'Ce numéro de téléphone est déjà utilisé.');
});

test('les deux coordonnées prises sont annoncées ensemble', async () => {
  baseSimulee({ emailPris: true, phonePris: true });

  const reponse = await inscription(COMPTE);
  const corps = await reponse.json();

  assert.equal(reponse.status, 409);
  assert.deepEqual(corps.fields.sort(), ['email', 'phone']);
  assert.match(corps.error, /tous les deux|déjà utilisés/);
});

test('une inscription valide hache le mot de passe et normalise l’e-mail', async () => {
  const etat = baseSimulee();

  const reponse = await inscription(COMPTE);
  const corps = await reponse.json();

  assert.equal(reponse.status, 201);

  // Les coordonnées ne sont plus stockées en clair : elles sont chiffrées et
  // accompagnées de leur empreinte, les colonnes héritées restant vides.
  assert.match(etat.requeteInsert, /VALUES \(\$1, \$2, NULL, NULL/);
  assert.match(etat.insere[5], /^v1:/);
  assert.match(etat.insere[6], /^v1:/);
  assert.match(etat.insere[7], /^[0-9a-f]{64}$/);
  assert.match(etat.insere[8], /^[0-9a-f]{64}$/);

  const hash = etat.insere[2];
  assert.match(hash, /^p2:/);
  assert.ok(!hash.includes('Chantier'));
  assert.equal(typeof corps.recoveryCode, 'string');
});
