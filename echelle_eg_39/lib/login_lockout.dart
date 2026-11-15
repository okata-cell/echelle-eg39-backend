// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

/// Blocage de la connexion après plusieurs échecs : durée par défaut, clé de
/// mémoire locale et libellé du décompte.
///
/// Le serveur reste seul juge du blocage : il renvoie la durée réellement
/// restante (`retryAfterSeconds`). Ce fichier ne fait que la mettre en forme et
/// la conserver le temps que l'écran de connexion soit refermé puis rouvert.
library;

/// Durée retenue quand le serveur ne précise pas le délai : même valeur que le
/// blocage par défaut du backend (quatre échecs, douze heures).
const Duration delaiBlocageParDefaut = Duration(hours: 12);

/// Clé de préférence où l'échéance du blocage est conservée.
///
/// Une clé par identifiant : deux comptes essayés sur le même téléphone ne
/// partagent pas leur décompte.
String? cleBlocage(String identifiant) {
  final normalise = identifiant.trim().toLowerCase();
  if (normalise.isEmpty) return null;
  return 'login_lock_until:$normalise';
}

/// « 11 h 40 », « 3 h », « 47 min », « moins d'une minute ».
///
/// Même vocabulaire que le message du serveur, pour qu'un client qui lit l'un
/// puis l'autre ne voie pas deux façons de dire la même attente.
String libelleDelaiRestant(Duration restant) {
  final secondes = restant.isNegative ? 0 : restant.inSeconds;

  if (secondes >= 3600) {
    final heures = secondes ~/ 3600;
    final minutes = (secondes % 3600) ~/ 60;
    return minutes > 0
        ? '$heures h ${minutes.toString().padLeft(2, '0')}'
        : '$heures h';
  }

  if (secondes >= 60) return '${secondes ~/ 60} min';

  return 'moins d’une minute';
}
