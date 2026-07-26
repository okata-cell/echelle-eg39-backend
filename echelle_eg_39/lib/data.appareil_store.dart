class Appareil {
  final String id;
  final int? dbId; // ID de la base de données (pour les opérations PUT/DELETE)
  final String nom;
  final String type;
  final String imageUrl;
  final int prixLocation;
  final int prixVente;

  bool disponible;

  Appareil({
    required this.id,
    this.dbId,
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