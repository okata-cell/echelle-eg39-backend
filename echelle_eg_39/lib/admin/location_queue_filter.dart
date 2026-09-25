import 'admin_tokens.dart';

enum LocationQueueFilter { pending, inProgress, completed, history, all }

extension LocationQueueFilterPresentation on LocationQueueFilter {
  String get key => switch (this) {
    LocationQueueFilter.pending => 'pending',
    LocationQueueFilter.inProgress => 'in-progress',
    LocationQueueFilter.completed => 'completed',
    LocationQueueFilter.history => 'history',
    LocationQueueFilter.all => 'all',
  };

  String get label => switch (this) {
    LocationQueueFilter.pending => 'En attente',
    LocationQueueFilter.inProgress => 'En cours',
    LocationQueueFilter.completed => 'Terminées',
    LocationQueueFilter.history => 'Historique',
    LocationQueueFilter.all => 'Toutes',
  };
}

/// Returns the display bucket for a persisted or legacy location status.
/// Unknown statuses deliberately return null so they remain visible in "Toutes"
/// without being assigned to a misleading status tab.
String? locationQueueBucketKey(Object? status) {
  final normalized = adminStatusKey(status);
  switch (normalized) {
    case 'en_attente':
      return LocationQueueFilter.pending.key;
    case 'en_cours':
    case 'approuvee':
    case 'en_retard':
      return LocationQueueFilter.inProgress.key;
    case 'termine':
      return LocationQueueFilter.completed.key;
    case 'rejetee':
    case 'annulee':
      return LocationQueueFilter.history.key;
    default:
      return null;
  }
}

bool locationMatchesQueue(
  Map<String, dynamic> location,
  LocationQueueFilter filter,
) {
  if (filter == LocationQueueFilter.all) return true;
  return locationQueueBucketKey(location['statut']) == filter.key;
}

List<Map<String, dynamic>> filterLocationsForQueue(
  Iterable<Map<String, dynamic>> locations,
  LocationQueueFilter filter,
) {
  return locations
      .where((location) => locationMatchesQueue(location, filter))
      .toList(growable: false);
}

int countLocationsForQueue(
  Iterable<Map<String, dynamic>> locations,
  LocationQueueFilter filter,
) {
  return locations
      .where((location) => locationMatchesQueue(location, filter))
      .length;
}

bool isLocationStatusDeletable(Object? status) {
  final normalized = adminStatusKey(status);
  return normalized == 'termine' ||
      normalized == 'rejetee' ||
      normalized == 'annulee' ||
      normalized == 'annulée' ||
      normalized == 'annule' ||
      normalized == 'annulé' ||
      normalized == 'cancelled' ||
      normalized == 'canceled';
}
