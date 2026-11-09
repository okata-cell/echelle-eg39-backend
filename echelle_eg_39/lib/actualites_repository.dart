// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'actualite.dart';
import 'api_service.dart';

/// Résultat d'une lecture d'actualités, avec l'origine de la donnée.
class ActualitesSnapshot {
  const ActualitesSnapshot({required this.items, this.fromCache = false});

  final List<Actualite> items;
  final bool fromCache;

  bool get isEmpty => items.isEmpty;

  static const ActualitesSnapshot empty = ActualitesSnapshot(
    items: <Actualite>[],
  );
}

/// Source unique des actualités côté client : cache local puis réseau.
///
/// L'accueil affiche d'abord ce que l'appareil connaît déjà, ce qui évite un
/// bloc vide au lancement et une section qui disparaît hors ligne.
class ActualitesRepository {
  ActualitesRepository({
    Future<List<Map<String, dynamic>>> Function({int limit})? fetchPublished,
    Future<SharedPreferences> Function()? openPreferences,
  }) : _fetchPublished = fetchPublished ?? ApiService.getActualites,
       _openPreferences = openPreferences ?? SharedPreferences.getInstance;

  /// Nombre d'actualités affichées sur l'accueil.
  static const int homeLimit = 3;

  /// Nombre maximal demandé par l'écran « Toutes les actualités ».
  static const int listLimit = 50;

  static const String cacheKey = 'actualites_cache_v1';

  final Future<List<Map<String, dynamic>>> Function({int limit})
  _fetchPublished;
  final Future<SharedPreferences> Function() _openPreferences;

  Future<ActualitesSnapshot> readCache({int? limit}) async {
    try {
      final prefs = await _openPreferences();
      final raw = prefs.getString(cacheKey);
      if (raw == null || raw.isEmpty) return ActualitesSnapshot.empty;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return ActualitesSnapshot.empty;

      // Une actualité sortie de sa fenêtre de publication ne doit pas
      // réapparaître depuis le cache.
      final items = Actualite.listFrom(
        decoded,
      ).where((actualite) => actualite.estEnLigne).toList(growable: false);
      return ActualitesSnapshot(
        items: limit == null
            ? items
            : items.take(limit).toList(growable: false),
        fromCache: true,
      );
    } catch (_) {
      // Un cache illisible ne doit jamais empêcher l'appel réseau.
      return ActualitesSnapshot.empty;
    }
  }

  Future<ActualitesSnapshot> refresh({int? limit}) async {
    final payload = await _fetchPublished(limit: limit ?? listLimit);
    final items = Actualite.listFrom(payload);
    // La liste vide est écrite aussi : sans cela, une actualité dépubliée ou
    // supprimée resterait affichée sur l'accueil à partir du cache.
    await _writeCache(items);
    return ActualitesSnapshot(items: items);
  }

  Future<void> _writeCache(List<Actualite> items) async {
    try {
      final prefs = await _openPreferences();
      if (items.isEmpty) {
        await prefs.remove(cacheKey);
        return;
      }

      await prefs.setString(
        cacheKey,
        jsonEncode(items.map((actualite) => actualite.toCacheJson()).toList()),
      );
    } catch (_) {
      // Le cache est un confort : son échec ne remonte pas à l'écran.
    }
  }
}
