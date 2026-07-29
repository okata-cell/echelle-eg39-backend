# Plan de correction - Écran blanc au démarrage

## Problème identifié
L'application lance sur l'émulateur mais affiche un écran blanc.

## Causes possibles
1. **Firebase.initializeApp()** - Bloquait sans timeout
2. **Appels réseau** - `_attemptStartupSync()` faisait des requêtes HTTP qui bloquaient l'affichage
3. **Pas de gestion d'erreur** - Si Firebase ou l'API échouait, l'app se bloquait

## Corrections appliquées

### ✅ Étape 1: main.dart
- Ajout timeout 10 secondes pour Firebase.initializeApp()
- Gestion d'erreur si Firebase échoue (continue en mode offline)
- Utilisation de addPostFrameCallback pour ne pas bloquer l'affichage
- Réduction du délai d'attente de 2s à 1.5s
- Timeouts sur tous les appels réseau (3-5 secondes)
- Synchronisation en arrière-plan (ne bloque plus l'UI)

### ✅ Étape 2: sync_service.dart
- Réduction du timeout API de 5s à 3s

## Résultats attendus
- Le splash screen devrait s'afficher immédiatement
- La synchronisation se fait en arrière-plan
- L'app ne se bloque plus si Firebase ou l'API échoue

