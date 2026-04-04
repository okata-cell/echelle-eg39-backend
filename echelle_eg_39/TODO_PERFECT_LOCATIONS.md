# Améliorations Onglet Admin Locations d'Appareils - Approved Plan

**Statut: En cours**

1. ✅ [DONE] Créer TODO + analyse fichiers (data_manager.dart, models_location.dart, pubspec.yaml OK - intl/http déjà présents)

**Étapes restantes:**
- [ ] 1. lib/api_service.dart: Ajouter getAppareils(), createLocation()
- [ ] 2. lib/LocationsMenu.dart: 
  - Remplacer mock appareils par API real 
  - Dialog location: DatePickers + API createLocation
  - Ajouter search bar (filter clients/code)
  - Pull-to-refresh (RefreshIndicator)
  - Tabs Pending/All + empty states/skeleton
- [ ] 3. Test: flutter run
- [ ] 4. Commit/push

Pas de Timer auto-refresh (per user).

