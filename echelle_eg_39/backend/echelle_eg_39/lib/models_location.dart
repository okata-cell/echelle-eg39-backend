class Location {
  final String id;
  final String appareilNom;
  DateTime dateDebut;
  DateTime dateFin;
  final int montant;
  bool terminee;

  Location({
    required this.id,
    required this.appareilNom,
    required this.dateDebut,
    required this.dateFin,
    required this.montant,
    this.terminee = false,
  });

  bool get enRetard =>
      DateTime.now().isAfter(dateFin) && !terminee;
}