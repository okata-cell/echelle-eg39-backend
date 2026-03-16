# 📧📱 Guide de configuration SMS et Email Réels

Ce guide explique comment configurer l'envoi **réel** de SMS et d'emails pour l'application ÉCHELLE EG39.

## 📋 Prérequis

Le service utilise :
- **SendGrid** pour les emails
- **Africa's Talking** pour les SMS

Les deux services ont des plans gratuits généreux.

---

## 1️⃣ Configuration de SendGrid (Emails)

### Étape 1.1 : Créer un compte SendGrid

1. Allez sur [sendgrid.com](https://sendgrid.com)
2. Cliquez sur "Sign Up" ou "Start for Free"
3. Créez un compte avec votre email professionnel
4. Vérifiez votre adresse email

### Étape 1.2 : Créer une API Key

1. Connectez-vous à votre compte SendGrid
2. Allez dans **Settings** → **API Keys**
3. Cliquez sur **Create API Key**
4. Donnez un nom à votre clé (ex: "ECHELLE EG39")
5. Sélectionnez **Full Access** ou **Restricted Access** avec les permissions nécessaires :
   - **Mail Send** → Full Access
6. Cliquez sur **Create & View**
7. **IMPORTANT** : Copiez la clé affichée (elle ne sera visible qu'une seule fois!)

### Étape 1.3 : Configurer l'expéditeur vérifié

1. Allez dans **Settings** → **Sender Authentication**
2. Cliquez sur **Verify a Single Sender**
3. Remplissez les informations :
   - **From Email Address** : `noreply@echelle-eg39.com` (ou votre domaine)
   - **From Name** : ECHELLE EG39
   - **Address** : Votre adresse professionnelle
   - **City** : Lomé
   - **Country** : Togo
4. Cliquez sur **Create**
5. Vérifiez votre boîte email et cliquez sur le lien de confirmation

> **Note** : Si vous n'avez pas de domaine personnalisé, vous pouvez utiliser l'expéditeur par défaut de SendGrid ou vérifier un domaine gratuit.

---

## 2️⃣ Configuration d'Africa's Talking (SMS)

### Étape 2.1 : Créer un compte Africa's Talking

1. Allez sur [africastalking.com](https://africastalking.com)
2. Cliquez sur "Sign Up"
3. Sélectionnez le pays **Togo**
4. Remplissez le formulaire avec :
   - Votre numéro de téléphone togolais
   - Votre nom et email
5. Validez votre compte via SMS

### Étape 2.2 : Récupérer vos credentials

1. Connectez-vous à votre compte [sandbox.africastalking.com](https://sandbox.africastalking.com)
2. Allez dans **Settings** → **API Keys**
3. Votre **Username** est affiché en haut (généralement "sandbox" pour le compte gratuit)
4. Pour obtenir l'API Key :
   - Allez dans **Settings** → **API Key**
   - Cliquez sur "Generate new API Key"
   - Copiez la clé (visible une seule fois!)

### Étape 2.3 : Configuration du compte (Important!)

Par défaut, le compte sandbox permet uniquement d'envoyer des SMS à des numéros vérifiés. Pour tester :

1. Allez dans **SMS** → **Testers**
2. Ajoutez votre numéro de téléphone pour les tests

Pour passer en **production** (envoyer des SMS à tout le monde) :
- Soumettez votre demande dans **Settings** → **Production**
- Attendez l'approbation (généralement rapide pour le Togo)

---

## 3️⃣ Configuration des variables d'environnement

### Fichier `.env` (Backend)

Ajoutez ou modifiez le fichier `backend/.env` :

```env
# =====================
# CONFIGURATION SERVEUR
# =====================
PORT=3000
NODE_ENV=development

# =====================
# BASE DE DONNÉES
# =====================
DATABASE_URL=postgresql://user:password@localhost:5432/echelle_eg39

# =====================
# AUTHENTIFICATION
# =====================
JWT_SECRET=votre_secret_jwt_tres_long_et_securise

# =====================
# CORS
# =====================
ALLOWED_ORIGINS=http://localhost:*,https://votre-domaine.com

# =====================
# ADMIN PAR DÉFAUT
# =====================
ADMIN_EMAIL=admin@echelle-eg39.com
ADMIN_PASSWORD=Admin123!
ADMIN_PHONE=+22890014329

# =====================
# 📧 EMAIL (SendGrid)
# =====================
SENDGRID_API_KEY=SG.votre_cle_api_ici

# =====================
# 📱 SMS (Africa's Talking)
# =====================
# Option 1 : Variable standard
AT_API_KEY=votre_api_key_africas_talking

# Option 2 : Variable alternative
# AFRICASTALKING_API_KEY=votre_api_key_africas_talking
AFRICASTALKING_USERNAME=sandbox
```

---

## 4️⃣ Redémarrer le serveur

Après avoir configuré les variables :

```bash
cd backend
npm run dev
```

Vous devriez voir ces messages au démarrage :

```
✅ Africa's Talking configuré avec succès
✅ SendGrid configuré (si la clé est présente)
```

---

## 5️⃣ Tester l'envoi réel

### Test Email

Utilisez Postman ou curl :

```bash
curl -X POST https://votre-api.onrender.com/api/auth/forgot-password \
  -H "Content-Type: application/json" \
  -d '{
    "contact": "votre-email@test.com",
    "contactType": "email"
  }'
```

### Test SMS

```bash
curl -X POST https://votre-api.onrender.com/api/auth/forgot-password \
  -H "Content-Type: application/json" \
  -d '{
    "contact": "+22890000000",
    "contactType": "phone"
  }'
```

---

## 📊 Vérification des logs

Les logs console vous indiqueront le statut :

| Message | Signification |
|---------|---------------|
| `✅ Africa's Talking configuré avec succès` | SMS réel activé |
| `⚠️ Africa's Talking non configuré - SMS simulés` | Clé API manquante |
| `📱 Envoi SMS a +228...` | SMS en cours d'envoi |
| `✅ SMS envoyé avec succès` | SMS delivered! |
| `❌ Erreur Africa's Talking:` | Erreur (voir le message) |

---

## 💰 Coûts

### SendGrid
- **Plan gratuit** : 100 emails/jour, illimités pendant 30 jours pour les nouveaux comptes
- **Essai gratuite** : 5,000 emails gratuits les 30 premiers jours

### Africa's Talking
- **Sandbox** : SMS gratuits vers numéros vérifiés
- **Production** : ~5 CFA par SMS (Togo)
- **Crédit minimum** : 500 CFA pour démarrer

---

## 🔧 Dépannage

### Erreurs SendGrid courantes

| Erreur | Solution |
|--------|----------|
| `401 Unauthorized` | Clé API incorrecte ou expirée |
| `400 Bad Request` | Sender email non vérifié |
| `Rate limit exceeded` | Limite du plan gratuit atteinte |

### Erreurs Africa's Talking

| Erreur | Solution |
|--------|----------|
| `Invalid credentials` | Username ou API key incorrect |
| `Phone number not verified` | Ajoutez le numéro dans les testeurs sandbox |
| `Not Approved` | Demandez l'approbation production |

---

## 📞 Support

- **SendGrid** : [support.sendgrid.com](https://support.sendgrid.com)
- **Africa's Talking** : support@africastalking.com
- **Application** : Configurez les variables et redémarrez le serveur!

---

## ✅ Checklist finale

- [ ] Compte SendGrid créé et vérifié
- [ ] API Key SendGrid générée
- [ ] Sender vérifié dans SendGrid
- [ ] Compte Africa's Talking créé
- [ ] API Key Africa's Talking récupérée
- [ ] Variables ajoutées dans `.env`
- [ ] Serveur redémarré
- [ ] Messages "configuré avec succès" visibles
- [ ] Test d'envoi réel effectué

