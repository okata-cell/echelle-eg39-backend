# TODO: Fix Admin Locations Menu & Rendering Crash - APPROVED PLAN

**Problème**: Menu "location d'appareil" admin ne s'affiche plus, onglet "location attente" vide + erreur répétée `semantics.parentDataDirty` (crash rendering Flutter).

**Analyse**:
- Fichiers clés: lib/AdminDashBoard.dart (nav OK) → lib/LocationsMenu.dart (CustomScrollView + ListView.builder sans keys → crash rebuilds).
- Causes: 
  1. ListView.builder sans `key: ValueKey(loc['id'])` → semantics error spam.
  2. Nested scrollables (RefreshIndicator > ListView) sans shrinkWrap/physics → scroll conflicts.
  3. API getLocations() peut échouer (Render.com lent) → stuck loading ou empty.
- Backend OK (admin voit tout).

**Plan détaillé par fichier**:

## 1. ✅ [DONE] lib/LocationsMenu.dart - Fixes UI/Rendering
```
- Ajouter key: ValueKey(loc['id'].toString()) à ListView.builder items
- Restructure RefreshIndicator: inner ListView → shrinkWrap: true, physics: NeverScrollableScrollPhysics()
- Extract _getFilteredLocations() stable (éviter rebuilds)
- Ajouter mock data si empty (debug)
- Retry auto sur erreur API (3x)
```

## 2. ✅ [DONE] lib/api_service.dart - Timeout 15s sur getLocations()

## 3. ✅ Tests & Feedback Fixes
```
- Filtre 'en_attente' seulement dans _getFilteredLocations() → approved disparaît de pending
- Refresh appareils après approve → disparaît de disponibles
- Snackbar mis à jour
- Prêt pour test final
```

## 3. ⏳ Tests & Validation
```
- Hot reload → vérifier pas de crash console
- Onglet admin Locations → liste pending (empty OK, pas loading infini)
- Créer test location → vérifier "en attente" apparaît
```

## 4. ⏳ Suivi
```
- flutter clean && flutter pub get
- flutter run (émulateur)
- Vérifier logs: "📡 Locations chargées pour admin: X"
```

**Prochaines étapes après edits**:
1. Edits fichiers
2. `flutter run` test
3. Si OK → attempt_completion ✅

**Statut**: Plan approuvé - Prêt pour implémentation

