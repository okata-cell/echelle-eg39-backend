# 📋 Guide du Système de Prolongations

## 🎯 Vue d'ensemble

Le système de prolongations permet aux clients de prolonger leurs locations et au Directeur Général de valider les paiements reçus.

---

## 🔄 Flux Complet (Scénario Utilisateur + Admin)

### 📱 Côté UTILISATEUR (Client)

#### Étape 1️⃣ : Prolonger une location
```
1. L'utilisateur ouvre l'onglet "Historique"
2. Il voit une location "En cours"
3. Il clique sur le bouton vert "Prolonger"
```

#### Étape 2️⃣ : Sélectionner la nouvelle date
```
┌─────────────────────────────────────┐
│ 🔄 Prolonger la Location            │
│ GPS e-survey E600                   │
├─────────────────────────────────────┤
│ ℹ️ Informations actuelles           │
│ Date retour: 10/12/2025             │
│ Tarif/jour: 8 333 FCFA              │
│ Prolongations: 0/3                  │
├─────────────────────────────────────┤
│ 📅 Cliquer pour sélectionner        │
│ → Calendrier s'ouvre                │
│ → Sélectionne 20/12/2025            │
├─────────────────────────────────────┤
│ 🧮 Calcul automatique               │
│ Jours: 10 jours                     │
│ Coût: 83 330 FCFA                   │
└─────────────────────────────────────┘
```

#### Étape 3️⃣ : Confirmer la prolongation
```
✓ Nouvelle date: 20/12/2025
✓ Prolongation: 10 jours
✓ Facture N°: INV-EXT-1-1
⚠️ À payer: 83 330 FCFA
```

**Résultat:**
- Badge orange "Prolong. impayée" apparaît
- Historique des prolongations visible dans la carte
- Bouton orange "Payer prolong." activé

#### Étape 4️⃣ : Payer la prolongation
```
1. Clic sur "Payer prolong."
2. Dialogue s'ouvre avec instructions:
   - Contacter le DG au 99001166 ou 90897654
   - Payer en cash ou transfert
   - Le DG validera le paiement
3. Bouton "Appeler 99001166"
```

**Important:** L'utilisateur **NE PEUT PAS** marquer lui-même comme payé !

---

### 💼 Côté ADMIN (Directeur Général)

#### Étape 1️⃣ : Se connecter à l'espace admin
```
1. Connexion à l'application
2. Navigation vers "ESPACE DIRECTEUR GENERAL - EG39"
3. Onglet "Prolongations" en bas
```

#### Étape 2️⃣ : Voir les prolongations en attente
```
┌─────────────────────────────────────┐
│ 📊 Statistiques                     │
│ Total: 5 | En attente: 2            │
│ À recevoir: 125 000 FCFA            │
├─────────────────────────────────────┤
│ [Non payées] [Payées] [Toutes]     │
└─────────────────────────────────────┘

Liste des prolongations:
┌─────────────────────────────────────┐
│ ⚠️ EN ATTENTE DE PAIEMENT           │
│ INV-EXT-1-1                         │
├─────────────────────────────────────┤
│ 👤 Client XYZ                       │
│ GPS e-survey E600                   │
│                                     │
│ 📅 10/12 → 20/12 (+10j)             │
│ 💰 83 330 FCFA                      │
│                                     │
│ [✓ Confirmer le paiement reçu]     │
└─────────────────────────────────────┘
```

#### Étape 3️⃣ : Le client appelle et paye
```
📞 Appel du client
💵 Paiement reçu (cash/transfert)
```

#### Étape 4️⃣ : Valider le paiement
```
1. DG clique sur "Confirmer le paiement reçu"
2. Dialogue de confirmation s'ouvre:
   ┌─────────────────────────────────┐
   │ ⚠️ Confirmer le paiement        │
   │                                 │
   │ Client: Client XYZ              │
   │ Équipement: GPS e-survey E600   │
   │ Montant: 83 330 FCFA            │
   │ Facture: INV-EXT-1-1            │
   │                                 │
   │ [Annuler] [Oui, j'ai reçu]     │
   └─────────────────────────────────┘
3. Clic sur "Oui, j'ai reçu le paiement"
4. ✓ Prolongation marquée comme payée
```

**Résultat:**
- Badge passe de orange à vert
- Prolongation apparaît dans l'onglet "Payées"
- L'utilisateur voit le badge orange disparaître

---

## 📁 Architecture des Fichiers

### Nouveaux fichiers créés:

1. **`lib/extensions_manager.dart`**
   - Gestionnaire global (Singleton)
   - Stocke toutes les prolongations
   - Méthodes: addExtension, markAsPaid, getUnpaidExtensions, etc.

2. **`lib/admin_prolongations_page.dart`**
   - Interface Admin pour gérer les prolongations
   - Liste des prolongations avec filtres
   - Validation des paiements

### Fichiers modifiés:

3. **`lib/historique.dart`**
   - Utilise ExtensionsManager
   - Suppression du bouton "Marquer comme payé"
   - Dialogue d'instructions de paiement

4. **`lib/AdminDashBoard.dart`**
   - Ajout de l'onglet "Prolongations"
   - Navigation vers AdminProlongationsPage

---

## 🔒 Sécurité

### ✅ Ce qui est sécurisé:

1. **L'utilisateur ne peut PAS marquer comme payé**
   - Seul le DG peut valider
   - Pas de bouton "Marquer comme payé" côté utilisateur

2. **Vérifications multiples:**
   - Max 3 prolongations par location
   - Max 30 jours par prolongation
   - Bloque si prolongations impayées

3. **Traçabilité:**
   - Chaque prolongation a un ID unique
   - Numéro de facture séparé (INV-EXT-X-Y)
   - Historique visible

### ⚠️ Limitations actuelles (Sans Base de Données):

1. **Données perdues si l'app est fermée**
   - Solution future: SQLite ou Firebase

2. **Pas de synchronisation**
   - Utilisateur et Admin doivent être sur le même appareil
   - Solution future: Backend avec API

3. **Pas de notifications**
   - L'utilisateur ne sait pas quand le DG valide
   - Solution future: Push notifications

---

## 🚀 Améliorations Futures Recommandées

### Priorité 1 (Court terme):
- [ ] Ajouter SQLite pour persistance locale
- [ ] Stocker le vrai nom du client (actuellement "Client XYZ")
- [ ] Envoyer SMS de confirmation au client

### Priorité 2 (Moyen terme):
- [ ] Backend avec API REST
- [ ] Synchronisation cloud (Firebase)
- [ ] Notifications push

### Priorité 3 (Long terme):
- [ ] Paiement mobile intégré (TMoney/Flooz)
- [ ] Génération automatique de reçus
- [ ] Tableau de bord analytique

---

## 📞 Support

En cas de problème, contacter:
- **Directeur Général EG39**
- 📞 99001166
- 📞 90897654

---

## ✅ Checklist de Test

Pour tester le système complet:

### Côté Utilisateur:
- [ ] Prolonger une location (max 3 fois)
- [ ] Voir le calcul en temps réel
- [ ] Télécharger la facture de prolongation
- [ ] Cliquer sur "Payer prolong." et voir les instructions
- [ ] Vérifier qu'il n'y a PAS de bouton "Marquer comme payé"

### Côté Admin:
- [ ] Ouvrir l'onglet "Prolongations" dans le dashboard
- [ ] Voir les statistiques
- [ ] Filtrer par "Non payées", "Payées", "Toutes"
- [ ] Confirmer un paiement
- [ ] Vérifier que le badge change côté utilisateur

---

**Date de création:** 2025-12-30  
**Version:** 1.0  
**Statut:** ✅ Opérationnel (sans base de données)