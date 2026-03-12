/**
 * Service d'envoi d'email et SMS
 * Configuration: SendGrid pour les emails, Africa's Talking pour les SMS
 */

const sgMail = require('@sendgrid/mail');

// Configuration Africa's Talking - Support des deux formats de variables d'environnement
let at = null;
const atApiKey = process.env.AT_API_KEY || process.env.AFRICASTALKING_API_KEY;
const atUsername = process.env.AFRICASTALKING_USERNAME || 'sandbox';

if (atApiKey) {
  const AfricasTalking = require('africastalking');
  at = AfricasTalking({
    apiKey: atApiKey,
    username: atUsername
  });
  console.log("✅ Africa's Talking configuré avec succès");
} else {
  console.log("⚠️ Africa's Talking non configuré - SMS simulés");
}

/**
 * Envoyer un code par email via SendGrid
 */
async function sendResetCodeByEmail(emailAddress, code, userName) {
  
  var htmlContent = '<html><body style="font-family: Arial; padding: 20px;">';
  htmlContent += '<div style="max-width: 600px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px;">';
  htmlContent += '<div style="text-align: center; background: linear-gradient(135deg, #2563EB, #1E40AF); padding: 20px; border-radius: 10px 10px 0 0;">';
  htmlContent += '<h1 style="color: white; margin: 0;">ECHELLE EG39</h1></div>';
  htmlContent += '<div style="padding: 30px;">';
  htmlContent += '<h2>Bonjour ' + (userName || 'Client') + ',</h2>';
  htmlContent += '<p>Vous avez demande la reinitialisation de votre mot de passe.</p>';
  htmlContent += '<p>Voici votre code de verification:</p>';
  htmlContent += '<div style="font-size: 32px; font-weight: bold; color: #2563EB; letter-spacing: 8px; text-align: center; padding: 20px; background: #f0f9ff; border-radius: 8px; margin: 20px 0;">' + code + '</div>';
  htmlContent += '<p>Ce code expire dans 15 minutes.</p>';
  htmlContent += '<p>Si vous n\'avez pas demande cette reinitialisation, ignorez cet email.</p>';
  htmlContent += '</div></div></body></html>';

  var textContent = 'ECHELLE EG39 - Reinitialisation de mot de passe\n\n';
  textContent += 'Bonjour ' + (userName || 'Client') + ',\n\n';
  textContent += 'Votre code de verification: ' + code + '\n\n';
  textContent += 'Ce code expire dans 15 minutes.\n\n';
  textContent += '2026 ECHELLE EG39 - Topographie BTP';

  // Verifier si SendGrid est configure
  if (!process.env.SENDGRID_API_KEY) {
    console.log('SendGrid non configure - simulation');
    console.log('[SIMULATION] Email a ' + emailAddress + ': Code ' + code);
    return { success: true, message: 'Email simule' };
  }

  sgMail.setApiKey(process.env.SENDGRID_API_KEY);

  var msg = {
    to: emailAddress,
    from: 'echelleeg39@gmail.com',
    subject: 'Reinitialisation mot de passe - ECHELLE EG39',
    text: textContent,
    html: htmlContent
  };

  try {
    await sgMail.send(msg);
    console.log('Email envoye a ' + emailAddress);
    return { success: true, message: 'Email envoye' };
  } catch (error) {
    console.error('Erreur SendGrid:', error);
    return { success: false, message: error.message };
  }
}

/**
 * Envoyer un code par SMS via Africa's Talking
 */
async function sendResetCodeBySMS(phone, code) {
  var message = 'ECHELLE EG39: Votre code est ' + code + '. Expire dans 15 min.';
  
  // Si Africa's Talking n'est pas configuré, simuler
  if (!at) {
    console.log('SMS non configure - simulation');
    console.log('[SIMULATION] SMS a ' + phone + ': Code ' + code);
    return { success: true, message: 'SMS simule' };
  }

  try {
    // Formater le numéro (enlever les espaces et ajouter le code pays si nécessaire)
    let formattedPhone = phone.replace(/\s/g, '');
    if (!formattedPhone.startsWith('+')) {
      // Pour le Togo: +228
      if (formattedPhone.startsWith('0')) {
        formattedPhone = '+228' + formattedPhone.substring(1);
      } else if (formattedPhone.startsWith('9') || formattedPhone.startsWith('7') || formattedPhone.startsWith('8')) {
        formattedPhone = '+228' + formattedPhone;
      }
    }

    console.log('📱 Envoi SMS a ' + formattedPhone + '...');
    
    const result = await at.SMS.send({
      to: [formattedPhone],
      message: message
    });
    
    console.log('✅ SMS envoye avec succes:', JSON.stringify(result));
    return { success: true, message: 'SMS envoye', data: result };
  } catch (error) {
    console.error("❌ Erreur Africa's Talking:", error);
    return { success: false, message: error.message };
  }
}

/**
 * Envoyer le code par le bon canal
 */
async function sendVerificationCode(contact, contactType, code, userName) {
  if (contactType === 'email') {
    return await sendResetCodeByEmail(contact, code, userName);
  } else {
    return await sendResetCodeBySMS(contact, code);
  }
}

module.exports = {
  sendResetCodeByEmail,
  sendResetCodeBySMS,
  sendVerificationCode
};

