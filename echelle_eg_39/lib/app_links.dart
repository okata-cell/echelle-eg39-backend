import 'package:flutter/foundation.dart';

import 'company_contact.dart';

/// Liens publics de l’application.
///
/// L’application n’est pas encore publiée : les deux URLs ci-dessous sont
/// volontairement vides et l’interface affiche alors « Bientôt disponible ».
/// Le jour de la publication, il suffit de coller les liens ici — aucun autre
/// fichier à modifier.
class AppLinks {
  const AppLinks._();

  /// Identifiants utilisés au moment de la publication.
  static const String androidPackageId = 'com.okata.echelleeg39';
  static const String iosBundleId = 'com.maurice.echelleEg39';

  /// À remplir après publication, par exemple :
  /// `https://play.google.com/store/apps/details?id=com.okata.echelleeg39`
  static const String androidStoreUrl = '';

  /// À remplir après publication, par exemple :
  /// `https://apps.apple.com/app/id0000000000`
  static const String iosStoreUrl = '';

  static bool get hasAndroidStore => androidStoreUrl.isNotEmpty;

  static bool get hasIosStore => iosStoreUrl.isNotEmpty;

  static bool get isPublished => hasAndroidStore || hasIosStore;

  /// Liens disponibles, dans l’ordre Android puis iPhone.
  static List<StoreLink> get storeLinks =>
      buildStoreLinks(androidUrl: androidStoreUrl, iosUrl: iosStoreUrl);

  static List<StoreLink> buildStoreLinks({
    String androidUrl = androidStoreUrl,
    String iosUrl = iosStoreUrl,
  }) => [
    if (androidUrl.isNotEmpty) StoreLink(StorePlatform.android, androidUrl),
    if (iosUrl.isNotEmpty) StoreLink(StorePlatform.ios, iosUrl),
  ];

  /// Lien correspondant à la plateforme du téléphone courant, sinon le premier
  /// lien disponible (le destinataire d’un partage n’a pas forcément le même
  /// appareil).
  static String? storeUrlForThisDevice({String? androidUrl, String? iosUrl}) {
    final android = androidUrl ?? androidStoreUrl;
    final ios = iosUrl ?? iosStoreUrl;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS when ios.isNotEmpty => ios,
      TargetPlatform.iOS => android.isEmpty ? null : android,
      TargetPlatform.android when android.isNotEmpty => android,
      TargetPlatform.android => ios.isEmpty ? null : ios,
      _ => android.isNotEmpty ? android : (ios.isEmpty ? null : ios),
    };
  }

  /// Message d’invitation : les liens des deux stores y figurent pour que le
  /// destinataire choisisse celui de son téléphone.
  static String inviteMessage({
    String androidUrl = androidStoreUrl,
    String iosUrl = iosStoreUrl,
  }) {
    final links = buildStoreLinks(androidUrl: androidUrl, iosUrl: iosUrl);
    return [
      'Installez ${CompanyContact.name}, l’application de gestion des '
          'équipements de topographie.',
      for (final link in links) '${link.label} : ${link.url}',
    ].join('\n');
  }

  /// Texte affiché quand l’application n’est encore sur aucun store.
  static const String unavailableNotice =
      'L’application ÉCHELLE EG39 n’est pas encore publiée sur Google Play ni '
      'sur l’App Store. L’invitation sera partageable dès sa mise en ligne.';
}

enum StorePlatform { android, ios }

/// Lien de téléchargement d’un store.
class StoreLink {
  const StoreLink(this.platform, this.url);

  final StorePlatform platform;
  final String url;

  String get label => switch (platform) {
    StorePlatform.android => 'Android (Google Play)',
    StorePlatform.ios => 'iPhone (App Store)',
  };

  String get name => switch (platform) {
    StorePlatform.android => 'Google Play',
    StorePlatform.ios => 'App Store',
  };
}
