class TransactionModel {
  final String appareil;
  final String type; // location ou vente
  final int montant;
  final DateTime? dateFin;
  final String statut; // en_cours, termine, retard

  TransactionModel({
    required this.appareil,
    required this.type,
    required this.montant,
    this.dateFin,
    required this.statut,
  });
}