import 'package:flutter/material.dart';
import 'models_demande_achat.dart';

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
      imageUrl: "https://gms.gumtree.co.za/v2/images/za_ads_134213409_260118_696cd9fe200cfa000a9b8d85?size=l",
      prixLocation: 25000,
      prixVente: 2500000,
    ),
    Appareil(
      id: "APP-002",
      nom: "GPS e-survey E800",
      type: "GPS",
      imageUrl: "https://rtkvn.vn/wp-content/uploads/2020/12/may-gps-rtk-esurvey-e800-3-e1713953679130.jpg",
      prixLocation: 15000,
      prixVente: 1200000,
    ),
    Appareil(
      id: "APP-003",
      nom: "Niveau Leica",
      type: "Niveau",
      imageUrl: "https://m.media-amazon.com/images/I/61RMLIoYh6L._AC_UF894,1000_QL80_.jpg",
      prixLocation: 15000,
      prixVente: 1200000,
    ),
    Appareil(
      id: "APP-004",
      nom: "Niveau Electronique Leica",
      type: "Niveau",
      imageUrl: "https://topomaroc.com/wp-content/uploads/2023/01/leica-leica-sprinter-150m-762630-22627509.jpg",
      prixLocation: 30000,
      prixVente: 3500000,
    ),
    Appareil(
      id: "APP-005",
      nom: "Theodolite",
      type: "Station totale",
      imageUrl: "https://lh3.googleusercontent.com/proxy/QENf36FM_QOdPL6EZH4wI_mdJVA-cOVzGoCq9YObvGEWYvpGcaRmBsVgTWI3GLlrkGR7jzkRbtBr7cEDfyyur-jmBzWb6cVX2D7mz65KR8Zxj7Ga5zjz-y-ZC0xjf68PoItOFpCRZW6PjvtgIBQ4tX6Jyg",
      prixLocation: 30000,
      prixVente: 3500000,
    ),
    Appareil(
      id: "APP-006",
      nom: "Station Totale Leica TS06",
      type: "Theodolite",
      imageUrl: "https://e-prisme.fr/wp-content/uploads//2024/06/IMG_20240530_163035785-scaled.jpg",
      prixLocation: 30000,
      prixVente: 3500000,
    ),
    Appareil(
      id: "APP-007",
      nom: "GPS e-survey E300",
      type: "GPS",
      imageUrl: "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTXVhndu87ZoY0ur817KW0AD2_FNPdaaZHzqw&s",
      prixLocation: 25000,
      prixVente: 2500000,
    ),
    Appareil(
      id: "APP-008",
      nom: "Trepied Leica",
      type: "Trepied",
      imageUrl: "https://www.lepont.fr/30189-large_default/trepied-leica-cpt103-cpt104-mi-lourd.jpg",
      prixLocation: 15000,
      prixVente: 1200000,
    ),
    Appareil(
      id: "APP-009",
      nom: "Mire Stadimetrique",
      type: "Mire",
      imageUrl: "https://www.scors.fr/medias/photos-catalogue/6/G/G2/MIT.jpg",
      prixLocation: 15000,
      prixVente: 1200000,
    ),
    Appareil(
      id: "APP-011",
      nom: "Antenne GPS",
      type: "Antenne",
      imageUrl: "https://m.media-amazon.com/images/I/41B4Q7zJuhL._AC_UF894,1000_QL80_.jpg",
      prixLocation: 50000,
      prixVente: 5000000,
    ),
    Appareil(
      id: "APP-012",
      nom: "Canne GPS",
      type: "Canne",
      imageUrl: "https://m.media-amazon.com/images/I/61D+67Fr13L.jpg",
      prixLocation: 12000,
      prixVente: 1200000,
    ),
    Appareil(
      id: "APP-013",
      nom: "Réflecteur Leica",
      type: "Réflecteur",
      imageUrl: "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTwpQLIsIgCIxYZJ7erX8al95F12_iasdiQ6g&s",
      prixLocation: 8000,
      prixVente: 800000,
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
