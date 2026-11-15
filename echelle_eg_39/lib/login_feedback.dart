// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'api_service.dart';

/// Où poser le message quand une connexion échoue.
///
/// Un seul champ porte l'erreur : l'identifiant **ou** le mot de passe. Le
/// client n'a donc pas à deviner lequel des deux est en cause, ce que le
/// message global « e-mail ou mot de passe incorrect » ne permettait pas.
class FeedbackConnexion {
  const FeedbackConnexion({this.erreurIdentifiant, this.erreurMotDePasse});

  final String? erreurIdentifiant;
  final String? erreurMotDePasse;

  bool get aUneErreurDeChamp =>
      erreurIdentifiant != null || erreurMotDePasse != null;
}

/// Message de champ correspondant à un refus du serveur.
///
/// [identifiantEstEmail] vient de la saisie : le serveur ne précise pas si
/// l'identifiant recherché était une adresse ou un numéro, et le client doit
/// lire un message qui parle de ce qu'il a réellement tapé.
FeedbackConnexion feedbackConnexion(
  ApiException error, {
  required bool identifiantEstEmail,
}) {
  switch (error.type) {
    case ApiErrorType.invalidPassword:
      return const FeedbackConnexion(
        erreurMotDePasse: 'Mot de passe incorrect pour ce compte.',
      );

    case ApiErrorType.invalidIdentifier:
      return FeedbackConnexion(
        erreurIdentifiant: identifiantEstEmail
            ? 'Aucun compte avec cette adresse e-mail.'
            : 'Aucun compte avec ce numéro de téléphone.',
      );

    // Réseau, serveur, compte supprimé, blocage : aucun champ n'est en cause,
    // ces cas restent des messages d'écran (bandeau de blocage ou snack-bar).
    case ApiErrorType.invalidCredentials:
    case ApiErrorType.serverUnavailable:
    case ApiErrorType.network:
    case ApiErrorType.request:
    case ApiErrorType.accountDeleted:
    case ApiErrorType.accountLocked:
      return const FeedbackConnexion();
  }
}
