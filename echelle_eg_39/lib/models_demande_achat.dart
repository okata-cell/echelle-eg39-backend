class DemandeAchat {
  final String id;
  final String clientNom;
  final String clientEmail;
  final String clientPhone;
  final String produitId;
  final String produitNom;
  final int produitPrix;
  final int quantite;
  final String statut; // 'en_attente', 'approuvee', 'rejetee', 'livree'
  final DateTime dateCommande;
  final String? commentaireAdmin;

  DemandeAchat({
    required this.id,
    required this.clientNom,
    required this.clientEmail,
    required this.clientPhone,
    required this.produitId,
    required this.produitNom,
    required this.produitPrix,
    this.quantite = 1,
    this.statut = 'en_attente',
    required this.dateCommande,
    this.commentaireAdmin,
  });

  // Calculer le total
  int get total => produitPrix * quantite;

  // Créer une copie avec modifications
  DemandeAchat copyWith({
    String? id,
    String? clientNom,
    String? clientEmail,
    String? clientPhone,
    String? produitId,
    String? produitNom,
    int? produitPrix,
    int? quantite,
    String? statut,
    DateTime? dateCommande,
    String? commentaireAdmin,
  }) {
    return DemandeAchat(
      id: id ?? this.id,
      clientNom: clientNom ?? this.clientNom,
      clientEmail: clientEmail ?? this.clientEmail,
      clientPhone: clientPhone ?? this.clientPhone,
      produitId: produitId ?? this.produitId,
      produitNom: produitNom ?? this.produitNom,
      produitPrix: produitPrix ?? this.produitPrix,
      quantite: quantite ?? this.quantite,
      statut: statut ?? this.statut,
      dateCommande: dateCommande ?? this.dateCommande,
      commentaireAdmin: commentaireAdmin ?? this.commentaireAdmin,
    );
  }
}