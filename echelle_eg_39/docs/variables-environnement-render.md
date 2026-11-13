# Variables d'environnement sur Render

Procédure pour le service `echelle-eg39-backend-1`. Les secrets se posent dans le
**tableau de bord Render**, pas dans le dépôt : le fichier `render.yaml` déclare
seulement leur nom, avec `sync: false` pour qu'un déploiement ne les écrase pas.

## Où cliquer

1. Ouvrir <https://dashboard.render.com> et se connecter.
2. Dans la liste **Services**, cliquer sur `echelle-eg39-backend-1`.
3. Dans le menu de gauche du service, cliquer sur **Environment**.
4. Section **Environment Variables** → bouton **+ Add Environment Variable**.
5. Saisir la clé dans `Key`, la valeur dans `Value`, puis **Save Changes**.
   Render redéploie le service automatiquement (environ 2 à 4 minutes).

C'est le même écran que celui où sont déjà `DATABASE_URL`, `JWT_SECRET` et
`CLOUDINARY_*`. Rien à ajouter dans le code, rien à modifier dans `render.yaml`.

Variante par plan Blueprint : **Blueprint** → `echelle-eg39-backend-1` →
**Sync** affiche les variables déclarées dans `render.yaml` avec un champ vide
pour celles en `sync: false`. Remplir `DATA_ENCRYPTION_KEY` et
`CONTACT_INDEX_SECRET` à cet endroit, puis **Apply**. Éviter d'utiliser les deux
chemins en même temps : le dernier enregistré fait foi.

## Les deux variables

| Key | Value |
| --- | --- |
| `DATA_ENCRYPTION_KEY` | 32 octets en base64, à générer (commande ci-dessous). |
| `CONTACT_INDEX_SECRET` | 32 octets en base64, à générer séparément. |

Les deux font 32 octets tirés au hasard et doivent rester **différentes** :
l'une chiffre, l'autre calcule les empreintes de recherche. Générer chacune avec
la même commande, une fois par variable :

```bash
node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"
```

Les valeurs ne sont volontairement écrites nulle part dans ce dépôt : un secret
versionné reste dans l'historique Git même s'il est supprimé ensuite. Les
transmettre par le gestionnaire de secrets de l'équipe, les saisir directement
dans Render, et conserver `DATA_ENCRYPTION_KEY` en lieu sûr en dehors de Render.

Si la valeur est collée avec un espace ou un retour à la ligne en trop, le code
la nettoie (`trim()`) : l'erreur classique du copier-coller n'a pas d'effet.

## Pourquoi maintenant, et pas plus tard

Ces variables doivent exister **avant les prochaines inscriptions**. Tant
qu'elles manquent, le serveur dérive une clé de `JWT_SECRET` pour ne pas
s'arrêter : les comptes créés dans cet intervalle sont chiffrés et indexés avec
cette clé dérivée. Ajouter les variables ensuite ne casse pas la connexion de
ces comptes (l'empreinte est recalculée au moment de la connexion), mais leurs
coordonnées déjà enregistrées deviennent illisibles.

Une fois les variables en place :

- **ne plus les changer** sans raison ; les modifier rend illisibles les e-mails
  et téléphones chiffrés des comptes créés avant ;
- conserver `DATA_ENCRYPTION_KEY` ailleurs que dans Render (gestionnaire de
  secrets de l'équipe). Perdre cette clé, c'est perdre définitivement les
  coordonnées chiffrées : la base seule ne permet pas de les retrouver.

## Vérifier que Render a bien pris les variables

Après le redéploiement, appeler la route de santé :

```bash
curl -s https://echelle-eg39-backend-1.onrender.com/health
```

Attendu :

```json
"secrets": { "encryptionKey": "dediee", "indexSecret": "dedie" }
```

Les autres états indiquent le repli sur le secret du serveur :

| `encryptionKey` | Signification |
| --- | --- |
| `dediee` | `DATA_ENCRYPTION_KEY` lue par le serveur. |
| `derivee` | Variable absente : clé dérivée de `JWT_SECRET`. |
| `absente` | Ni l'une ni l'autre : chiffrement impossible. |

| `indexSecret` | Signification |
| --- | --- |
| `dedie` | `CONTACT_INDEX_SECRET` lu par le serveur. |
| `herite` | Repli sur `IDENTIFIER_HASH_SECRET` ou `JWT_SECRET`. |
| `absent` | Aucun secret : ni empreinte, ni unicité. |

La route ne renvoie jamais la valeur d'une clé, seulement son état.

## Contrôle final côté application

1. Créer un compte de test depuis l'application.
2. Se déconnecter, se reconnecter avec le même e-mail : la connexion doit
   passer (elle s'appuie sur l'empreinte, pas sur le clair).
3. Ouvrir la fiche du client dans l'onglet **Clients** de l'admin : l'e-mail et
   le téléphone doivent s'afficher normalement, donc être déchiffrés.

Un tiret à la place des coordonnées signifie que `DATA_ENCRYPTION_KEY` a changé
entre l'inscription et la lecture.
