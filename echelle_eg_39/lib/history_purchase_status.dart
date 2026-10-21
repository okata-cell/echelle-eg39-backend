/// Keeps purchase request statuses distinct from rental lifecycle statuses.
///
/// In particular, an approved purchase is not a rental in progress and a
/// delivered purchase is not necessarily marked complete.
String normalizePurchaseStatus(Object? value) {
  final normalized = (value?.toString() ?? '')
      .trim()
      .toLowerCase()
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('à', 'a')
      .replaceAll('ù', 'u')
      .replaceAll('-', '_');

  switch (normalized) {
    case 'en_attente':
    case 'pending':
      return 'en_attente';
    case 'approuvee':
    case 'approved':
      return 'approuvee';
    case 'rejetee':
    case 'rejected':
      return 'rejetee';
    case 'livree':
    case 'delivered':
      return 'livree';
    case 'termine':
    case 'completed':
      return 'termine';
    default:
      return 'inconnu';
  }
}
