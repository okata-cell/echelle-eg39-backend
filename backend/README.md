# 🏗️ ÉCHELLE EG39 - API Backend

API REST pour la gestion de l'application ÉCHELLE EG39 (Topographie & BTP)

## 📋 Table des matières

- [Technologies](#technologies)
- [Installation locale](#installation-locale)
- [Configuration](#configuration)
- [Migrations de base de données](#migrations)
- [API Endpoints](#api-endpoints)
- [Déploiement sur Render](#déploiement-sur-render)

## 🛠️ Technologies

- **Node.js** v18+
- **Express.js** - Framework web
- **PostgreSQL** - Base de données
- **JWT** - Authentification
- **bcryptjs** - Hachage des mots de passe

## 💻 Installation locale

```bash
# Installer les dépendances
npm install

# Copier le fichier d'environnement
cp .env.example .env

# Éditer .env avec vos propres valeurs
nano .env

# Lancer les migrations
npm run migrate

# Démarrer le serveur en mode développement
npm run dev

# Ou en mode production
npm start
```

## ⚙️ Configuration

Créez un fichier `.env` à la racine du dossier `backend/` avec les variables suivantes :

```env
PORT=3000
NODE_ENV=development
DATABASE_URL=postgresql://user:password@localhost:5432/echelle_eg39
JWT_SECRET=votre_secret_jwt_tres_long_et_securise
ALLOWED_ORIGINS=http://localhost:*
ADMIN_EMAIL=admin@echelle-eg39.com
ADMIN_PASSWORD=Admin123!
ADMIN_PHONE=+22890014329
# Pour les PDF de devis (valeurs conservées uniquement dans l’environnement, jamais dans Git)
R2_ACCOUNT_ID=<identifiant_de_compte_cloudflare>
R2_ACCESS_KEY_ID=<identifiant_api_r2>
R2_SECRET_ACCESS_KEY=<secret_api_r2>
R2_BUCKET_NAME=<nom_du_bucket_prive>
```

## 🗄️ Migrations

```bash
# Exécuter les migrations (créer les tables + données initiales)
npm run migrate
```

Cela créera :
- Les tables : `users`, `appareils`, `demandes_achat`, `locations`, `prolongations`, `clients`
- Un compte admin par défaut
- 9 appareils de démonstration

## 📡 API Endpoints

### Authentification (`/api/auth`)

#### POST `/api/auth/register`
Inscription d'un nouvel utilisateur

**Body:**
```json
{
  "firstName": "Jean",
  "lastName": "Dupont",
  "email": "jean@example.com",
  "phone": "+22890000000",
  "password": "Password123"
}
```

**Response:**
```json
{
  "message": "Inscription réussie",
  "user": {
    "id": 1,
    "firstName": "Jean",
    "lastName": "Dupont",
    "email": "jean@example.com",
    "phone": "+22890000000",
    "role": "client"
  },
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

#### POST `/api/auth/login`
Connexion

**Body:**
```json
{
  "identifier": "jean@example.com",
  "password": "Password123"
}
```

**Response:**
```json
{
  "message": "Connexion réussie",
  "user": { ... },
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

#### GET `/api/auth/me`
Obtenir le profil de l'utilisateur connecté

**Headers:**
```
Authorization: Bearer <token>
```

### Appareils (`/api/appareils`)

#### GET `/api/appareils`
Liste des appareils (public)

**Query params:**
- `type`: Filtrer par type
- `disponible`: true/false

#### POST `/api/appareils`
Ajouter un appareil (Admin seulement)

**Headers:**
```
Authorization: Bearer <admin_token>
```

**Body:**
```json
{
  "nom": "GPS e-survey E900",
  "type": "GPS",
  "imageUrl": "https://...",
  "prixLocation": 30000,
  "prixVente": 3000000
}
```

#### PUT `/api/appareils/:id`
Modifier un appareil (Admin)

#### DELETE `/api/appareils/:id`
Supprimer un appareil (Admin)

### Demandes d'achat (`/api/demandes`)

#### GET `/api/demandes`
Liste des demandes
- Admin : Toutes les demandes
- Client : Ses demandes seulement

**Query params:**
- `statut`: en_attente, approuvee, rejetee, livree

#### POST `/api/demandes`
Créer une demande d'achat

**Body:**
```json
{
  "appareilId": 1,
  "quantite": 2
}
```

#### PATCH `/api/demandes/:id/statut`
Modifier le statut (Admin)

**Body:**
```json
{
  "statut": "approuvee",
  "commentaire": "Approuvé, livraison prévue demain"
}
```

### Locations (`/api/locations`)

#### GET `/api/locations`
Liste des locations

#### POST `/api/locations`
Créer une location

**Body:**
```json
{
  "appareilId": 1,
  "dateDebut": "2025-01-15",
  "dateFin": "2025-01-25"
}
```

#### PATCH `/api/locations/:id/terminer`
Terminer une location (Admin)

### Prolongations (`/api/prolongations`)

#### GET `/api/prolongations`
Liste des prolongations

#### POST `/api/prolongations`
Créer une prolongation

**Body:**
```json
{
  "locationId": 1,
  "nouvelleDateFin": "2025-02-05"
}
```

#### PATCH `/api/prolongations/:id/payer`
Marquer comme payée (Admin)

## 🚀 Déploiement sur Render

### 1. Créer un compte Render

Allez sur [render.com](https://render.com) et créez un compte gratuit.

### 2. Créer une base de données PostgreSQL

1. Dans Render Dashboard, cliquez sur **"New +"**
2. Sélectionnez **"PostgreSQL"**
3. Configurez:
   - Name: `echelle-eg39-db`
   - Database: `echelle_eg39`
   - User: `echelle_user`
   - Region: Choisissez le plus proche
   - Plan: **Free** (gratuit)
4. Cliquez sur **"Create Database"**
5. **Copiez l'URL interne** (Internal Database URL)

### 3. Créer le Web Service

1. Dans Render Dashboard, cliquez sur **"New +"**
2. Sélectionnez **"Web Service"**
3. Connectez votre repository GitHub
4. Pour le service configuré par le `render.yaml` à la racine du dépôt, conservez la racine du dépôt comme répertoire de travail ; ses commandes exécutent `cd backend && npm install` puis `cd backend && npm start`.
5. Sous "Advanced", ajoutez les variables d'environnement:
   ```
   NODE_ENV=production
   DATABASE_URL=<internal_database_url_copiée>
   JWT_SECRET=votre_secret_jwt_production_tres_securise
   ALLOWED_ORIGINS=https://votre-app.com
   ADMIN_EMAIL=admin@echelle-eg39.com
   ADMIN_PASSWORD=Admin123!
   ADMIN_PHONE=+22890014329
   ```
6. Cliquez sur **"Create Web Service"**

### 4. Lancer les migrations

Une fois le déploiement terminé :

1. Dans Render Dashboard, ouvrez votre service
2. Allez dans l'onglet **"Shell"**
3. Exécutez:
   ```bash
   npm run migrate
   ```

### 5. Tester l'API

Votre API est maintenant disponible à l'URL :
```
https://echelle-eg39-api.onrender.com
```

Testez :
```bash
curl https://echelle-eg39-api.onrender.com/health
```

## 📄 PDF privés des devis (Cloudflare R2)

Le backend génère automatiquement le PDF quand l’admin émet une offre, puis le stocke dans un bucket R2 privé. La base PostgreSQL conserve uniquement la clé objet opaque. L’application ne crée aucun lien public permanent : l’admin ou le client propriétaire demande une URL signée HTTPS de lecture, valable 5 minutes, après contrôle du JWT et de la propriété du devis.

### Configuration Cloudflare et Render

1. Créez un bucket Cloudflare R2 privé (ne pas activer l’accès public).
2. Créez une clé API S3 limitée au bucket, avec droits de lecture, écriture et suppression d’objets. Gardez l’identifiant de compte, l’ID de clé et le secret hors du dépôt.
3. Dans Render Dashboard, ouvrez le service `echelle-eg39-backend-1` et ajoutez `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` et `R2_BUCKET_NAME` comme variables secrètes. Les noms sont déclarés `sync: false` dans le `render.yaml` racine ; leurs valeurs doivent être ajoutées dans le Dashboard.
4. Redéployez le backend. La migration idempotente ajoute `document_storage_key` au démarrage. Aucun PDF n’est écrit sur le disque de Render.
5. Émettez un devis de test et vérifiez qu’un admin et le client propriétaire peuvent l’ouvrir ; qu’un autre client reçoit une 404 ; puis vérifiez qu’une nouvelle URL est générée après expiration.

Si ces variables manquent ou si R2 est indisponible, l’émission du devis échoue avec une erreur de service au lieu de stocker le document publiquement ou localement. Les anciennes offres avec `document_url` restent accessibles après authentification et contrôle de propriété. Les URL R2 signées sont des jetons temporaires : ne pas les journaliser, les enregistrer en base, ni les partager publiquement.

## 📝 Notes importantes

- **Render Free Tier** : Le service s'endort après 15 minutes d'inactivité. Premier appel = lent (cold start).
- **Upgrade** : Pour production, passez au plan payant pour éviter les cold starts.
- **Base de données** : Plan gratuit = 90 jours, puis payant ou données supprimées.

## 🔒 Sécurité

- Ne commitez JAMAIS le fichier `.env`
- Changez le `JWT_SECRET` en production
- Utilisez HTTPS en production
- Activez CORS seulement pour vos domaines

## 📞 Support

Pour toute question : contact@echelle-eg39.com