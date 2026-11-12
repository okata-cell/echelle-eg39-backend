// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

/// Une demande cliente consignée dans le journal d'activité administrateur.
///
/// Le serveur l'écrit au moment où la demande est créée (`admin_events`) : rien
/// ne transite par un service de notification externe.
class AdminActivityEvent {
  const AdminActivityEvent({
    required this.id,
    required this.kind,
    required this.reference,
    required this.titre,
    required this.createdAt,
    this.demandeur,
    this.montant,
    this.readAt,
    this.description,
    this.demandeStatut,
    this.supprimable = false,
  });

  factory AdminActivityEvent.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'];
    return AdminActivityEvent(
      id: _entier(json['id']),
      kind: (json['kind'] ?? '').toString(),
      reference: (json['reference'] ?? '').toString(),
      titre: (json['titre'] ?? '').toString(),
      demandeur: _texte(json['demandeur']),
      montant: json['montant'] == null ? null : _entier(json['montant']),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString())?.toLocal() ??
          DateTime.now(),
      readAt: DateTime.tryParse((json['readAt'] ?? '').toString())?.toLocal(),
      description: metadata is Map ? _texte(metadata['description']) : null,
      demandeStatut: _texte(json['demandeStatut']),
      supprimable: json['supprimable'] == true,
    );
  }

  /// Identifiant du journal côté serveur (acquittement).
  final int id;

  /// `location`, `vente` ou `devis`.
  final String kind;

  /// Référence métier affichée à l'admin (`LOC-…`, `DA-…`, `DEV-…`).
  final String reference;

  /// Matériel demandé ou objet du devis.
  final String titre;

  /// Nom et téléphone du client, quand ils sont connus.
  final String? demandeur;

  /// Montant engagé, en FCFA.
  final int? montant;

  final DateTime createdAt;

  /// Nul tant que la demande n'a pas été ouverte par un administrateur.
  final DateTime? readAt;

  /// Précision libre du devis (description saisie par le client).
  final String? description;

  /// Statut actuel de la demande liée (`termine`, `en_cours`, `rejetee`…).
  final String? demandeStatut;

  /// Vrai quand le serveur autorise le retrait de cette ligne du journal :
  /// la demande est close (terminée, livrée ou annulée).
  final bool supprimable;

  bool get nonLu => readAt == null;

  String get moduleLabel => switch (kind) {
    'location' => 'Locations',
    'vente' => 'Ventes',
    'devis' => 'Devis',
    _ => 'Activité',
  };

  AdminActivityEvent marqueLu(DateTime instant) => AdminActivityEvent(
    id: id,
    kind: kind,
    reference: reference,
    titre: titre,
    createdAt: createdAt,
    demandeur: demandeur,
    montant: montant,
    readAt: instant,
    description: description,
    demandeStatut: demandeStatut,
    supprimable: supprimable,
  );
}

/// Regroupement par journée, tel que présenté dans la feuille Activité.
class AdminActivityJour {
  const AdminActivityJour({required this.entete, required this.evenements});

  final String entete;
  final List<AdminActivityEvent> evenements;
}

const List<String> _mois = <String>[
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

int _entier(Object? value) => num.tryParse('${value ?? 0}')?.toInt() ?? 0;

String? _texte(Object? value) {
  final texte = value?.toString().trim();
  return texte == null || texte.isEmpty ? null : texte;
}

/// `20:44` — heure locale, chiffres tabulaires côté widget.
String heureActivite(DateTime instant) =>
    '${instant.hour.toString().padLeft(2, '0')}:'
    '${instant.minute.toString().padLeft(2, '0')}';

/// « il y a 12 s », « il y a 4 min », « hier ».
String ancienneteActivite(DateTime moment, {DateTime? maintenant}) {
  final reference = maintenant ?? DateTime.now();
  final ecart = reference.difference(moment);

  if (ecart.inSeconds < 10) return 'à l’instant';
  if (ecart.inSeconds < 60) return 'il y a ${ecart.inSeconds} s';

  if (ecart.inMinutes < 60) return 'il y a ${ecart.inMinutes} min';
  if (ecart.inHours < 24) return 'il y a ${ecart.inHours} h';

  final jours = _joursEntre(moment, reference);
  if (jours == 1) return 'hier';
  if (jours < 7) return 'il y a $jours jours';

  return 'le ${dateCourteActivite(moment)}';
}

/// `08/11/2026`.
String dateCourteActivite(DateTime instant) =>
    '${instant.day.toString().padLeft(2, '0')}/'
    '${instant.month.toString().padLeft(2, '0')}/${instant.year}';

bool _memeJour(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

int _joursEntre(DateTime a, DateTime b) {
  final jourA = DateTime(a.year, a.month, a.day);
  final jourB = DateTime(b.year, b.month, b.day);
  return jourB.difference(jourA).inDays;
}

String _enteteJour(DateTime instant, DateTime maintenant) {
  if (_memeJour(instant, maintenant)) return 'Aujourd’hui';
  if (_joursEntre(instant, maintenant) == 1) {
    return 'Hier, ${instant.day} ${_mois[instant.month - 1]}';
  }
  if (instant.year == maintenant.year) {
    return '${instant.day} ${_mois[instant.month - 1]}';
  }
  return '${instant.day} ${_mois[instant.month - 1]} ${instant.year}';
}

/// Sections « Aujourd’hui / Hier / 8 novembre » de la feuille Activité.
List<AdminActivityJour> grouperParJour(
  List<AdminActivityEvent> evenements, {
  DateTime? maintenant,
}) {
  final reference = maintenant ?? DateTime.now();
  final sections = <AdminActivityJour>[];

  for (final evenement in evenements) {
    final entete = _enteteJour(evenement.createdAt, reference);
    if (sections.isNotEmpty && sections.last.entete == entete) {
      sections.last.evenements.add(evenement);
      continue;
    }
    sections.add(
      AdminActivityJour(
        entete: entete,
        evenements: <AdminActivityEvent>[evenement],
      ),
    );
  }

  return sections;
}
