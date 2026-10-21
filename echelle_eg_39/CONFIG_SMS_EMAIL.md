# 📧📱 Guide de configuration SMS et Email Réels

Ce guide explique comment configurer l'envoi **réel** de SMS et d'emails pour l'application ÉCHELLE EG39.

## 📋 Prérequis

Le service utilise :
- **SendGrid** pour les emails
- **Africa's Talking** pour les SMS

**SendGrid** propose actuellement une formule d’essai gratuite, mais ses limites, conditions d’activation et exigences de facturation peuvent dépendre du compte et évoluer. Ne supposez pas que l’envoi restera gratuit ou illimité en production : vérifiez les conditions affichées dans votre compte et sur la [page officielle des tarifs](https://www.twilio.com/en-us/products/email-api/pricing). La configuration gratuite est adaptée aux essais; pour une utilisation en production, prévoyez les étapes de validation d’expéditeur et d’authentification du domaine décrites ci-dessous.

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
4. Donnez un nom à la clé (ex. `ECHELLE EG39 - production`).
5. Choisissez **Restricted Access** et accordez uniquement **Mail Send → Full Access** (pas les permissions API inutiles).
6. Cliquez sur **Create & View** et copiez la clé immédiatement : SendGrid ne la réaffichera pas.
7. Gardez-la secrète. Ne la collez jamais dans le code, un ticket ou GitHub; ajoutez-la uniquement dans les variables protégées de Render.

### Étape 1.3 : Authentifier l’expéditeur (requis)

L’adresse `From` envoyée par l’application doit être vérifiée dans SendGrid. **Pour la production, authentifiez un domaine que vous possédez**; la vérification d’un seul expéditeur est plus rapide, mais SendGrid la présente comme une option de test.

**Option recommandée pour la production — authentification du domaine**

1. Dans SendGrid, ouvrez **Settings → Sender Authentication → Authenticate Your Domain**.
2. Choisissez le fournisseur DNS qui héberge votre domaine, ou l’option manuelle.
3. Saisissez le domaine que vous contrôlez (par exemple `echelle-eg39.com`) et suivez l’assistant.
4. Ajoutez **exactement** les enregistrements DNS affichés par SendGrid auprès du fournisseur de domaine. Ne remplacez pas vos enregistrements SPF/DKIM existants; vérifiez les instructions SendGrid si un SPF existe déjà.
5. Revenez dans SendGrid et cliquez sur **Verify**. La propagation DNS peut prendre un certain temps.
6. Utilisez ensuite une adresse sur ce domaine, par exemple `noreply@echelle-eg39.com`, comme expéditeur.

**Pour un essai rapide seulement — expéditeur unique**

1. Ouvrez **Settings → Sender Authentication → Verify a Single Sender**.
2. Indiquez une adresse e-mail à laquelle vous avez accès, par exemple votre adresse professionnelle réelle.
3. Confirmez le lien reçu dans cette boîte.
4. Dans Render, configurez comme expéditeur **exactement cette même adresse**.

Une adresse inventée comme `noreply@echelle-eg39.com` ne fonctionnera pas tant qu’elle n’est pas autorisée dans votre compte SendGrid. L’authentification de domaine exige l’accès à ses paramètres DNS; ne choisissez pas un domaine que vous ne contrôlez pas.

SendGrid peut également demander la vérification du compte (e-mail, authentification du domaine, 2FA et parfois une méthode de paiement) avant d’autoriser l’envoi. Suivez les exigences affichées dans votre tableau de bord; sa documentation indique que l’ajout d’un moyen de paiement lors du déblocage ne le facture pas immédiatement.

---

## 2️⃣ Configuration d'Africa's Talking (SMS)

### Étape 2.1 : Créer l’application Live

1. Crée un compte sur [Africa’s Talking](https://account.africastalking.com/auth/register) et confirme l’adresse e-mail.
2. Ouvre l’environnement **Live** (tableau de bord vert), puis sélectionne l’équipe concernée.
3. Clique sur **Create App**. Donne un nom à l’application, choisis un **username** et sélectionne le pays demandé, puis enregistre.
4. Ouvre l’application Live et note son username : c’est cette valeur qui ira dans `AFRICASTALKING_USERNAME` (ce n’est pas ton adresse de connexion).

Ne confonds pas l’application Live avec le Sandbox : le Sandbox utilise le username `sandbox` et ses messages sont visibles dans le simulateur, pas sur les téléphones. Le backend de ce projet appelle l’endpoint SMS Live.

### Étape 2.2 : Générer la clé Live

1. Dans le tableau de bord de l’application Live, ouvre **Settings → API Key**.
2. Saisis ton mot de passe puis clique sur **Generate**.
3. Copie et conserve la clé tout de suite; elle est secrète et ne doit pas être ajoutée au code ou à Git.
4. Attends quelques minutes avant le premier test.

### Étape 2.3 : Faire approuver le Sender ID

Africa’s Talking demande un **Sender ID** enregistré/approuvé pour envoyer des SMS. Demande-le depuis ton compte ou auprès de son support pour les destinations ciblées; les exigences dépendent du pays. Pour le Togo, confirme directement avec Africa’s Talking quel Sender ID est accepté et s’il faut un shortcode. Le nom approuvé exactement doit être utilisé dans `AFRICASTALKING_SENDER_ID`.

Un compte peut aussi devoir être vérifié par une première interaction avec l’API et avoir un solde Live suffisant avant l’envoi réel. Les SMS Live peuvent être facturés; vérifie les tarifs et ton solde dans le tableau de bord.

---

## 3️⃣ Configuration des variables d'environnement

### Fichier `.env` (Backend)

Ajoutez ou modifiez `backend/backend/.env` (ne commitez jamais ce fichier) :

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
SENDGRID_FROM_EMAIL=noreply@votre-domaine-verifie.com

# =====================
# 📱 SMS (Africa's Talking - Live)
# =====================
# Clé et username de l'application Live (pas les identifiants Sandbox)
AT_API_KEY=votre_cle_api_live
AFRICASTALKING_USERNAME=username_de_votre_app_live
# Sender ID approuvé par Africa's Talking pour le pays destinataire
AFRICASTALKING_SENDER_ID=VOTRE_SENDER_ID

# Alternative acceptée à AT_API_KEY, à utiliser seulement si AT_API_KEY est absent :
# AFRICASTALKING_API_KEY=votre_cle_api_live
```

### Variables de production dans Render

Dans le tableau de bord Render, ouvrez le service `echelle-eg39-backend-1` → **Environment**. Ajoutez ces deux variables avec **Add Environment Variable** (ou **Bulk Edit**) :

| Nom | Valeur |
|---|---|
| `SENDGRID_API_KEY` | La clé API SendGrid secrète créée à l’étape 1.2 |
| `SENDGRID_FROM_EMAIL` | L’adresse `From` exacte dont le domaine est authentifié, par exemple `noreply@votre-domaine.com` |
| `AT_API_KEY` | La clé API de l’application Africa’s Talking Live |
| `AFRICASTALKING_USERNAME` | Le username exact de l’application Live (pas `sandbox`) |
| `AFRICASTALKING_SENDER_ID` | Le Sender ID approuvé pour l’envoi dans le pays destinataire |

`AFRICASTALKING_API_KEY` est accepté comme alias si `AT_API_KEY` n’est pas renseigné; ne configure pas deux clés différentes. Enregistre les changements et attends le redémarrage/redéploiement du service. `SENDGRID_FROM_EMAIL` est préféré; si absent, le backend utilise `ADMIN_EMAIL`, qui doit alors être une adresse vérifiée dans SendGrid. Les entrées `sync: false` de `render.yaml` déclarent les noms sans enregistrer les valeurs secrètes dans Git.

Pour le développement local uniquement, placez les valeurs dans `backend/backend/.env` (ce fichier est ignoré par Git), puis redémarrez le backend. Ne mettez jamais la vraie clé dans `.env.example`.

---

## 4️⃣ Redémarrer le serveur

Après avoir configuré les variables :

```bash
cd backend/backend
npm run dev
```

Le démarrage affiche le serveur et l’environnement. Il ne valide pas les identifiants SendGrid; testez avec une adresse existante, puis vérifiez l’activité e-mail dans SendGrid et les éventuelles erreurs dans les logs Render.

---

## 5️⃣ Tester l'envoi réel

### Test Email

Utilisez une adresse e-mail **déjà associée à un compte ÉCHELLE EG39** (le serveur n’envoie le code que pour un compte existant) :

```bash
curl -X POST https://votre-api.onrender.com/api/auth/forgot-password \
  -H "Content-Type: application/json" \
  -d '{
    "contact": "adresse-d-un-compte-existant@example.com",
    "contactType": "email"
  }'
```

Une réponse `success: true` peut être générique si aucun compte ne correspond; elle ne prouve donc pas à elle seule qu’un e-mail a été envoyé. En production, une erreur de livraison renvoie `503`. Vérifiez les journaux Render et l’activité e-mail SendGrid; l’acceptation par l’API ne garantit pas l’arrivée en boîte de réception (vérifiez aussi les indésirables).

### Test SMS

Utilise le numéro au format international, associé à un compte existant dans l’application. Avec les identifiants Live configurés, ce test envoie un SMS réel susceptible d’être facturé.

```bash
curl -X POST https://votre-api.onrender.com/api/auth/forgot-password \
  -H "Content-Type: application/json" \
  -d '{
    "contact": "+22890000000",
    "contactType": "phone"
  }'
```

---

## 📊 Vérification des envois

- Dans Render, ouvre **Logs** et cherche les lignes `[SMS]`. Elles indiquent le statut renvoyé par Africa’s Talking, le coût et l’identifiant de message; elles n’affichent ni le numéro ni l’OTP.
- Les statuts `100`, `101` ou `102` signifient que le message a été traité, transmis ou mis en file d’attente, **pas qu’il est arrivé sur le téléphone**. Une confirmation de livraison demande un rapport de livraison (DLR) et son callback.
- `402` indique généralement un Sender ID/shortcode invalide ou non approuvé; `405` indique un solde insuffisant. Vérifie aussi le tableau de bord Africa’s Talking.
- Le code échoue volontairement si les identifiants ou `AFRICASTALKING_SENDER_ID` sont absents en production.

### Vérification de l’envoi e-mail

- Dans Render, ouvrez **Logs** et cherchez `Erreur envoi code` en cas d’échec. Le backend renvoie `503` si l’envoi échoue en production.
- Dans SendGrid, consultez **Email Activity** pour voir si l’e-mail a été accepté, livré, rejeté ou bloqué.
- `202 Accepted` de l’API indique que SendGrid a accepté la requête, pas que l’e-mail est arrivé dans la boîte de réception. Vérifiez également les courriers indésirables et l’adresse destinataire.
- Ne copiez pas de clé API ni de code OTP dans les tickets ou les logs partagés.

---

## 💰 Coûts

### SendGrid
- Une **formule d’essai gratuite** est affichée par SendGrid actuellement. Les limites et conditions de déblocage peuvent varier selon le compte et changer; vérifiez-les dans le tableau de bord et sur la [page officielle des tarifs](https://www.twilio.com/en-us/products/email-api/pricing).
- Ne considérez pas l’essai comme une offre gratuite permanente pour la production. SendGrid peut demander des vérifications et une méthode de paiement pour débloquer l’envoi; consultez les [conditions de vérification du compte](https://www.twilio.com/docs/sendgrid/ui/account-and-settings/verifying-your-account).

### Africa's Talking
- **Sandbox** : gratuit; les messages sont reçus dans le simulateur, pas sur les téléphones.
- **Live** : les SMS sont facturés. Vérifie le tarif Togo et le solde minimum affichés dans ton compte Africa's Talking; les prix peuvent varier selon le pays et le volume.

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
| `401` / `Invalid credentials` | Vérifie que l’API key et le username correspondent à la même application Live. |
| `402` / `InvalidSenderId` | Vérifie que le Sender ID est approuvé pour le pays destinataire et correspond à `AFRICASTALKING_SENDER_ID`. |
| `403` / `InvalidPhoneNumber` | Vérifie le format international du numéro, par exemple `+228…`. |
| `405` / `InsufficientBalance` | Vérifie le solde/crédit du compte Africa’s Talking Live. |

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

