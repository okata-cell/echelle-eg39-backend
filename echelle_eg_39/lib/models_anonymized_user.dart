/// Données minimales exposées par le répertoire administrateur.
///
/// Cette classe ne doit jamais contenir un e-mail brut, un téléphone, un nom,
/// un mot de passe ou une date d'inscription.
class AnonymizedUser {
  const AnonymizedUser({
    required this.id,
    required this.role,
    required this.maskedEmail,
  });

  final String id;
  final String role;
  final String maskedEmail;

  factory AnonymizedUser.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    return AnonymizedUser(
      id: rawId?.toString().trim() ?? '',
      role: json['role']?.toString().trim() ?? '',
      maskedEmail: json['maskedEmail']?.toString().trim() ?? '••••',
    );
  }
}

const String allAnonymizedRolesFilter = 'tous';

String formatAnonymizedResultCount(int count) {
  return '$count ${count == 1 ? 'résultat' : 'résultats'}';
}

String formatAnonymizedLiveRegion(int count) {
  return '${formatAnonymizedResultCount(count)} affichés';
}
