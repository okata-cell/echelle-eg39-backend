/// Converts backend rental statuses to the stable keys used by client history.
/// Unknown values stay unknown instead of being misleadingly shown as pending.
String normalizeLocationStatus(Object? value) {
  final normalized = (value?.toString() ?? '')
      .trim()
      .toLowerCase()
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('à', 'a')
      .replaceAll('ù', 'u')
      .replaceAll('_', '-');

  switch (normalized) {
    case 'en-attente':
    case 'pending':
    case 'nouveau':
      return 'en-attente';
    case 'approuvee':
    case 'approved':
      return 'approuvee';
    case 'en-cours':
    case 'active':
      return 'en-cours';
    case 'en-retard':
    case 'overdue':
      return 'en-retard';
    case 'termine':
    case 'completed':
    case 'livree':
      return 'termine';
    case 'rejetee':
    case 'rejected':
      return 'rejetee';
    case 'annulee':
    case 'annule':
    case 'cancelled':
    case 'canceled':
      return 'annulee';
    default:
      return 'inconnu';
  }
}
