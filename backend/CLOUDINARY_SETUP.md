# Configurer Cloudinary pour les images de promotion

Le backend envoie les images sélectionnées par un administrateur à Cloudinary, puis enregistre l’URL publique de l’image et son identifiant Cloudinary dans PostgreSQL. L’application Flutter continue d’utiliser l’endpoint existant `/api/promotions/image` : aucun changement côté application mobile n’est nécessaire.

## 1. Créer un compte Cloudinary

1. Créez un compte sur [cloudinary.com](https://cloudinary.com/) et confirmez votre adresse e-mail.
2. Dans le tableau de bord Cloudinary, ouvrez les informations du produit (Product Environment / API Keys).
3. Relevez les trois valeurs suivantes :
   - **Cloud name**
   - **API Key**
   - **API Secret**

L’offre affichée par Cloudinary est gratuite dans ses limites d’utilisation. Consultez [les tarifs et quotas à jour](https://cloudinary.com/pricing). Ne publiez jamais l’API Secret dans le dépôt, l’application Flutter, une capture d’écran ou une conversation.

## 2. Ajouter les variables dans Render

Dans le service backend Render, ouvrez **Environment** et ajoutez les variables suivantes, avec les valeurs du tableau de bord Cloudinary :

| Nom de variable | Valeur Cloudinary |
| --- | --- |
| `CLOUDINARY_CLOUD_NAME` | Cloud name |
| `CLOUDINARY_API_KEY` | API Key |
| `CLOUDINARY_API_SECRET` | API Secret |

Enregistrez les changements et laissez Render redéployer le backend. Les variables Firebase `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY` et `FIREBASE_STORAGE_BUCKET` ne sont plus nécessaires pour les nouveaux téléversements de promotion.

## 3. Vérifier l’intégration

1. Attendez que le service Render soit **Live**.
2. Dans l’application, connectez-vous comme administrateur et créez une promotion avec une image JPEG, PNG ou WebP de moins de 5 Mo.
3. Après réussite, ouvrez **Media Library** dans Cloudinary et vérifiez le dossier `promotions`.
4. Vérifiez que la promotion s’affiche dans l’application cliente.

L’API Secret reste uniquement dans Render. L’application mobile ne communique qu’avec le backend, qui valide l’image et effectue l’envoi signé vers Cloudinary.
