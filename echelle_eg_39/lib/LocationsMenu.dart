import 'package:flutter/material.dart';
import 'data_manager.dart';
import 'api_service.dart';

class LocationPage extends StatefulWidget {
  @override
  _LocationPageState createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  final DataManager _dataManager = DataManager();
  
  // Données chargées depuis l'API
  List<Map<String, dynamic>> _locationsFromAPI = [];
  bool _isLoadingLocations = true;
  String? _errorLoadingLocations;
  
  String? clientChoisi;
  String? appareilChoisi;
  int duree = 1;
  bool isLoading = false;

  List<Map<String, dynamic>> appareils = [
    {"nom": "Niveau Leica", "statut": "disponible", "prixJour": 15000, "image": "https://images.unsplash.com/photo-1590650153855-d9e808231d41"},
    {"nom": "GPS E-Survey E600", "statut": "disponible", "prixJour": 25000, "image": "https://images.unsplash.com/photo-1581092334494-8b6a8c3a52f3"},
    {"nom": "GPS E-Survey E300", "statut": "loué", "prixJour": 20000, "image": "https://images.unsplash.com/photo-1581092334494-8b6a8c3a52f3"},
    {"nom": "GPS E-Survey E800", "statut": "disponible", "prixJour": 30000, "image": "https://images.unsplash.com/photo-1581092334494-8b6a8c3a52f3"},
    {"nom": "Station Totale", "statut": "disponible", "prixJour": 20000, "image": "https://images.unsplash.com/photo-1506744038136-46273834b3fb"},
    {"nom": "Theodolite", "statut": "disponible", "prixJour": 18000, "image": "https://images.unsplash.com/photo-1506744038136-46273834b3fb"},
    {"nom": "Trépied", "statut": "disponible", "prixJour": 10000, "image": "https://images.unsplash.com/photo-1590650153855-d9e808231d41"},
    {"nom": "Mire", "statut": "disponible", "prixJour": 5000, "image": "https://images.unsplash.com/photo-1590650153855-d9e808231d41"},
    {"nom": "Drone", "statut": "disponible", "prixJour": 50000, "image": "https://images.unsplash.com/photo-1506941433948-8f0958e3c0f1"},
    {"nom": "Laser", "statut": "disponible", "prixJour": 12000, "image": "https://images.unsplash.com/photo-1562654501-a0ccc81d82d5"},
    {"nom": "Réflecteur", "statut": "disponible", "prixJour": 8000, "image": "https://images.unsplash.com/photo-1581092334494-8b6a8c3a52f3"},
  ];

  List<Map<String, dynamic>> historique = [];

  @override
  void initState() {
    super.initState();
    _dataManager.initialize();
    _loadLocationsFromAPI();
  }

  // Charger les locations depuis l'API
  Future<void> _loadLocationsFromAPI() async {
    setState(() {
      _isLoadingLocations = true;
      _errorLoadingLocations = null;
    });
    
    try {
      final locations = await ApiService.getLocations();
      setState(() {
        _locationsFromAPI = locations;
        _isLoadingLocations = false;
      });
      print('📡 Locations chargées pour admin: ${locations.length}');
    } catch (e) {
      setState(() {
        _errorLoadingLocations = e.toString();
        _isLoadingLocations = false;
      });
      print('❌ Erreur chargement locations: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientNames = _dataManager.clientNames;
    final appareilsDispo = appareils.where((a) => a["statut"] == "disponible").toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // AppBar avec design moderne
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF6366F1),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                "Location d'Appareils",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -50,
                      top: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      left: -30,
                      bottom: -30,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadLocationsFromAPI,
                tooltip: 'Actualiser',
              ),
            ],
          ),

          // Section: Liste des locations en attente (depuis API)
          if (_isLoadingLocations)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_errorLoadingLocations != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Erreur: $_errorLoadingLocations', style: const TextStyle(color: Colors.red)),
              ),
            )
          else if (_locationsFromAPI.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.pending_actions, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Locations en attente (${_locationsFromAPI.length})',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._locationsFromAPI.map((loc) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.shade100,
                          child: const Icon(Icons.inventory_2, color: Colors.orange),
                        ),
                        title: Text(loc['appareilNom'] ?? 'Appareil'),
                        subtitle: Text('${loc['clientNom'] ?? ''} - ${loc['clientEmail'] ?? ''}'),
                        trailing: Text(
                          '${loc['montantTotal'] ?? 0} FCA',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () => _showLocationDetails(loc),
                      ),
                    )),
                  ],
                ),
              ),
            ),

          // Section: Appareils disponibles (inchangée)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Appareils disponibles (${appareilsDispo.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final appareil = appareilsDispo[index];
                  return _buildAppareilCard(appareil);
                },
                childCount: appareilsDispo.length,
              ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
        ],
      ),
    );
  }

  Widget _buildAppareilCard(Map<String, dynamic> appareil) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                color: Colors.grey.shade200,
                image: DecorationImage(
                  image: NetworkImage(appareil['image'] ?? ''),
                  fit: BoxFit.cover,
                  onError: (exception, stackTrace) {},
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "disponible",
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appareil['nom'],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${appareil['prixJour']} FCA/jour',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showLocationDialog(appareil),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        minimumSize: const Size(0, 32),
                      ),
                      child: const Text('Louer', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLocationDialog(Map<String, dynamic> appareil) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Location: ${appareil['nom']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Nom du client'),
              onChanged: (v) => clientChoisi = v,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField(
              value: clientChoisi,
              decoration: const InputDecoration(labelText: 'Ou sélectionner un client'),
              items: _dataManager.clientNames.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => clientChoisi = v),
            ),
            const SizedBox(height: 10),
            Text('Prix par jour: ${appareil['prixJour']} FCA'),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Durée (jours): '),
                IconButton(icon: const Icon(Icons.remove), onPressed: () {
                  if (duree > 1) setState(() => duree--);
                }),
                Text('$duree', style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.add), onPressed: () {
                  setState(() => duree++);
                }),
              ],
            ),
            Text(
              'Total: ${appareil['prixJour'] * duree} FCA',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (clientChoisi == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Veuillez sélectionner un client')),
                );
                return;
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Location créée pour $clientChoisi!')),
              );
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _showLocationDetails(Map<String, dynamic> location) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Location: ${location['code'] ?? ''}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client: ${location['clientNom'] ?? ''}'),
            Text('Email: ${location['clientEmail'] ?? ''}'),
            Text('Téléphone: ${location['clientPhone'] ?? ''}'),
            Text('Appareil: ${location['appareilNom'] ?? ''}'),
            Text('Prix jour: ${location['prixJournalier'] ?? 0} FCA'),
            Text('Total: ${location['montantTotal'] ?? 0} FCA'),
            Text('Statut: ${location['statut'] ?? ''}'),
            Text('Début: ${location['dateDebut'] ?? ''}'),
            Text('Fin: ${location['dateFin'] ?? ''}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Valider la location via API
              Navigator.pop(context);
              try {
                final response = await ApiService.approveLocation(location['id']);
                if (response != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Location validée avec succès!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // Rafraîchir la liste des locations
                  _loadLocationsFromAPI();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Valider'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showRejectDialog(location);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(Map<String, dynamic> location) {
    final raisonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejeter la location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Veuillez préciser la raison du rejet :'),
            const SizedBox(height: 12),
            TextField(
              controller: raisonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Raison du rejet',
                border: OutlineInputBorder(),
                hintText: 'Ex: Appareil non disponible, problème de paiement...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final raison = raisonController.text.trim();
              if (raison.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Veuillez saisir une raison de rejet')),
                );
                return;
              }
              Navigator.pop(context);
              // Appeler l'API pour rejeter
              try {
                final response = await ApiService.rejectLocation(location['id'], raison);
                if (response != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Location rejetée avec succès!')),
                  );
                  _loadLocationsFromAPI();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirmer le rejet'),
          ),
        ],
      ),
    );
  }
}
