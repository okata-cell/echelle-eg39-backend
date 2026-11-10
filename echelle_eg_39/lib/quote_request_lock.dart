// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

/// Une demande de devis reste « vivante » tant que l'équipe n'a pas répondu.
///
/// Le client ne peut déposer qu'une seule demande par prestation dans cet état :
/// le bouton « Demander un devis » est bloqué jusqu'à l'approbation ou le rejet.
/// La même liste est appliquée par le serveur (`POST /api/devis` répond 409),
/// qui reste la référence en cas de renvoi depuis un autre appareil.
const Set<String> statutsDevisEnAttente = <String>{
  'en_attente',
  'en_traitement',
};

/// Vrai si la demande attend encore une décision de l'administration.
bool devisAttendReponse(Object? statut) {
  final valeur = (statut ?? '').toString().trim().toLowerCase();
  return statutsDevisEnAttente.contains(valeur);
}

/// Indexe la demande ouverte par identifiant de service.
///
/// Les devis déjà traités (approuvés, rejetés, terminés) sont ignorés : ils
/// débloquent la prestation pour une nouvelle demande.
Map<String, Map<String, dynamic>> indexerDevisOuverts(
  List<Map<String, dynamic>> devis,
) {
  final index = <String, Map<String, dynamic>>{};

  for (final demande in devis) {
    final serviceId = (demande['serviceId'] ?? '').toString().trim();
    if (serviceId.isEmpty || !devisAttendReponse(demande['statut'])) continue;

    final existante = index[serviceId];
    if (existante == null || _date(demande).isAfter(_date(existante))) {
      index[serviceId] = demande;
    }
  }

  return index;
}

/// La demande ouverte pour ce service, ou `null` si le client peut en déposer une.
Map<String, dynamic>? devisOuvertPourService(
  List<Map<String, dynamic>> devis,
  Object? serviceId,
) {
  final cible = (serviceId ?? '').toString().trim();
  if (cible.isEmpty) return null;

  return indexerDevisOuverts(devis)[cible];
}

/// « En attente de traitement » / « En cours d'examen », aligné sur Mes devis.
String libelleStatutDemande(Object? statut) {
  switch ((statut ?? '').toString().trim().toLowerCase()) {
    case 'en_traitement':
      return 'En cours d’examen';
    case 'en_attente':
      return 'En attente de traitement';
    default:
      return 'En attente de réponse';
  }
}

/// Référence courte affichée sur la carte du service.
String referenceDemande(Object? devisId) {
  final id = devisId?.toString().trim();
  return id == null || id.isEmpty ? '' : 'DEV-$id';
}

/// `10/11/2026` — date d'envoi de la demande.
String dateDemandeLibelle(Object? createdAt) {
  final date = DateTime.tryParse((createdAt ?? '').toString())?.toLocal();
  if (date == null) return '';

  final jour = date.day.toString().padLeft(2, '0');
  final mois = date.month.toString().padLeft(2, '0');
  return 'Envoyée le $jour/$mois/${date.year}';
}

DateTime _date(Map<String, dynamic> demande) {
  return DateTime.tryParse((demande['createdAt'] ?? '').toString()) ??
      DateTime.fromMillisecondsSinceEpoch(0);
}
