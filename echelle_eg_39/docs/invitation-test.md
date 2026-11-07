# Inviter un utilisateur à tester l'application (hors magasin)

L'application n'est ni sur Google Play ni sur l'App Store. Android se distribue
directement par fichier APK signé ; iPhone reste bloqué tant qu'il n'y a pas de
compte développeur Apple payant (TestFlight ou Ad Hoc).

Version courante : **1.0.3** (versionCode **2004**, variante allégée arm64
**4004**). Nouveautés : la récupération d'accès ne dépend plus d'aucun envoi
d'e-mail ni de SMS — le client saisit le **code de récupération**
(`EG39-XXXX-XXXX`) remis à la création du compte, et l'application affiche un
mot de passe temporaire pendant 2 minutes (copier/fermer), puis impose le choix
d'un mot de passe définitif. Le code est affiché dans la fenêtre des identifiants
juste après l'inscription.

**Important à dire aux testeurs** : le code de récupération s'affiche une seule
fois, en même temps que le mot de passe, juste après l'inscription. Sans lui,
seule l'agence peut régénérer un accès (menu d'un client → « Code de
récupération » dans le back-office), après vérification de l'identité par
téléphone.

Rappel des versions précédentes : 1.0.2 (compte supprimé signalé clairement,
session fermée immédiatement, mot de passe temporaire affiché 2 minutes) ;
1.0.1 (récapitulatif des identifiants après inscription).

Contact affiché sur la page d'invitation : **okataolaniyi@gmail.com** ·
**+228 90 94 94 39**. Les pages légales (confidentialité, conditions,
suppression de compte) conservent, elles, l'adresse de l'entreprise.

## Liens à envoyer

| Élément | Adresse |
| --- | --- |
| **Page de téléchargement** (à envoyer au client) | https://echelle-eg39-backend-1.onrender.com/tester |
| APK universel (toutes architectures) | https://github.com/okata-cell/echelle-eg39-backend/releases/download/android-test-1.0.3/echelle-eg39-1.0.3-android.apk |
| APK allégé (arm64, téléphones Android récents) | https://github.com/okata-cell/echelle-eg39-backend/releases/download/android-test-1.0.3/echelle-eg39-1.0.3-arm64.apk |
| Page de la release (notes, empreintes) | https://github.com/okata-cell/echelle-eg39-backend/releases/tag/android-test-1.0.3 |

Version 1.0.3 · Android 7.0 (API 24) et plus · 64 Mo (64 200 187 octets,
versionCode 2004), variante allégée 23 Mo (23 246 745 octets, versionCode 4004).

En pratique, on n'envoie qu'**un seul lien** : celui de la page `/tester`. Elle
explique l'installation pas à pas et évite d'envoyer un fichier lourd par
WhatsApp.

## Message court (WhatsApp, SMS)

> Bonjour, l'application ÉCHELLE EG39 est prête à être testée avant sa mise en
> ligne. Sur Android, installez-la depuis cette page :
> https://echelle-eg39-backend-1.onrender.com/tester
> Android vous demandera d'autoriser l'installation « depuis cette source »
> (c'est normal, l'application ne passe pas encore par le Play Store).
> Si l'application est déjà installée, réinstallez simplement par-dessus : vos
> données et votre session sont conservées.
> Connectez-vous ensuite avec votre compte habituel. Dites-moi ce qui bloque ou
> ce qui manque : okataolaniyi@gmail.com ou +228 90 94 94 39.
> Sur iPhone, écrivez-moi : le lien arrivera plus tard.

## Message e-mail

> **Objet : Tester l'application ÉCHELLE EG39**
>
> Bonjour,
>
> L'application ÉCHELLE EG39 est disponible en test avant sa publication sur les
> magasins d'applications. Votre retour nous sert à corriger ce qui gêne avant
> l'ouverture au public.
>
> **Sur Android** : ouvrez https://echelle-eg39-backend-1.onrender.com/tester
> puis touchez « Télécharger l'application ». Android affiche un avertissement,
> car l'application ne vient pas encore du Play Store : autorisez l'installation
> pour la source utilisée (Chrome ou Fichiers). Le fichier fait 64 Mo.
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
> okataolaniyi@gmail.com · +228 90 94 94 39

## Publier une nouvelle version de test

1. Mettre à jour `version:` dans `pubspec.yaml` et la constante `kAppVersion` de
   `lib/app_version.dart` (le numéro affiché dans le Profil).
   **Le numéro après le `+` doit rester au-dessus de 2000** : voir l'encadré
   ci-dessous. La 1.0.3 utilise `1.0.3+2004`.
2. Construire : `flutter build apk --release` puis
   `flutter build apk --release --split-per-abi`. Vérifier les deux versionCodes :
   `aapt2 dump badging build/app/outputs/flutter-apk/app-release.apk | head -1`.
3. Créer une nouvelle release GitHub (tag `android-test-<version>`, pré-release) et
   y joindre l'APK universel (`app-release.apk`, renommé
   `echelle-eg39-<version>-android.apk`) + l'APK arm64
   (`app-arm64-v8a-release.apk`, renommé `echelle-eg39-<version>-arm64.apk`).
4. Mettre à jour les constantes `ANDROID_TEST_*` en tête de
   `backend/src/routes/public_pages.js` (version, taille, date, URL).
5. Pousser sur `main` : Render redéploie le backend, la page `/tester` suit.

> **Piège des versionCodes ABI.** `--split-per-abi` ne produit pas le même
> versionCode pour la variante arm64 : Flutter ajoute 2 000 à celui de l'APK
> universel. La 1.0.2 universelle était donc en **3**, mais sa variante allégée
> en **2003**. Un testeur passé par la variante allégée ne pourrait pas installer
> une 1.0.3 en versionCode 4 : Android refuse une régression. D'où le choix de
> partir de **2004** pour l'universel (**4004** pour l'arm64) — les deux
> variantes s'installent alors par-dessus l'une ou l'autre 1.0.2, sans perte de
> données.

Les testeurs qui possèdent déjà l'application réinstallent par-dessus : données
et session conservées. Hors magasin, aucune mise à jour automatique.

## Rappel de la contrainte iPhone

- Compte gratuit : profil de 7 jours, 3 applications maximum, installation par
  câble. Non partageable.
- Apple Developer Program (99 $/an) : TestFlight (lien public, 10 000 testeurs)
  ou Ad Hoc (100 appareils par an, UDID à collecter au préalable).
- Aucune installation iOS « type APK » n'existe : Apple exige un paquet signé.
