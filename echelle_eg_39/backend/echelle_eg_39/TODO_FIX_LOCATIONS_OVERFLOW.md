# TODO_FIX_LOCATIONS_OVERFLOW.md
Correction overflow boutons "Louer" - lib/LocationsMenu.dart

## Status
- [x] 1. Plan approuvé par user
- [x] 2. Créer TODO ✅ **DONE**
- [x] 3. Modifier SliverGrid childAspectRatio → 0.90 ✅ (Round 2)
- [x] 4. Optimiser _buildAppareilCard() : flex 3/2→2/3 + padding↓ + Spacer→SizedBox ✅
- [x] 5. Fix Row header appareils (Expanded) ✅
- [x] 6. Réduire bottom padding (100→20px) ✅
- [x] 7. ✅ Dropdown FIXED (syntax + doublons + null safe)
- [ ] 8. Test `flutter run` → Louer appareil → Dialog OK
- [ ] 8. ✅ attempt_completion

## Modifications appliquées
```
✅ childAspectRatio: 0.75 → 0.85 (plus haut)
✅ bottom padding: 100px → 20px
✅ Row header: spaceBetween → Expanded(Text)
✅ _buildAppareilCard(): padding↓, fontSize↓, button minHeight=32px
```

## Objectif ✅
Corriger "RenderFlex overflowed by 27 pixels on the bottom" sur boutons "Louer".

**Tests** : 
1. AdminDashboard → onglet Locations
2. Section "Appareils disponibles" 
3. Scroll → boutons "Louer" sans overflow jaune/noir

Si OK après `flutter run` → Dites "test ok" pour finaliser.
