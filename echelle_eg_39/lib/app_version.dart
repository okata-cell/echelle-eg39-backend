// Version affichée dans l’application (écran Profil, « À propos »).

/// Numéro de version lisible, aligné sur `version:` dans `pubspec.yaml`.
///
/// Le nombre après le `+` de `pubspec.yaml` est le versionCode Android : il doit
/// toujours augmenter, sinon Android refuse l’installation par-dessus l’ancienne
/// version. La procédure de publication est décrite dans
/// `docs/invitation-test.md`.
const String kAppVersion = '1.0.3';
