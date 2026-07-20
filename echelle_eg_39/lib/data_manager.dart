import 'package:flutter/material.dart';
import 'models_demande_achat.dart';
import 'appareil_images.dart';

// Modèle pour un client
class Client {
  final String id;
  final String name;
  final String? email;
  final String? phone;

  Client({
    required this.id,
    required this.name,
    this.email,
    this.phone,
  });

  // Convertir en Map pour la sauvegarde
  Map<String, String> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email ?? '',
      'phone': phone ?? '',
    };
  }

  // Créer un client à partir d'une Map
  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'],
      name: map['name'],
      email: map['email'].isNotEmpty ? map['email'] : null,
      phone: map['phone'].isNotEmpty ? map['phone'] : null,
    );
  }
}

// Modèle pour un appareil
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

// Gestionnaire global des données
class DataManager extends ChangeNotifier {
  static final DataManager _instance = DataManager._internal();
  factory DataManager() => _instance;
  DataManager._internal();

  // Liste des clients
  final List<Client> _clients = [];

  // Clients par défaut pour la démo
  final List<Client> _defaultClients = [
    Client(id: 'C-0001', name: 'Client A', email: 'clienta@example.com', phone: '123456789'),
    Client(id: 'C-0002', name: 'Client B', email: 'clientb@example.com', phone: '987654321'),
    Client(id: 'C-0003', name: 'Client C', email: 'clientc@example.com', phone: '456789123'),
  ];

  // Liste des appareils
  final List<Appareil> _appareils = [];

  // Appareils par défaut pour la démo
  final List<Appareil> _defaultAppareils = [
     Appareil(
        id: "APP-001",
        nom: "GPS e-survey E600",
        type: "GPS",
        imageUrl: AppareilImages.getImageUrlForAppareilId("APP-001"),
        prixLocation: 25000,
        prixVente: 2500000,
      ),
    Appareil(
      id: "APP-002",
      nom: "GPS e-survey E800",
      type: "GPS",
      imageUrl: AppareilImages.getImageUrlForAppareilId("APP-002"),
      prixLocation: 15000,
      prixVente: 1200000,
    ),
    Appareil(
      id: "APP-003",
      nom: "Niveau Leica",
      type: "Niveau",
      imageUrl: AppareilImages.getImageUrlForAppareilId("APP-003"),
      prixLocation: 15000,
      prixVente: 1200000,
    ),
    Appareil(
      id: "APP-004",
      nom: "Niveau Electronique Leica",
      type: "Niveau",
      imageUrl: AppareilImages.getImageUrlForAppareilId("APP-004"),
      prixLocation: 30000,
      prixVente: 3500000,
    ),
     Appareil(
       id: "APP-005",
       nom: "Theodolite",
       type: "Station totale",
       imageUrl: AppareilImages.getImageUrlForAppareilId("APP-005"),
       prixLocation: 30000,
       prixVente: 3500000,
     ),
     Appareil(
       id: "APP-006",
       nom: "Station Totale Leica TS06",
       type: "Theodolite",
       imageUrl: AppareilImages.getImageUrlForAppareilId("APP-006"),
       prixLocation: 30000,
       prixVente: 3500000,
     ),
    Appareil(
        id: "APP-007",
        nom: "GPS e-survey E300",
        type: "GPS",
        imageUrl: AppareilImages.getImageUrlForAppareilId("APP-007"),
        prixLocation: 25000,
        prixVente: 2500000,
      ),
    Appareil(
      id: "APP-008",
      nom: "Trepied Leica",
      type: "Trepied",
      imageUrl: AppareilImages.getImageUrlForAppareilId("APP-008"),
      prixLocation: 15000,
      prixVente: 1200000,
    ),
    Appareil(
      id: "APP-009",
      nom: "Mire Stadimetrique",
      type: "Mire",
      imageUrl: AppareilImages.getImageUrlForAppareilId("APP-009"),
      prixLocation: 15000,
      prixVente: 1200000,
    ),
    Appareil(
      id: "APP-010",
      nom: "Antenne GPS RTK",
      type: "Antenne",
      imageUrl: AppareilImages.getImageUrlForAppareilId("APP-010"),
      prixLocation: 50000,
      prixVente: 5000000,
    ),
    Appareil(
      id: "APP-011",
      nom: "Canne GPS",
      type: "Canne",
      imageUrl: AppareilImages.getImageUrlForAppareilId("APP-011"),
      prixLocation: 12000,
      prixVente: 1200000,
    ),
    Appareil(
      id: "APP-012",
      nom: "Reflecteur Leica",
      type: "Reflecteur",
      imageUrl: AppareilImages.getImageUrlForAppareilId("APP-012"),
      prixLocation: 8000,
      prixVente: 800000,
    ),
    Appareil(
      id: "APP-013",
      nom: "Drone topographique",
      type: "Drone",
      imageUrl: AppareilImages.getImageUrlForAppareilId("APP-013"),
      prixLocation: 100000,
      prixVente: 10000000,
    ),
    Appareil(
      id: "APP-014",
      nom: "GPS Trimble R10",
      type: "GPS",
      imageUrl: AppareilImages.getImageUrlForAppareilId("APP-014"),
      prixLocation: 35000,
      prixVente: 3500000,
    ),
    Appareil(
      id: "APP-015",
      nom: "GPS Leica GS18 T",
      type: "GPS",
      imageUrl: AppareilImages.getImageUrlForAppareilId("APP-015"),
      prixLocation: 40000,
      prixVente: 4000000,
    ),
    Appareil(
      id: "APP-016",
      nom: "GPS Topcon Hiper VR",
      type: "GPS",
      imageUrl: AppareilImages.getImageUrlForAppareilId("APP-016"),
      prixLocation: 38000,
      prixVente: 3800000,
    ),
    Appareil(
      id: "APP-017",
      nom: "GPS Spectra SP80",
      type: "GPS",
      imageUrl: AppareilImages.getImageUrlForAppareilId("APP-017"),
      prixLocation: 32000,
      prixVente: 3200000,
    ),
    Appareil(
      id: "APP-018",
      nom: "Niveau Automatique Leica NA720",
      type: "Niveau",
      imageUrl: AppareilImages.getImageUrlForAppareilId("APP-018"),
      prixLocation: 18000,
      prixVente: 1500000,
    ),
    Appareil(
      id: "APP-019",
      nom: "Niveau Numérique Leica DNA03",
      type: "Niveau",
      imageUrl: AppareilImages.getImageUrlForAppareilId("APP-019"),
      prixLocation: 45000,
      prixVente: 4500000,
    ),
    Appareil(
      id: "APP-020",
      nom: "Niveau Topcon AT-B2",
      type: "Niveau",
      imageUrl: AppareilImages.getImageUrlForAppareilId("APP-020"),
      prixLocation: 16000,
      prixVente: 1400000,
    ),
    Appareil(
      id: "APP-021",
      nom: "Station Totale Leica TS16",
      type: "Station totale",
      imageUrl: AppareilImages.getImageUrlForAppareilId("APP-021"),
      prixLocation: 80000,
      prixVente: 8000000,
    ),
    Appareil(
      id: "APP-022",
      nom: "Station Totale Topcon GT-1200",
      type: "Station totale",
      imageUrl: AppareilImages.getImageUrlForAppareilId("APP-022"),
      prixLocation: 75000,
      prixVente: 7500000,
    ),
    Appareil(
      id: "APP-023",
      nom: "Station Totale Sokkia IX-1000",
      type: "Station totale",
      imageUrl: AppareilImages.getImageUrlForAppareilId("APP-023"),
      prixLocation: 70000,
      prixVente: 7000000,
    ),
    Appareil(
      id: "APP-024",
      nom: "Théodolite Électronique Leica TPS1200",
      type: "Théodolite",
      imageUrl: AppareilImages.getImageUrlForAppareilId("APP-024"),
      prixLocation: 55000,
      prixVente: 5500000,
    ),
    Appareil(
      id: "APP-025",
      nom: "Réflecteur Sphérique Leica GPR121",
      type: "Réflecteur",
      imageUrl: AppareilImages.getImageUrlForAppareilId("APP-025"),
      prixLocation: 15000,
      prixVente: 1500000,
    ),
    Appareil(
      id: "APP-026",
      nom: "Mire à Prismes Leica GMP101",
      type: "Mire",
      imageUrl: AppareilImages.getImageUrlForAppareilId("APP-026"),
      prixLocation: 12000,
      prixVente: 1200000,
    ),
    Appareil(
      id: "APP-027",
      nom: "Canne Télescopique Leica GLS121",
      type: "Canne",
      imageUrl: AppareilImages.getImageUrlForAppareilId("APP-027"),
      prixLocation: 20000,
      prixVente: 2000000,
    ),
    Appareil(
      id: "APP-028",
      nom: "Antenne GPS Externe Leica AX1200G",
      type: "Antenne",
      imageUrl: AppareilImages.getImageUrlForAppareilId("APP-028"),
      prixLocation: 60000,
      prixVente: 6000000,
    ),
    Appareil(
      id: "APP-029",
      nom: "Batterie GPS Leica GEV240",
      type: "Accessoire",
      imageUrl: AppareilImages.getImageUrlForAppareilId("APP-029"),
      prixLocation: 5000,
      prixVente: 500000,
    ),
    Appareil(
      id: "APP-030",
      nom: "Chargeur GPS Leica GEV242",
      type: "Accessoire",
      imageUrl: AppareilImages.getImageUrlForAppareilId("APP-030"),
      prixLocation: 4000,
      prixVente: 400000,
    ),
    Appareil(
      id: "APP-031",
      nom: "Housse de Protection GPS",
      type: "Accessoire",
      imageUrl: AppareilImages.getImageUrlForAppareilId("APP-031"),
      prixLocation: 3000,
      prixVente: 300000,
    ),
    Appareil(
      id: "APP-032",
      nom: "Drone DJI Phantom 4 RTK",
      type: "Drone",
      imageUrl: AppareilImages.getImageUrlForAppareilId("APP-032"),
      prixLocation: 120000,
      prixVente: 12000000,
    ),
    Appareil(
      id: "APP-033",
      nom: "Drone DJI Matrice 300 RTK",
      type: "Drone",
      imageUrl: AppareilImages.getImageUrlForAppareilId("APP-033"),
      prixLocation: 250000,
      prixVente: 25000000,
    ),
  ];

  // Liste des demandes d'achat
  final List<DemandeAchat> _demandesAchat = [];

  bool _initialized = false;

  // Initialiser avec les clients et appareils par défaut
  void initialize() {
    if (!_initialized) {
      _clients.addAll(_defaultClients);
      _appareils.addAll(_defaultAppareils);
      _initialized = true;
      notifyListeners();
    }
  }

  // Obtenir tous les clients
  List<Client> get clients => List.unmodifiable(_clients);

  // Obtenir les noms des clients (pour les dropdowns)
  List<String> get clientNames => _clients.map((client) => client.name).toList();

  // Obtenir tous les appareils
  List<Appareil> get appareils => List.unmodifiable(_appareils);

  // Ajouter un nouveau client
  void addClient(Client client) {
    _clients.add(client);
    notifyListeners(); // Notifier tous les listeners
  }

  // Modifier un client existant
  void updateClient(int index, Client client) {
    if (index >= 0 && index < _clients.length) {
      _clients[index] = client;
      notifyListeners();
    }
  }

  // Supprimer un client
  void removeClient(int index) {
    if (index >= 0 && index < _clients.length) {
      _clients.removeAt(index);
      notifyListeners();
    }
  }

  // Rechercher un client par nom
  Client? getClientByName(String name) {
    try {
      return _clients.firstWhere((client) => client.name == name);
    } catch (e) {
      return null;
    }
  }

  // Rechercher un client par ID
  Client? getClientById(String id) {
    try {
      return _clients.firstWhere((client) => client.id == id);
    } catch (e) {
      return null;
    }
  }

  // Vider la liste des appareils
  void clearAppareils() {
    _appareils.clear();
    notifyListeners();
  }

  // Charger les appareils par défaut
  void loadDefaultAppareils() {
    _appareils.clear();
    _appareils.addAll(_defaultAppareils);
    notifyListeners();
  }

  // Ajouter un nouvel appareil
  void addAppareil(Appareil appareil) {
    _appareils.add(appareil);
    notifyListeners();
  }

  // Modifier un appareil existant
  void updateAppareil(int index, Appareil appareil) {
    if (index >= 0 && index < _appareils.length) {
      _appareils[index] = appareil;
      notifyListeners();
    }
  }

  // Supprimer un appareil
  void removeAppareil(int index) {
    if (index >= 0 && index < _appareils.length) {
      _appareils.removeAt(index);
      notifyListeners();
    }
  }

  // Changer la disponibilité d'un appareil
  void toggleDisponibilite(int index) {
    if (index >= 0 && index < _appareils.length) {
      _appareils[index].disponible = !_appareils[index].disponible;
      notifyListeners();
    }
  }

  // === GESTION DES DEMANDES D'ACHAT ===

  // Obtenir toutes les demandes d'achat
  List<DemandeAchat> get demandesAchat => List.unmodifiable(_demandesAchat);

  // Obtenir le nombre de demandes en attente
  int get nombreDemandesEnAttente => 
    _demandesAchat.where((d) => d.statut == 'en_attente').length;

  // Ajouter une nouvelle demande d'achat
  String addDemandeAchat({
    required String clientNom,
    required String clientEmail,
    required String clientPhone,
    required String produitId,
    required String produitNom,
    required int produitPrix,
    int quantite = 1,
  }) {
    final id = 'DA-${DateTime.now().millisecondsSinceEpoch}';
    final demande = DemandeAchat(
      id: id,
      clientNom: clientNom,
      clientEmail: clientEmail,
      clientPhone: clientPhone,
      produitId: produitId,
      produitNom: produitNom,
      produitPrix: produitPrix,
      quantite: quantite,
      dateCommande: DateTime.now(),
    );
    
    _demandesAchat.insert(0, demande); // Ajouter au début de la liste
    notifyListeners();
    return id;
  }

  // Modifier le statut d'une demande
  void updateDemandeStatut(String demandeId, String nouveauStatut, {String? commentaire}) {
    final index = _demandesAchat.indexWhere((d) => d.id == demandeId);
    if (index != -1) {
      _demandesAchat[index] = _demandesAchat[index].copyWith(
        statut: nouveauStatut,
        commentaireAdmin: commentaire,
      );
      notifyListeners();
    }
  }

  // Supprimer une demande
  void removeDemande(String demandeId) {
    _demandesAchat.removeWhere((d) => d.id == demandeId);
    notifyListeners();
  }

  // Obtenir les demandes par statut
  List<DemandeAchat> getDemandesByStatut(String statut) {
    if (statut == 'tous') return demandesAchat;
    return _demandesAchat.where((d) => d.statut == statut).toList();
  }

  // Obtenir les demandes d'un client
  List<DemandeAchat> getDemandesByClient(String clientEmail) {
    return _demandesAchat.where((d) => d.clientEmail == clientEmail).toList();
  }
}
