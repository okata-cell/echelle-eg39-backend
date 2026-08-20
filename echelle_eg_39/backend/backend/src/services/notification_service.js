const { normalizePhone } = require('../utils/identifiers');

const isProduction = () => process.env.NODE_ENV === 'production';

function simulationResult(channel, contact, code) {
  if (isProduction()) {
    console.warn(`⚠️ ${channel} non configuré pour ${contact}`);
    return { success: false, configured: false };
  }

  console.log(`[SIMULATION] ${channel} à ${contact}: code ${code}`);
  return { success: true, simulated: true };
}

async function sendEmailCode(email, code, userName) {
  const apiKey = process.env.SENDGRID_API_KEY;
  const from = process.env.SENDGRID_FROM_EMAIL || process.env.ADMIN_EMAIL;

  if (!apiKey || !from) {
    return simulationResult('Email', email, code);
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

  if (!apiKey || !username) {
    return simulationResult('SMS', phone, code);
  }

  const response = await fetch('https://api.africastalking.com/version1/messaging', {
    method: 'POST',
    headers: {
      apiKey,
      Accept: 'application/json',
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      username,
      to: normalizePhone(phone),
      message: `ÉCHELLE EG39 : votre code est ${code}. Il expire dans 15 minutes.`,
    }),
  });

  if (!response.ok) {
    const details = await response.text();
    throw new Error(`Africa's Talking ${response.status}: ${details.slice(0, 200)}`);
  }

  return { success: true };
}

async function sendVerificationCode(contact, contactType, code, userName) {
  if (contactType === 'email') {
    return sendEmailCode(contact, code, userName);
  }

  return sendSmsCode(contact, code);
}

module.exports = { sendVerificationCode };
