const assert = require('node:assert/strict');
const { test } = require('node:test');

const { sendVerificationCode } = require('../src/services/notification_service');

const AT_ENV_KEYS = [
  'NODE_ENV',
  'AT_API_KEY',
  'AFRICASTALKING_API_KEY',
  'AFRICASTALKING_USERNAME',
  'AFRICASTALKING_SENDER_ID',
];

function setUpSmsEnvironment(t, values = {}) {
  const previousEnv = Object.fromEntries(
    AT_ENV_KEYS.map((key) => [key, process.env[key]]),
  );
  const previousFetch = global.fetch;
  const previousInfo = console.info;
  const previousWarn = console.warn;

  t.after(() => {
    for (const key of AT_ENV_KEYS) {
      if (previousEnv[key] === undefined) delete process.env[key];
      else process.env[key] = previousEnv[key];
    }
    global.fetch = previousFetch;
    console.info = previousInfo;
    console.warn = previousWarn;
  });

  for (const key of AT_ENV_KEYS) delete process.env[key];
  Object.assign(process.env, values);
  process.env.NODE_ENV = 'production';
}

function jsonResponse(body, { ok = true, status = 200 } = {}) {
  return {
    ok,
    status,
    text: async () => JSON.stringify(body),
  };
}

test('envoie le SMS avec Sender ID et journalise uniquement le statut fournisseur', async (t) => {
  setUpSmsEnvironment(t, {
    AT_API_KEY: 'test-api-key',
    AFRICASTALKING_USERNAME: 'echelle-live',
    AFRICASTALKING_SENDER_ID: 'ECHELLE',
  });

  let request;
  let logs = '';
  console.info = (...args) => { logs += args.join(' '); };
  global.fetch = async (url, options) => {
    request = { url, options };
    return jsonResponse({
      SMSMessageData: {
        Recipients: [{
          statusCode: 101,
          status: 'Success',
          number: '+22890123456',
          cost: 'XOF 1.00',
          messageId: 'AT-test-id',
        }],
      },
    });
  };

  const code = '123456';
  const result = await sendVerificationCode('+22890123456', 'phone', code);

  assert.equal(request.url, 'https://api.africastalking.com/version1/messaging/bulk');
  assert.equal(request.options.headers.apiKey, 'test-api-key');
  assert.equal(request.options.headers['Content-Type'], 'application/json');
  assert.deepEqual(JSON.parse(request.options.body), {
    username: 'echelle-live',
    phoneNumbers: ['+22890123456'],
    message: `ÉCHELLE EG39 : votre code est ${code}. Il expire dans 15 minutes.`,
    senderId: 'ECHELLE',
  });
  assert.equal(result.success, true);
  assert.equal(result.accepted, true);
  assert.equal(result.delivered, false);
  assert.equal(result.statusCode, 101);
  assert.match(logs, /statusCode=101/);
  assert.equal(logs.includes(code), false);
  assert.equal(logs.includes('+22890123456'), false);
});

test('rejette un SMS refusé par le fournisseur même si HTTP est 200', async (t) => {
  setUpSmsEnvironment(t, {
    AT_API_KEY: 'test-api-key',
    AFRICASTALKING_USERNAME: 'echelle-live',
    AFRICASTALKING_SENDER_ID: 'ECHELLE',
  });

  global.fetch = async () => jsonResponse({
    SMSMessageData: {
      Recipients: [{ statusCode: 402, status: 'InvalidSenderId' }],
    },
  });

  await assert.rejects(
    sendVerificationCode('+22890123456', 'phone', '654321'),
    /statusCode 402: InvalidSenderId/,
  );
});

test('échoue en production si le Sender ID est absent', async (t) => {
  setUpSmsEnvironment(t, {
    AT_API_KEY: 'test-api-key',
    AFRICASTALKING_USERNAME: 'echelle-live',
  });

  let called = false;
  global.fetch = async () => {
    called = true;
    return jsonResponse({});
  };

  const result = await sendVerificationCode('+22890123456', 'phone', '112233');

  assert.equal(result.success, false);
  assert.equal(result.configured, false);
  assert.equal(called, false);
});
