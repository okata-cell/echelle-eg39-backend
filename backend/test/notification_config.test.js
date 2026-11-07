const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  describeDeliveryChannels,
  deliveryWarnings,
} = require('../src/services/notification_service');

const COMPLETE_ENV = {
  NODE_ENV: 'production',
  SENDGRID_API_KEY: 'sg-key',
  SENDGRID_FROM_EMAIL: 'no-reply@echelle-eg39.com',
  AFRICASTALKING_USERNAME: 'echelle',
  AT_API_KEY: 'at-key',
};

test('les deux canaux sont configurés quand toutes les variables sont là', () => {
  const channels = describeDeliveryChannels(COMPLETE_ENV);

  assert.equal(channels.email.configured, true);
  assert.equal(channels.email.provider, 'sendgrid');
  assert.equal(channels.sms.configured, true);
  assert.equal(channels.sms.provider, 'africastalking');
  assert.equal(channels.email.problem, null);
  assert.equal(channels.sms.problem, null);
});

test('une clé SendGrid absente est signalée par son nom', () => {
  const channels = describeDeliveryChannels({
    ...COMPLETE_ENV,
    SENDGRID_API_KEY: '',
  });

  assert.equal(channels.email.configured, false);
  assert.match(channels.email.problem, /SENDGRID_API_KEY/);
});

test('un expéditeur absent est distingué d’une clé absente', () => {
  const channels = describeDeliveryChannels({
    ...COMPLETE_ENV,
    SENDGRID_FROM_EMAIL: '',
    ADMIN_EMAIL: '',
  });

  assert.equal(channels.email.configured, false);
  assert.match(channels.email.problem, /SENDGRID_FROM_EMAIL/);
});

test('le SMS accepte AT_API_KEY comme AFRICASTALKING_API_KEY', () => {
  const withAtKey = describeDeliveryChannels({
    ...COMPLETE_ENV,
    AT_API_KEY: '',
    AFRICASTALKING_API_KEY: 'other-at-key',
  });
  assert.equal(withAtKey.sms.configured, true);

  const withoutUsername = describeDeliveryChannels({
    ...COMPLETE_ENV,
    AFRICASTALKING_USERNAME: ' ',
  });
  assert.equal(withoutUsername.sms.configured, false);
  assert.match(withoutUsername.sms.problem, /AFRICASTALKING_USERNAME/);
});

test('aucun secret ne sort du diagnostic', () => {
  const serialized = JSON.stringify(describeDeliveryChannels(COMPLETE_ENV));

  assert.equal(serialized.includes('sg-key'), false);
  assert.equal(serialized.includes('at-key'), false);
  assert.match(serialized, /no-reply@echelle-eg39\.com/);
});

test('les avertissements ne concernent que la production', () => {
  assert.deepEqual(deliveryWarnings({ NODE_ENV: 'development' }), []);

  const missingNothing = deliveryWarnings({ NODE_ENV: 'production' });
  assert.equal(missingNothing.length, 2);
  assert.match(missingNothing.join(' '), /SENDGRID|AFRICASTALKING/);

  assert.deepEqual(deliveryWarnings(COMPLETE_ENV), []);
});
