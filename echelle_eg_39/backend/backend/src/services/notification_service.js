const { normalizePhone } = require('../utils/identifiers');

const isProduction = () => process.env.NODE_ENV === 'production';
const AFRICAS_TALKING_BULK_SMS_URL =
  'https://api.africastalking.com/version1/messaging/bulk';
const ACCEPTED_SMS_STATUS_CODES = new Set([100, 101, 102]);

function simulationResult(channel) {
  if (isProduction()) {
    console.warn(`[${channel}] Provider non configuré; aucun envoi effectué.`);
    return { success: false, configured: false };
  }

  // Ne jamais écrire le destinataire ou le code OTP dans les logs.
  console.info(`[SIMULATION] ${channel}: envoi ignoré, fournisseur non configuré.`);
  return { success: true, simulated: true };
}

async function sendEmailCode(email, code, userName) {
  const apiKey = process.env.SENDGRID_API_KEY;
  const from = process.env.SENDGRID_FROM_EMAIL || process.env.ADMIN_EMAIL;

  if (!apiKey || !from) {
    return simulationResult('Email');
  }

  const safeName = String(userName || 'Client').replace(/[<>]/g, '');
  const response = await fetch('https://api.sendgrid.com/v3/mail/send', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      personalizations: [{ to: [{ email }] }],
      from: { email: from },
      subject: 'Réinitialisation du mot de passe - ÉCHELLE EG39',
      content: [
        {
          type: 'text/plain',
          value: `Bonjour ${safeName},\n\nVotre code de vérification ÉCHELLE EG39 est : ${code}\n\nCe code expire dans 15 minutes.`,
        },
        {
          type: 'text/html',
          value: `<p>Bonjour ${safeName},</p><p>Votre code de vérification est :</p><h2>${code}</h2><p>Ce code expire dans 15 minutes.</p>`,
        },
      ],
    }),
  });

  if (!response.ok) {
    const details = await response.text();
    throw new Error(`SendGrid ${response.status}: ${details.slice(0, 200)}`);
  }

  return { success: true };
}

async function sendSmsCode(phone, code) {
  const apiKey = process.env.AT_API_KEY || process.env.AFRICASTALKING_API_KEY;
  const username = process.env.AFRICASTALKING_USERNAME;
  const senderId = process.env.AFRICASTALKING_SENDER_ID;

  if (!apiKey || !username || !senderId) {
    const missing = [
      !apiKey && 'AT_API_KEY (ou AFRICASTALKING_API_KEY)',
      !username && 'AFRICASTALKING_USERNAME',
      !senderId && 'AFRICASTALKING_SENDER_ID',
    ].filter(Boolean);

    if (isProduction()) {
      console.warn(`[SMS] Configuration manquante: ${missing.join(', ')}.`);
    }
    return simulationResult('SMS');
  }

  const normalizedPhone = normalizePhone(phone);
  const response = await fetch(AFRICAS_TALKING_BULK_SMS_URL, {
    method: 'POST',
    headers: {
      apiKey,
      Accept: 'application/json',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      username,
      phoneNumbers: [normalizedPhone],
      message: `ÉCHELLE EG39 : votre code est ${code}. Il expire dans 15 minutes.`,
      senderId,
    }),
  });

  const responseText = await response.text();
  let result;
  try {
    result = responseText ? JSON.parse(responseText) : null;
  } catch {
    result = null;
  }

  if (!response.ok) {
    const providerCode = result?.SMSMessageData?.Recipients?.[0]?.statusCode;
    const codeLabel = Number.isFinite(Number(providerCode))
      ? `, statusCode=${Number(providerCode)}`
      : '';
    // Avoid logging raw provider payloads; they may contain recipient data.
    throw new Error(`Africa's Talking HTTP ${response.status}${codeLabel}.`);
  }

  const recipient = result?.SMSMessageData?.Recipients?.[0];
  if (!recipient) {
    throw new Error("Africa's Talking n'a retourné aucun statut de destinataire.");
  }

  const statusCode = Number(recipient.statusCode);
  const providerStatus = String(recipient.status || 'statut indisponible');
  if (!ACCEPTED_SMS_STATUS_CODES.has(statusCode)) {
    console.warn(
      `[SMS] Africa's Talking a refusé le message: statusCode=${statusCode}, status=${providerStatus}.`,
    );
    throw new Error(
      `Africa's Talking a refusé le SMS (statusCode ${statusCode}: ${providerStatus}).`,
    );
  }

  const cost = typeof recipient.cost === 'string' ? `, coût=${recipient.cost}` : '';
  const messageId =
    typeof recipient.messageId === 'string' ? `, messageId=${recipient.messageId}` : '';
  console.info(
    `[SMS] Africa's Talking a accepté le message: statusCode=${statusCode}, status=${providerStatus}${cost}${messageId}. La livraison au téléphone n'est pas confirmée par cette réponse.`,
  );

  return {
    success: true,
    accepted: true,
    delivered: false,
    statusCode,
    messageId: recipient.messageId,
  };
}

async function sendVerificationCode(contact, contactType, code, userName) {
  if (contactType === 'email') {
    return sendEmailCode(contact, code, userName);
  }

  return sendSmsCode(contact, code);
}

module.exports = { sendVerificationCode };
