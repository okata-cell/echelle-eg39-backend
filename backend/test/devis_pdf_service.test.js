const assert = require('node:assert/strict');
const { test } = require('node:test');

const { createDevisPdfBuffer, displayDate } = require('../src/services/devis_pdf_service');

test('génère un PDF français lisible contenant les termes de l’offre', async () => {
  const buffer = await createDevisPdfBuffer({
    devis: {
      id: 123,
      nom: 'Afi Koffi',
      email: 'afi@example.com',
      telephone: '+22890000000',
      service_name: 'Levée de détail',
      description: 'Relevé topographique à Lomé',
    },
    montant: 125000,
    dateValidite: '2026-10-15',
    commentaireAdmin: 'Offre valable jusqu’à la date indiquée.',
    dateEmission: '2026-10-08',
  });

  assert.ok(Buffer.isBuffer(buffer));
  assert.ok(buffer.length > 5000);
  assert.equal(buffer.subarray(0, 5).toString('ascii'), '%PDF-');
  assert.match(buffer.toString('latin1'), /NotoSans/);
});

test('formate les dates de validité sans décalage de fuseau', () => {
  assert.equal(displayDate('2026-10-15'), '15/10/2026');
  assert.equal(displayDate('date invalide'), 'date invalide');
});

test('refuse un devis sans montant positif ou date ISO', async () => {
  const base = {
    devis: { id: 1, nom: 'Client' },
    montant: 1000,
    dateValidite: '2026-10-15',
  };
  await assert.rejects(
    createDevisPdfBuffer({ ...base, montant: 0 }),
    /montant FCFA positif/,
  );
  await assert.rejects(
    createDevisPdfBuffer({ ...base, dateValidite: '15/10/2026' }),
    /date ISO/,
  );
});
