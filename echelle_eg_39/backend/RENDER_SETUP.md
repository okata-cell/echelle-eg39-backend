# 🚀 Guide de Configuration Render - ÉCHELLE EG39 Backend

Ce guide vous aide à configurer correctement votre application sur Render avec PostgreSQL.

---

## 📋 ÉTAPE 1 : Créer une Base de Données PostgreSQL sur Render

### 1.1 Accéder à Render Dashboard
1. Allez sur [https://dashboard.render.com](https://dashboard.render.com)
2. Connectez-vous à votre compte

### 1.2 Créer la Base de Données
1. Cliquez sur **"New +"** en haut à droite
2. Sélectionnez **"PostgreSQL"**
3. Remplissez les informations :
   - **Name** : `echelle-eg39-db` (ou un nom de votre choix)
   - **Database** : `echelle_eg39` (nom de la base)
   - **User** : `echelle_eg39_user` (nom d'utilisateur)
   - **Region** : Choisissez la région la plus proche (ex: Frankfurt pour l'Europe)
   - **PostgreSQL Version** : Dernière version stable (16 recommandée)
   - **Plan** : 
     - **Free** (pour tester) - **ATTENTION : se supprime après 90 jours d'inactivité**
     - **Starter ($7/mois)** - Recommandé pour production

4. Cliquez sur **"Create Database"**

### 1.3 Attendre la Création
- ⏳ La création prend **2-5 minutes**
- Le statut passera de "Creating..." à "Available"
- ✅ Quand c'est vert "Available", c'est prêt !

---

## 📋 ÉTAPE 2 : Récupérer l'URL de Connexion DATABASE_URL

### 2.1 Copier l'URL Interne
1. Une fois la base créée, cliquez dessus dans votre Dashboard
2. Allez dans l'onglet **"Info"** ou **"Connect"**
3. Cherchez la section **"Connections"**
4. Copiez l'**Internal Database URL** (commence par `postgresql://`)

**Format de l'URL :**
```
postgresql://username:password@hostname:port/database
```

**Exemple :**
```
postgresql://echelle_eg39_user:AbCdEf123456@dpg-abc123xyz.frankfurt-postgres.render.com:5432/echelle_eg39
```

> ⚠️ **IMPORTANT** : Utilisez l'**Internal Database URL** (plus rapide et gratuit), pas l'External URL.

---

## 📋 ÉTAPE 3 : Configurer les Variables d'Environnement sur Render

### 3.1 Accéder au Web Service
1. Retournez au **Dashboard Render**
2. Cliquez sur votre **Web Service** backend (celui qui exécute votre API Node.js)

### 3.2 Ajouter les Variables d'Environnement
1. Allez dans **"Environment"** (menu de gauche)
2. Cliquez sur **"Add Environment Variable"**
3. Ajoutez ces 3 variables **UNE PAR UNE** :

#### Variable 1 : DATABASE_URL
- **Key** : `DATABASE_URL`
- **Value** : Collez l'URL PostgreSQL copiée à l'étape 2.1
- Exemple : `postgresql://echelle_eg39_user:AbCdEf123456@dpg-abc123xyz.frankfurt-postgres.render.com:5432/echelle_eg39`

#### Variable 2 : JWT_SECRET
- **Key** : `JWT_SECRET`
- **Value** : Une chaîne aléatoire sécurisée (minimum 32 caractères)
- Exemple : `echelle_eg39_super_secret_jwt_key_2024_production_secure_1234567890`

> 💡 **Comment générer un JWT_SECRET sécurisé ?**
> - Option 1 : Utilisez un générateur en ligne : [https://randomkeygen.com/](https://randomkeygen.com/)
> - Option 2 : Dans votre terminal local : `node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"`

#### Variable 3 : NODE_ENV
- **Key** : `NODE_ENV`
- **Value** : `production`

#### Variables optionnelles (admin par défaut) :

##### ADMIN_EMAIL
- **Key** : `ADMIN_EMAIL`
- **Value** : `admin@echelle-eg39.com` (ou votre email admin)

##### ADMIN_PASSWORD
- **Key** : `ADMIN_PASSWORD`
- **Value** : `Admin123!` (ou votre mot de passe sécurisé)

##### ADMIN_PHONE
- **Key** : `ADMIN_PHONE`
- **Value** : `+22890014329` (ou votre numéro)

### 3.3 Sauvegarder
- Cliquez sur **"Save Changes"**
- ⚠️ Render va **automatiquement redémarrer** votre service

---

## 📋 ÉTAPE 4 : Vérifier que les Migrations s'Exécutent

### 4.1 Vérifier les Logs
1. Dans votre Web Service, allez dans **"Logs"** (menu de gauche)
2. Attendez que le service redémarre (1-2 minutes)
3. Cherchez dans les logs :

**✅ Messages de SUCCÈS à voir :**
```
✅ Connecté à la base de données PostgreSQL
✅ Migration réussie !
📧 Admin créé: admin@echelle-eg39.com
🔑 Mot de passe: Admin123!
🚀 Serveur démarré sur le port 3000
```

**❌ Messages d'ERREUR possibles :**

#### Erreur 1 : DATABASE_URL manquante
```
❌ Erreur PostgreSQL: Connection string is not defined
```
**Solution** : Retournez à l'étape 3 et ajoutez DATABASE_URL

#### Erreur 2 : JWT_SECRET manquant
```
❌ JWT_SECRET not defined
```
**Solution** : Retournez à l'étape 3 et ajoutez JWT_SECRET

#### Erreur 3 : Connexion PostgreSQL échoue
```
❌ ECONNREFUSED
❌ Connection timeout
```
**Solutions** :
- Vérifiez que la base de données est bien "Available" (pas "Creating")
- Vérifiez l'URL copiée (pas d'espaces, URL complète)
- Utilisez l'**Internal URL**, pas l'External

---echelle_eg39_super_secret_jwt_production_2024_secure_key_abcdef123456

## 📋 ÉTAPE 5 : Vérifier que les Tables sont Créées

### 5.1 Se Connecter à la Base de Données
1. Dans votre PostgreSQL Database sur Render
2. Allez dans **"Connect"** (menu de gauche)
3. Cliquez sur **"External Connection"** → **"PSQL Command"**
4. Copiez la commande (ressemble à ça) :
```bash
PGPASSWORD=motdepasse psql -h hostname -U username database
```

### 5.2 Exécuter dans le Terminal Local
1. Ouvrez votre terminal sur votre ordinateur
2. Collez la commande PSQL et appuyez sur Entrée
3. Vous serez connecté à votre base PostgreSQL

### 5.3 Vérifier les Tables
Dans le terminal PSQL, tapez :

```sql
-- Lister toutes les tables
\dt
```

**✅ Vous devez voir ces 6 tables :**
- `users`
- `appareils`
- `demandes_achat`
- `locations`
- `prolongations`
- `clients`

**Vérifier la table users :**
```sql
-- Voir la structure de la table users
\d users

-- Compter les utilisateurs
SELECT COUNT(*) FROM users;

-- Voir l'admin par défaut
SELECT email, role FROM users WHERE role = 'admin';
```

**✅ Résultat attendu :**
```
 email                    | role
--------------------------+-------
 admin@echelle-eg39.com   | admin
```

### 5.4 Quitter PSQL
```sql
\q
```

---

## 📋 ÉTAPE 6 : Tester l'API depuis le Navigateur

### 6.1 Tester l'Endpoint de Santé
Ouvrez dans votre navigateur :
```
https://echelle-eg39-backend.onrender.com/health
```

**✅ Réponse attendue :**
```json
{
  "status": "OK",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

### 6.2 Tester l'Inscription
Utilisez un outil comme **Postman** ou **curl** :

```bash
curl -X POST https://echelle-eg39-backend.onrender.com/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "Test",
    "lastName": "User",
    "email": "test@example.com",
    "phone": "+22890123456",
    "password": "Test123"
  }'
```

**✅ Réponse attendue (201 Created) :**
```json
{
  "message": "Inscription réussie",
  "user": {
    "id": 2,
    "firstName": "Test",
    "lastName": "User",
    "email": "test@example.com",
    "phone": "+22890123456",
    "role": "client"
  },
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

---

## 🔧 DÉPANNAGE : Problèmes Courants

### ❌ Problème 1 : "Erreur serveur" dans l'application
**Causes possibles :**
- DATABASE_URL manquante ou incorrecte
- JWT_SECRET manquant
- Base de données pas encore créée

**Solutions :**
1. Vérifiez les variables d'environnement (Étape 3)
2. Regardez les logs du serveur (Étape 4)
3. Vérifiez que la base est "Available"

---

### ❌ Problème 2 : "Email ou téléphone déjà utilisé"
**Cause :** Vous essayez de créer un compte avec un email/téléphone déjà enregistré

**Solutions :**
1. Utilisez un autre email/téléphone
2. Ou connectez-vous au lieu de vous inscrire
3. Ou supprimez l'ancien compte dans la base :
```sql
DELETE FROM users WHERE email = 'test@example.com';
```

---

### ❌ Problème 3 : Les migrations ne s'exécutent pas
**Cause :** Erreur dans le script package.json

**Vérification :**
Dans les logs Render, cherchez :
```
> echelle-eg39-backend@1.0.0 start
> node src/config/migrate.js && node src/server.js
```

**Solution :** Vérifiez que `package.json` contient :
```json
"scripts": {
  "start": "node src/config/migrate.js && node src/server.js"
}
```

---

### ❌ Problème 4 : Database timeout / Connection refused
**Causes possibles :**
- La base de données est en train de se créer (attendez 5 min)
- L'URL est incorrecte
- Vous utilisez External URL au lieu d'Internal URL

**Solutions :**
1. Attendez que le statut soit "Available"
2. Vérifiez l'URL copiée
3. Utilisez l'**Internal Database URL**

---

## ✅ CHECKLIST FINALE

Avant de tester l'inscription dans l'app Flutter :

- [ ] ✅ Base de données PostgreSQL créée et statut "Available"
- [ ] ✅ Variable `DATABASE_URL` ajoutée dans Render Environment
- [ ] ✅ Variable `JWT_SECRET` ajoutée (min 32 caractères)
- [ ] ✅ Variable `NODE_ENV=production` ajoutée
- [ ] ✅ Service redémarré automatiquement
- [ ] ✅ Logs montrent "Migration réussie !" et "Serveur démarré"
- [ ] ✅ Tables créées (vérifiées avec PSQL)
- [ ] ✅ Admin par défaut créé
- [ ] ✅ Test API réussi (Postman/curl)

---

## 📞 Support

Si vous avez toujours des problèmes après avoir suivi ce guide :

1. **Vérifiez les logs Render** (section Logs de votre Web Service)
2. **Vérifiez les logs Flutter** (terminal où vous avez lancé `flutter run`)
3. **Capturez les messages d'erreur complets** et consultez la documentation

---

**Bonne chance ! 🚀**
