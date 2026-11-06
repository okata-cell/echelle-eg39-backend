# Protéger le code lors de la livraison — exemples concrets

Deux pièces, deux usages : un **contrat** qui rend la copie fautive, et un
**watermark** qui la rend prouvable. Les exemples ci-dessous sont rédigés pour
le projet ÉCHELLE EG39 (client + développeur tiers) et doivent être relus par un
avocat avant signature — ce sont des modèles, pas un avis juridique.

---

## 1. Exemple de contrat — extraits utilisables

**Titre** : Contrat de cession de droits d'utilisation et de confidentialité
**Parties** :

- `ÉCHELLE EG39`, Lomé, Rue des frères franciscains, après les rails — Togo
  (ci-après « le Prestataire ») ;
- `[Nom du client]`, ci-après « le Client » ;
- `[Nom du développeur / société tierce]`, ci-après « le Repreneur ».

### Art. 1 — Objet et inventaire du code livré

Le Prestataire livre l'Application ÉCHELLE EG39 (Flutter, Android et iOS) et son
backend (Node.js), tels qu'inventoriés en **Annexe A** : liste des fichiers,
version (`tag`), empreinte `SHA-256` de l'archive, date de livraison.

> Exemple d'annexe : « Livraison `EG39-20270312-9F3A`, archive
> `echelle-eg39-20270312.zip`, 412 fichiers, empreinte
> `9f3a1c…e07b`, commit source `dffd7c0`, 12 mars 2027. »

### Art. 2 — Propriété : choisir un modèle, pas les deux

- **Modèle A (recommandé si le Prestataire veut garder la main)** : le Prestataire
  reste titulaire des droits patrimoniaux ; le Client obtient une **licence
  d'utilisation, de modification et d'exploitation** de l'Application, pour ses
  propres besoins, sans droit de réutilisation du code pour un autre produit.
- **Modèle B (le Client possède)** : le Prestataire cède au Client les droits
  patrimoniaux sur le code livré, à l'exclusion expresse des composants tiers
  (packages MIT/BSD, polices, cartes) qui restent sous leurs licences d'origine.

Dans les deux modèles, la cession ou la licence est **subordonnée au paiement
intégral** du prix.

### Art. 3 — Interdiction de réutilisation (la clause qui compte)

> « Le Repreneur s'interdit, pendant et après l'exécution de sa mission et sans
> limitation de durée, de reproduire, réutiliser, adapter, traduire, extraire ou
> transposer, en tout ou en partie, le code source, les maquettes, les textes,
> les éléments graphiques, les jeux de données ou l'architecture de
> l'Application, pour son compte ou pour le compte d'un tiers, y compris sous
> une forme modifiée, obfusquée ou intégrée à un autre produit.
>
> Cette interdiction couvre notamment la réutilisation de tout ou partie de
> l'interface, de la structure de données, des règles de calcul commerciales et
> des procédures métier de l'Application. »

### Art. 4 — Confidentialité

> « Le Repreneur garde confidentiels le code, les accès techniques et les
> informations commerciales pendant la mission et **cinq ans** après sa fin. Il
> ne conserve qu'une copie de travail, la supprime à la fin de la mission et
> atteste par écrit de cette suppression dans les quinze jours. »

### Art. 5 — Marquage et preuve

> « Le Repreneur reconnaît que le code livré comporte des **marques
> d'identification** (en-têtes de copyright et identifiant de livraison) ainsi
> qu'une empreinte `SHA-256` consignée en Annexe A. Leur suppression, altération
> ou remplacement vaut **présomption de contrefaçon**. Le Client peut faire
> vérifier le respect du présent contrat par un tiers indépendant, sur
> préavis de sept jours. »

### Art. 6 — Sanction

> « Tout manquement aux articles 3 à 5 donne lieu au paiement d'une indemnité
> forfaitaire de `[montant, par ex. 5 000 000 FCFA]` par manquement constaté,
> sans préjudice des dommages et intérêts complémentaires, de la cessation de
> l'exploitation du produit contrefaisant et de la publication de la décision. »

### Art. 7 — Droit applicable

> « Droit togolais. Tribunaux de Lomé, sauf arbitrage CCJA (OHADA) choisi d'un
> commun accord. »

**Coût réel** : 2 à 3 heures de rédaction, puis relecture par un avocat. C'est
la dépense la plus rentable de tout le dispositif.

---

## 2. Exemple de watermark — ce que ça donne concrètement

### a. Fichier généré à chaque livraison (`lib/watermark.g.dart`)

```dart
// © 2026 ÉCHELLE EG39 — Tous droits réservés.
// Livraison EG39-20270312-9F3A à [Client]. Reproduction interdite.
// Fichier généré par tools/watermark.sh — ne pas modifier à la main.
class BuildWatermark {
  static const String owner = 'ÉCHELLE EG39';
  static const String licensee = 'Société ABC SARL';
  static const String deliveredAt = '2027-03-12T09:00:00Z';
  static const String deliveryId = 'EG39-20270312-9F3A';
  static const String sourceCommit = 'dffd7c0';
  static const String sourceFingerprint = '9f3a1c7b4d2e8a05';
}
```

Utilisé à un endroit visible : l'écran « À propos » affiche `deliveryId` en petit
sous le numéro de version. Un code recopié ailleurs porte donc la trace, à
l'écran **et** dans le binaire.

### b. En-tête ajouté dans chaque fichier source

```dart
// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20270312-9F3A
```

```js
// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20270312-9F3A
```

### c. Manifeste de livraison (`ANNEXE-A.md`, signé et archivé)

```
Livraison   : EG39-20270312-9F3A
Date        : 2027-03-12 09:00 UTC
Commit      : dffd7c0 (signé GPG)
Archive     : echelle-eg39-20270312.zip
Empreinte   : 9f3a1c7b4d2e8a05…e07b   (sha256 de l'archive)
Fichiers    : 412
Vérification: shasum -a 256 -c ANNEXE-A.sha256
```

### d. Comment ça sert le jour où le code réapparaît ailleurs

1. Une chaîne rare est propre à la livraison : `EG39-20270312-9F3A`.
2. On la cherche dans un APK suspect :
   `unzip -p suspect.apk classes.dex | strings | grep EG39-2027`
   ou dans un dépôt : `grep -r "EG39-20270312" .`
3. On retrouve l'identifiant, le nom du client et la date → le lien avec la
   livraison est établi, sans expertise technique.
4. L'empreinte `SHA-256` de l'archive prouve que le fichier livré est bien
   celui qu'on compare.

**Ce que ça ne fait pas** : ça n'empêche pas la copie, et un développeur peut
retirer les en-têtes. Mais retirer volontairement une mention de copyright est
en soi un indice de mauvaise foi, et l'identifiant est souvent enfoui à
plusieurs endroits (en-têtes, constante compilée, écran, documentation).

**Coût réel** : un script de 40 lignes, une heure de mise en place, réutilisable
à chaque livraison.

---

## Ce qu'il faut éviter

- Promettre « le code ne peut pas être copié » : faux, et ça vous affaiblit en
  cas de litige.
- Ajouter du DRM ou une détection de clonage : coût élevé, contournement facile.
- Oublier les composants tiers : les packages Flutter (MIT/BSD) restent
  réutilisables par n'importe qui ; votre interdiction ne porte que sur votre
  code. Conservez leurs mentions dans `NOTICE`.
