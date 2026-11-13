const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  chiffrerContact,
  cleChiffrement,
  contactsDuCompte,
  dechiffrerContact,
  empreinteContact,
  etatSecrets,
} = require('../src/utils/contact_crypto');

const CLE = Buffer.alloc(32, 7).toString('base64');
const ENV = {
  DATA_ENCRYPTION_KEY: CLE,
  CONTACT_INDEX_SECRET: 'secret-index-de-test',
};

test('le chiffrement se relit et ne laisse rien en clair', () => {
  const chiffre = chiffrerContact('afi@example.com', { env: ENV });

  assert.match(chiffre, /^v1:/);
  assert.ok(!chiffre.includes('afi@example.com'));
  assert.equal(dechiffrerContact(chiffre, { env: ENV }), 'afi@example.com');

  const telephone = chiffrerContact('+22890000000', { env: ENV });
  assert.equal(dechiffrerContact(telephone, { env: ENV }), '+22890000000');
});

test('deux chiffrements de la même valeur diffèrent', () => {
  const premier = chiffrerContact('afi@example.com', { env: ENV });
  const second = chiffrerContact('afi@example.com', { env: ENV });

  // Vecteur d'initialisation aléatoire : aucun rapprochement possible à l'œil.
  assert.notEqual(premier, second);
  assert.equal(dechiffrerContact(premier, { env: ENV }), 'afi@example.com');
  assert.equal(dechiffrerContact(second, { env: ENV }), 'afi@example.com');
});

test('une valeur altérée ou une mauvaise clé ne rendent rien', () => {
  const chiffre = chiffrerContact('afi@example.com', { env: ENV });
  const altere = `${chiffre.slice(0, -4)}AAAA`;

  assert.equal(dechiffrerContact(altere, { env: ENV }), null);
  assert.equal(
    dechiffrerContact(chiffre, {
      env: { DATA_ENCRYPTION_KEY: Buffer.alloc(32, 9).toString('base64') },
    }),
    null,
  );
  assert.equal(dechiffrerContact('pas un chiffré', { env: ENV }), null);
  assert.equal(dechiffrerContact('', { env: ENV }), null);
});

test('l’index aveugle est stable, secret et non réversible', () => {
  const premier = empreinteContact('Afi@Example.com', { env: ENV });
  const second = empreinteContact('  afi@example.com ', { env: ENV });

  // Même adresse, écriture différente : même empreinte, donc même compte.
  assert.equal(premier, second);
  assert.match(premier, /^[0-9a-f]{64}$/);

  // Deux valeurs distinctes ne se confondent pas.
  assert.notEqual(
    premier,
    empreinteContact('autre@example.com', { env: ENV }),
  );

  // Un autre secret donne une autre empreinte : sans lui, pas de recherche.
  assert.notEqual(
    premier,
    empreinteContact('afi@example.com', {
      env: { CONTACT_INDEX_SECRET: 'autre-secret' },
    }),
  );

  assert.equal(empreinteContact('', { env: ENV }), null);
});

test('la clé de chiffrement fait toujours 32 octets', () => {
  assert.equal(cleChiffrement({ DATA_ENCRYPTION_KEY: CLE }).length, 32);
  assert.equal(
    cleChiffrement({ DATA_ENCRYPTION_KEY: Buffer.alloc(32, 5).toString('hex') })
      .length,
    32,
  );
  // Clé courte : dérivée plutôt que refusée.
  assert.equal(cleChiffrement({ DATA_ENCRYPTION_KEY: 'court' }).length, 32);
  // Repli documenté sur le secret du serveur.
  assert.equal(cleChiffrement({ JWT_SECRET: 'secret-de-secours' }).length, 32);
  assert.equal(cleChiffrement({}), null);
});

test('la lecture reste mixte pour les comptes hérités', () => {
  const chiffreEmail = chiffrerContact('nouveau@example.com', { env: ENV });
  const chiffrePhone = chiffrerContact('+22890000001', { env: ENV });

  // Compte hérité : coordonnées en clair, aucune colonne chiffrée.
  assert.deepEqual(
    contactsDuCompte(
      { email: 'ancien@example.com', phone: '+22890000002' },
      { env: ENV },
    ),
    { email: 'ancien@example.com', phone: '+22890000002' },
  );

  // Compte récent : colonnes héritées vides, valeurs déchiffrées à la lecture.
  assert.deepEqual(
    contactsDuCompte(
      {
        email: null,
        phone: null,
        email_cipher: chiffreEmail,
        phone_cipher: chiffrePhone,
      },
      { env: ENV },
    ),
    { email: 'nouveau@example.com', phone: '+22890000001' },
  );

  // Le clair prime s'il existe encore, même en présence d'un chiffré.
  assert.deepEqual(
    contactsDuCompte(
      { email: 'ancien@example.com', phone: null, email_cipher: chiffreEmail },
      { env: ENV },
    ),
    { email: 'ancien@example.com', phone: null },
  );

  assert.deepEqual(contactsDuCompte(null, { env: ENV }), {
    email: null,
    phone: null,
  });
});

test('/health annonce les secrets sans jamais livrer leur valeur', () => {
  // Variables renseignées : c'est l'état attendu en production.
  assert.deepEqual(etatSecrets(ENV), {
    encryptionKey: 'dediee',
    indexSecret: 'dedie',
  });

  // Rien de renseigné : le service tourne, mais le repli n'existe pas.
  assert.deepEqual(etatSecrets({}), {
    encryptionKey: 'absente',
    indexSecret: 'absent',
  });

  // Repli documenté sur le secret du serveur.
  const repli = etatSecrets({ JWT_SECRET: 'secret-de-secours' });
  assert.deepEqual(repli, { encryptionKey: 'derivee', indexSecret: 'herite' });
  assert.ok(!JSON.stringify(etatSecrets(ENV)).includes(CLE));
});
