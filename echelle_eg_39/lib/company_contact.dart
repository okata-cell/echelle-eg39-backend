// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'company_location.dart';

/// Coordonnées officielles de contact d’ÉCHELLE EG39.
///
/// Source unique : les écrans lisent ces valeurs au lieu de répéter l’adresse
/// e-mail et les numéros à plusieurs endroits du code.
class CompanyContact {
  const CompanyContact._();

  static const String name = CompanyLocation.name;

  /// Numéro affiché, lisible par un humain.
  static const String phoneDisplay = '+228 90 01 43 29';

  /// Numéro au format international, attendu par le composeur téléphonique.
  static const String phoneDial = '+22890014329';

  /// Numéro sans « + », format attendu par les liens wa.me.
  static const String whatsAppNumber = '22890014329';

  /// Boîte réellement relevée par l’entreprise (compte administrateur).
  static const String email = 'admin@echelle-eg39.com';

  static const String hours = 'Lundi–vendredi : 8h–18h\nSamedi : sur demande';

  static Uri get phoneUri => Uri(scheme: 'tel', path: phoneDial);

  static Uri get emailUri => Uri(scheme: 'mailto', path: email);

  /// Conversation WhatsApp avec l’entreprise.
  static Uri whatsAppUri({String? text}) => Uri.https(
    'wa.me',
    '/$whatsAppNumber',
    text == null ? null : {'text': text},
  );

  /// Partage libre : le choix du destinataire revient à WhatsApp.
  static Uri whatsAppShareUri(String text) =>
      Uri.https('wa.me', '/', {'text': text});

  /// Lien e-mail avec objet et corps pré-remplis.
  static Uri emailUriWith({String? subject, String? body}) => Uri(
    scheme: 'mailto',
    path: email,
    queryParameters: {'subject': ?subject, 'body': ?body},
  );

  /// Texte de présentation partagé depuis le profil.
  static const String introduction =
      'Découvrez $name, votre partenaire en équipements de topographie. '
      'Contact : $phoneDisplay — $email';

  static const String phoneFallbackMessage =
      'Aucune application d’appel. Numéro copié : $phoneDisplay';

  static const String emailFallbackMessage =
      'Aucune application e-mail. Adresse copiée : $email';

  static const String whatsAppFallbackMessage =
      'WhatsApp introuvable. Numéro copié : $phoneDisplay';
}
