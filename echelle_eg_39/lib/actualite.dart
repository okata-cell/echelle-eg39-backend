// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'package:flutter/foundation.dart';

/// Une actualité rédigée par l'administrateur et affichée sur l'accueil.
///
/// La carte d'accueil n'est pas cliquable : `description` doit donc rester
/// autosuffisante. `corps` est transporté dès maintenant pour permettre un
/// écran de détail ultérieur sans nouvelle migration.
@immutable
class Actualite {
  const Actualite({
    required this.id,
    required this.titre,
    required this.description,
    required this.datePublication,
    this.corps,
    this.imageUrl,
    this.imageStoragePath,
    this.publiee = true,
    this.epingle = false,
  });

  final int id;
  final String titre;
  final String description;
  final String? corps;
  final String? imageUrl;
  final String? imageStoragePath;
  final DateTime datePublication;
  final bool publiee;
  final bool epingle;

  bool get hasImage => (imageUrl ?? '').trim().isNotEmpty;

  /// Date au format des cartes : « 06 nov. 2026 ».
  String get dateLabel => formatActualiteDate(datePublication);

  /// Lit une actualité renvoyée par l'API, en tolérant les champs manquants.
  static Actualite? tryParse(Object? raw) {
    if (raw is! Map) return null;

    final map = Map<String, dynamic>.from(raw);
    final id = int.tryParse(map['id']?.toString() ?? '');
    final titre = map['titre']?.toString().trim() ?? '';
    final description = map['description']?.toString().trim() ?? '';
    if (id == null || titre.isEmpty || description.isEmpty) return null;

    final statut = map['statut']?.toString();
    return Actualite(
      id: id,
      titre: titre,
      description: description,
      corps: _nullable(map['corps']),
      imageUrl: _nullable(map['image_url'] ?? map['imageUrl']),
      imageStoragePath: _nullable(map['image_storage_path']),
      datePublication: parseDateOnly(map['date_publication']) ?? DateTime.now(),
      publiee: statut == null || statut == 'publiee',
      epingle: map['epingle'] == true,
    );
  }

  /// Convertit une liste d'objets JSON en actualités triées pour l'accueil.
  static List<Actualite> listFrom(Iterable<Object?> raw) {
    final items = raw.map(tryParse).whereType<Actualite>().toList()
      ..sort(compareForHome);
    return List<Actualite>.unmodifiable(items);
  }

  /// Épinglée d'abord, puis la plus récente, puis le plus grand identifiant.
  static int compareForHome(Actualite a, Actualite b) {
    if (a.epingle != b.epingle) return a.epingle ? -1 : 1;
    final byDate = b.datePublication.compareTo(a.datePublication);
    if (byDate != 0) return byDate;
    return b.id.compareTo(a.id);
  }

  /// Ne garde que l'année, le mois et le jour : le serveur renvoie une `DATE`
  /// sérialisée à minuit UTC, qu'il ne faut pas décaler d'un jour.
  static DateTime? parseDateOnly(Object? raw) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return null;

    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(text);
    if (match != null) {
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
    }

    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  /// Représentation stockée sur l'appareil : contrairement à la charge utile
  /// envoyée à l'API, elle conserve l'identifiant, sans quoi le cache serait
  /// impossible à relire.
  Map<String, dynamic> toCacheJson() {
    return <String, dynamic>{
      'id': id,
      'titre': titre,
      'description': description,
      'corps': corps,
      'image_url': imageUrl,
      'image_storage_path': imageStoragePath,
      'date_publication': formatIsoDate(datePublication),
      'statut': publiee ? 'publiee' : 'brouillon',
      'epingle': epingle,
    };
  }

  /// Charge utile JSON envoyée à l'API admin.
  Map<String, dynamic> toPayload() {
    return <String, dynamic>{
      'titre': titre,
      'description': description,
      if (corps != null) 'corps': corps,
      'date_publication': formatIsoDate(datePublication),
      'statut': publiee ? 'publiee' : 'brouillon',
      'epingle': epingle,
      'image_url': imageUrl,
      'image_storage_path': imageStoragePath,
    };
  }

  static String? _nullable(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

/// « 06 nov. 2026 » : la forme utilisée par les cartes et l'admin.
String formatActualiteDate(DateTime date) {
  const mois = <String>[
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];
  final jour = date.day.toString().padLeft(2, '0');
  return '$jour ${mois[date.month - 1]} ${date.year}';
}

/// `AAAA-MM-JJ`, le seul format de date accepté par l'API.
String formatIsoDate(DateTime date) {
  final mois = date.month.toString().padLeft(2, '0');
  final jour = date.day.toString().padLeft(2, '0');
  return '${date.year}-$mois-$jour';
}
