# Plan de Corrections - Problème d'Inscription

## Problème
1. **1er clic** → `{"error":"Erreur serveur"}` (Status 500)
2. **2e clic** → `{"error":"Email ou téléphone déjà utilisé"}` (Status 400)

## Causes identifiées
1. Le téléphone est mis en minuscules dans Flutter (`.toLowerCase()`)
2. Message d'erreur générique qui masque le vrai problème
3. Validation du téléphone insuffisante

## Corrections à appliquer

### 1. `backend/src/routes/auth.js`
- [ ] Améliorer la gestion des erreurs avec messages spécifiques
- [ ] Clarifier la manipulation du téléphone
- [ ] Ajouter validation du format téléphone

### 2. `lib/register.page.dart`
- [ ] Ne pas mettre le téléphone en minuscules

## Étapes
1. Modifier `auth.js` avec meilleure gestion d'erreurs
2. Modifier `register.page.dart` pour supprimer `.toLowerCase()` sur le téléphone
3. Tester l'inscription

