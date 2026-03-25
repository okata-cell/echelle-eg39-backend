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
    from: 'okataolaniyi@gmail.com',
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

/**
 * Envoyer une notification de demande de location approuvée par email
 */
async function sendLocationApprovedEmail(emailAddress, userName, locationCode, appareilNom, dateDebut, dateFin, montantTotal) {
  var htmlContent = '<html><body style="font-family: Arial; padding: 20px;">';
  htmlContent += '<div style="max-width: 600px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px;">';
  htmlContent += '<div style="text-align: center; background: linear-gradient(135deg, #059669, #047857); padding: 20px; border-radius: 10px 10px 0 0;">';
  htmlContent += '<h1 style="color: white; margin: 0;">DEMANDE APPROUVÉE</h1></div>';
  htmlContent += '<div style="padding: 30px;">';
  htmlContent += '<h2>Bonjour ' + (userName || 'Client') + ',</h2>';
  htmlContent += '<p>Votre demande de location a été <strong>approuvée</strong>!</p>';
  htmlContent += '<div style="background: #f0fdf4; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #059669;">';
  htmlContent += '<p><strong>Code:</strong> ' + locationCode + '</p>';
  htmlContent += '<p><strong>Appareil:</strong> ' + appareilNom + '</p>';
  htmlContent += '<p><strong>Période:</strong> ' + dateDebut + ' au ' + dateFin + '</p>';
  htmlContent += '<p><strong>Montant total:</strong> ' + montantTotal + ' FCFA</p>';
  htmlContent += '</div>';
  htmlContent += '<p>Merci de votre confiance!</p>';
  htmlContent += '<p>2026 ECHELLE EG39 - Topographie BTP</p>';
  htmlContent += '</div></div></body></html>';

  var textContent = 'ECHELLE EG39 - Demande approuvée\n\n';
  textContent += 'Bonjour ' + (userName || 'Client') + ',\n\n';
  textContent += 'Votre demande de location a été approuvée!\n\n';
  textContent += 'Code: ' + locationCode + '\n';
  textContent += 'Appareil: ' + appareilNom + '\n';
  textContent += 'Période: ' + dateDebut + ' au ' + dateFin + '\n';
  textContent += 'Montant: ' + montantTotal + 'FCFA\n\n';
  textContent += '2026 ECHELLE EG39 - Topographie BTP';

  if (!process.env.SENDGRID_API_KEY) {
    console.log('[SIMULATION] Email approbation à ' + emailAddress + ': ' + locationCode);
    return { success: true, message: 'Email simulé' };
  }

  sgMail.setApiKey(process.env.SENDGRID_API_KEY);

  var msg = {
    to: emailAddress,
    from: 'okataolaniyi@gmail.com',
    subject: 'Votre demande de location a été approuvée - ECHELLE EG39',
    text: textContent,
    html: htmlContent
  };

  try {
    await sgMail.send(msg);
    console.log('Email approbation envoyé à ' + emailAddress);
    return { success: true, message: 'Email envoyé' };
  } catch (error) {
    console.error('Erreur SendGrid:', error);
    return { success: false, message: error.message };
  }
}

/**
 * Envoyer une notification de demande de location rejetée par email
 */
async function sendLocationRejectedEmail(emailAddress, userName, locationCode, appareilNom, raison) {
  var htmlContent = '<html><body style="font-family: Arial; padding: 20px;">';
  htmlContent += '<div style="max-width: 600px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px;">';
  htmlContent += '<div style="text-align: center; background: linear-gradient(135deg, #DC2626, #B91C1C); padding: 20px; border-radius: 10px 10px 0 0;">';
  htmlContent += '<h1 style="color: white; margin: 0;">DEMANDE REJETÉE</h1></div>';
  htmlContent += '<div style="padding: 30px;">';
  htmlContent += '<h2>Bonjour ' + (userName || 'Client') + ',</h2>';
  htmlContent += '<p>Votre demande de location a été <strong>rejetée</strong>.</p>';
  htmlContent += '<div style="background: #fef2f2; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #DC2626;">';
  htmlContent += '<p><strong>Code:</strong> ' + locationCode + '</p>';
  htmlContent += '<p><strong>Appareil:</strong> ' + appareilNom + '</p>';
  htmlContent += '<p><strong>Raison du rejet:</strong> ' + raison + '</p>';
  htmlContent += '</div>';
  htmlContent += '<p>Vous pouvez soumettre une nouvelle demande.</p>';
  htmlContent += '<p>2026 ECHELLE EG39 - Topographie BTP</p>';
  htmlContent += '</div></div></body></html>';

  var textContent = 'ECHELLE EG39 - Demande rejetée\n\n';
  textContent += 'Bonjour ' + (userName || 'Client') + ',\n\n';
  textContent += 'Votre demande de location a été rejetée.\n\n';
  textContent += 'Code: ' + locationCode + '\n';
  textContent += 'Appareil: ' + appareilNom + '\n';
  textContent += 'Raison: ' + raison + '\n\n';
  textContent += '2026 ECHELLE EG39 - Topographie BTP';

  if (!process.env.SENDGRID_API_KEY) {
    console.log('[SIMULATION] Email rejet à ' + emailAddress + ': ' + locationCode);
    return { success: true, message: 'Email simulé' };
  }

  sgMail.setApiKey(process.env.SENDGRID_API_KEY);

  var msg = {
    to: emailAddress,
    from: 'okataolaniyi@gmail.com',
    subject: 'Votre demande de location a été rejetée - ECHELLE EG39',
    text: textContent,
    html: htmlContent
  };

  try {
    await sgMail.send(msg);
    console.log('Email rejet envoyé à ' + emailAddress);
    return { success: true, message: 'Email envoyé' };
  } catch (error) {
    console.error('Erreur SendGrid:', error);
    return { success: false, message: error.message };
  }
}

module.exports = {
  sendResetCodeByEmail,
  sendResetCodeBySMS,
  sendVerificationCode,
  sendLocationApprovedEmail,
  sendLocationRejectedEmail
};

