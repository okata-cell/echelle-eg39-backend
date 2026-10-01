const assert = require('node:assert/strict');
const { test } = require('node:test');
const {
  businessToday,
  inclusiveRentalDays,
  isDateOnly,
  overlapsInclusive,
} = require('../src/utils/rental_dates');

test('validates canonical date-only values and inclusive rental days', () => {
  assert.equal(isDateOnly('2026-10-01'), true);
  assert.equal(isDateOnly('2026-02-30'), false);
  assert.equal(isDateOnly('2026-10-01T00:00:00Z'), false);
  assert.equal(inclusiveRentalDays('2026-10-01', '2026-10-01'), 1);
  assert.equal(inclusiveRentalDays('2026-10-01', '2026-10-03'), 3);
  assert.equal(inclusiveRentalDays('2026-10-03', '2026-10-01'), 0);
});

test('treats shared boundary days as inclusive overlap', () => {
  assert.equal(
    overlapsInclusive('2026-10-01', '2026-10-05', '2026-10-05', '2026-10-08'),
    true,
  );
  assert.equal(
    overlapsInclusive('2026-10-01', '2026-10-05', '2026-10-06', '2026-10-08'),
    false,
  );
});

test('uses the configured Togo business calendar', () => {
  const instantBeforeUtcMidnight = new Date('2026-09-30T23:30:00.000Z');
  assert.equal(businessToday(instantBeforeUtcMidnight), '2026-09-30');
});
