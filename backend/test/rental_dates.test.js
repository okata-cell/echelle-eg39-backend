const assert = require('node:assert/strict');
const { test } = require('node:test');
const {
  businessToday,
  findBlockingLocation,
  inclusiveRentalDays,
  isDateOnly,
  RENTAL_BLOCKING_STATUSES,
} = require('../src/utils/rental_dates');

test('validates date-only values and inclusive rental days', () => {
  assert.equal(isDateOnly('2026-10-01'), true);
  assert.equal(isDateOnly('2026-02-30'), false);
  assert.equal(isDateOnly('2026-10-01T00:00:00Z'), false);
  assert.equal(inclusiveRentalDays('2026-10-01', '2026-10-01'), 1);
  assert.equal(inclusiveRentalDays('2026-10-01', '2026-10-03'), 3);
  assert.equal(inclusiveRentalDays('2026-10-03', '2026-10-01'), 0);
});

test('uses the Togo business calendar for the current rental day', () => {
  assert.equal(
    businessToday(new Date('2026-09-30T23:30:00.000Z')),
    '2026-09-30',
  );
});

test('finds inclusive reservation conflicts and keeps overdue rentals open-ended', async () => {
  let capturedValues;
  const blockingLocation = { id: 12, statut: 'en_attente' };
  const db = {
    async query(_sql, values) {
      capturedValues = values;
      return { rows: [blockingLocation] };
    },
  };

  const result = await findBlockingLocation(db, {
    appareilId: 9,
    dateDebut: '2026-10-03',
    dateFin: '2026-10-05',
    today: '2026-10-01',
  });

  assert.equal(result, blockingLocation);
  assert.equal(capturedValues[0], 9);
  assert.deepEqual(capturedValues[1], RENTAL_BLOCKING_STATUSES);
  assert.equal(capturedValues[3], '2026-10-05');
  assert.equal(capturedValues[4], '2026-10-03');
  assert.equal(capturedValues[6], '2026-10-01');
});
