# Inviter un utilisateur à tester l'application (hors magasin)

L'application n'est ni sur Google Play ni sur l'App Store. Android se distribue
directement par fichier APK signé ; iPhone reste bloqué tant qu'il n'y a pas de
compte développeur Apple payant (TestFlight ou Ad Hoc).

## Liens à envoyer

| Élément | Adresse |
| --- | --- |
| **Page de téléchargement** (à envoyer au client) | https://echelle-eg39-backend-1.onrender.com/tester |
| APK universel (toutes architectures) | https://github.com/okata-cell/echelle-eg39-backend/releases/download/android-test-1.0.0/echelle-eg39-1.0.0-android.apk |
| APK allégé (arm64, téléphones Android récents) | https://github.com/okata-cell/echelle-eg39-backend/releases/download/android-test-1.0.0/echelle-eg39-1.0.0-arm64.apk |
| Page de la release (notes, empreintes) | https://github.com/okata-cell/echelle-eg39-backend/releases/tag/android-test-1.0.0 |

Version 1.0.0 · Android 7.0 (API 24) et plus · 61 Mo (61 019 359 octets),
variante allégée 23 Mo (23 246 141 octets).

En pratique, on n'envoie qu'**un seul lien** : celui de la page `/tester`. Elle
explique l'installation pas à pas et évite d'envoyer un fichier lourd par
WhatsApp.

## Message court (WhatsApp, SMS)

> Bonjour, l'application ÉCHELLE EG39 est prête à être testée avant sa mise en
> ligne. Sur Android, installez-la depuis cette page : https://okata-cell.github.io/echelle-eg39-backend/
> Android vous demandera d'autoriser l'installation « depuis cette source »
> (c'est normal, l'application ne passe pas encore par le Play Store).
> Connectez-vous ensuite avec votre compte habituel. Dites-moi ce qui bloque ou
> ce qui manque. Sur iPhone, écrivez-moi : le lien arrivera plus tard.

## Message e-mail

> **Objet : Tester l'application ÉCHELLE EG39**
>
> Bonjour,
>
> L'application ÉCHELLE EG39 est disponible en test avant sa publication sur les
> magasins d'applications. Votre retour nous sert à corriger ce qui gêne avant
> l'ouverture au public.
>
> **Sur Android** : ouvrez https://okata-cell.github.io/echelle-eg39-backend/
> puis touchez « Télécharger l'application ». Android affiche un avertissement,
> car l'application ne vient pas encore du Play Store : autorisez l'installation
> pour la source utilisée (Chrome ou Fichiers). Le fichier fait 61 Mo.
>
> **Sur iPhone** : l'installation passe obligatoirement par TestFlight, qui
> demande un compte développeur Apple payant. Nous ouvrirons ce canal ensuite ;
> répondez à ce message pour être prévenu en premier.
>
> Une fois installée, connectez-vous avec votre compte. Si vous n'en avez pas
> encore, dites-le-nous : nous le créons.
>
> Cordialement,
> ÉCHELLE EG39 — Lomé, Rue des frères franciscains, après les rails — Togo
> admin@echelle-eg39.com · +228 90 01 43 29

## Publier une nouvelle version de test

1. Mettre à jour `version:` dans `pubspec.yaml` (par exemple `1.0.0+2`).
2. Construire : `flutter build apk --release` puis
   `flutter build apk --release --split-per-abi`.
3. Créer une nouvelle release GitHub (tag `android-test-<version>`) et y joindre
   l'APK universel + l'APK arm64.
4. Mettre à jour les constantes `ANDROID_TEST_*` en tête de
   `backend/backend/src/routes/public_pages.js` (version, taille, URL).
5. Pousser sur `main` : Render redéploie le backend, la page `/tester` suit.

Les testeurs qui possèdent déjà l'application réinstallent par-dessus : données
et session conservées. Hors magasin, aucune mise à jour automatique.

## Rappel de la contrainte iPhone

- Compte gratuit : profil de 7 jours, 3 applications maximum, installation par
  câble. Non partageable.
- Apple Developer Program (99 $/an) : TestFlight (lien public, 10 000 testeurs)
  ou Ad Hoc (100 appareils par an, UDID à collecter au préalable).
- Aucune installation iOS « type APK » n'existe : Apple exige un paquet signé.
