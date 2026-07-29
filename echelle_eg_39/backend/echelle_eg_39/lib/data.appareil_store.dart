class Appareil {
  final String id;
  final String nom;
  final String type;
  final String imageUrl;
  final int prixLocation;
  final int prixVente;

  bool disponible;

  Appareil({
    required this.id,
    required this.nom,
    required this.type,
    required this.imageUrl,
    required this.prixLocation,
    required this.prixVente,
    this.disponible = true,
  });
}

class AppareilStore {
  static final List<Appareil> appareils = [];
}