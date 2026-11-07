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

/**
 * État des canaux d'envoi, sans jamais révéler de secret.
 *
 * Une variable déclarée dans `render.yaml` sans valeur dans le tableau de bord
 * reste vide : c'est la cause la plus fréquente du message « service d'envoi
 * indisponible ». Ce résumé permet de le voir d'un coup d'œil.
 */
function describeDeliveryChannels(env = process.env) {
  const sendgridKey = Boolean(String(env.SENDGRID_API_KEY || '').trim());
  const sendgridFrom = String(
    env.SENDGRID_FROM_EMAIL || env.ADMIN_EMAIL || '',
  ).trim();
  const atKey = Boolean(
    String(env.AT_API_KEY || env.AFRICASTALKING_API_KEY || '').trim(),
  );
  const atUsername = String(env.AFRICASTALKING_USERNAME || '').trim();

  return {
    email: {
      provider: 'sendgrid',
      configured: sendgridKey && Boolean(sendgridFrom),
      problem: !sendgridKey
        ? 'SENDGRID_API_KEY manquante'
        : !sendgridFrom
          ? 'SENDGRID_FROM_EMAIL manquant'
          : null,
      sender: sendgridFrom || null,
    },
    sms: {
      provider: 'africastalking',
      configured: atKey && Boolean(atUsername),
      problem: !atKey
        ? 'AT_API_KEY (ou AFRICASTALKING_API_KEY) manquante'
        : !atUsername
          ? 'AFRICASTALKING_USERNAME manquant'
          : null,
      username: atUsername || null,
    },
  };
}

/** Avertissements affichés au démarrage du serveur. */
function deliveryWarnings(env = process.env) {
  if (env.NODE_ENV !== 'production') return [];

  const channels = describeDeliveryChannels(env);
  const warnings = [];

  if (!channels.email.configured) {
    warnings.push(
      'Envoi e-mail non configuré : les demandes de code par e-mail seront ' +
        `refusées. Renseignez SENDGRID_API_KEY et SENDGRID_FROM_EMAIL dans Render (${channels.email.provider}).`,
    );
  }
  if (!channels.sms.configured) {
    warnings.push(
      'Envoi SMS non configuré : les demandes de code par téléphone seront ' +
        `refusées. Renseignez AFRICASTALKING_USERNAME et AT_API_KEY dans Render (${channels.sms.provider}).`,
    );
  }

  return warnings;
}

module.exports = {
  sendVerificationCode,
  describeDeliveryChannels,
  deliveryWarnings,
};
