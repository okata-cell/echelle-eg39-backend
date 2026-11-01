import 'company_contact.dart';
import 'company_location.dart';

/// Contenu partagé et liens d’envoi vers les réseaux sociaux.
///
/// Chaque réseau possède son propre lien d’intention ; Instagram et les
/// applications sans partage web passent par la feuille de partage du système
/// ou par une copie du message.
class CompanyShare {
  const CompanyShare._();

  /// Seul lien public réellement disponible pour l’entreprise.
  static String get publicUrl => CompanyLocation.mapsUrl;

  /// Présentation de l’entreprise (téléphone et e-mail inclus).
  static const String message = CompanyContact.introduction;

  /// Texte complet envoyé : présentation puis lien de localisation.
  static String get fullMessage => '$message\n$publicUrl';

  static Uri whatsAppUri() => CompanyContact.whatsAppShareUri(fullMessage);

  static Uri facebookUri() => Uri.https(
    'www.facebook.com',
    '/sharer/sharer.php',
    {'u': publicUrl, 'quote': message},
  );

  static Uri telegramUri() =>
      Uri.https('t.me', '/share/url', {'url': publicUrl, 'text': message});

  static Uri xUri() => Uri.https('twitter.com', '/intent/tweet', {
    'text': message,
    'url': publicUrl,
  });

  static Uri linkedInUri() => Uri.https(
    'www.linkedin.com',
    '/sharing/share-offsite/',
    {'url': publicUrl},
  );

  static Uri emailUri() => CompanyContact.emailUriWith(
    subject: '${CompanyContact.name} — coordonnées',
    body: fullMessage,
  );

  /// Instagram n’accepte aucun partage texte par lien : on ouvre l’application
  /// après avoir copié le message.
  static Uri instagramAppUri() => Uri.parse('instagram://app');

  static Uri instagramWebUri() => Uri.https('www.instagram.com', '/');

  static const String instagramCopiedMessage =
      'Message copié. Collez-le dans Instagram.';
}
