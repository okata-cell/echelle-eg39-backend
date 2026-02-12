import 'package:flutter/material.dart';
import 'data_manager.dart';

class LocationPage extends StatefulWidget {
  @override
  _LocationPageState createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  final DataManager _dataManager = DataManager();
  
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
  ];

  List<Map<String, dynamic>> historique = [];

  @override
  void initState() {
    super.initState();
    _dataManager.initialize();
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
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Contenu principal
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Carte principale
                  _buildMainCard(clientNames, appareilsDispo),
                  
                  const SizedBox(height: 20),

                  // Prix total si appareil choisi
                  if (appareilChoisi != null) _buildPriceCard(),
                  
                  const SizedBox(height: 20),

                  // Bouton de validation
                  _buildValidationButton(clientNames),

                  const SizedBox(height: 30),

                  // État des appareils
                  _buildDeviceStatusCard(),

                  const SizedBox(height: 20),

                  // Historique
                  if (historique.isNotEmpty) _buildHistoryCard(),
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainCard(List<String> clientNames, List<Map<String, dynamic>> appareilsDispo) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre de section
            Row(
              children: [
                Icon(Icons.add_circle_outline, color: Colors.indigo.shade600, size: 24),
                const SizedBox(width: 8),
                Text(
                  "Nouvelle Location",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Message d'avertissement si pas de clients
            if (clientNames.isEmpty)
              _buildWarningCard(),
            
            if (clientNames.isNotEmpty) ...[
              // Sélection client
              _buildClientSelection(clientNames),
              const SizedBox(height: 16),
            ],

            // Sélection appareil
            _buildDeviceSelection(appareilsDispo),
            const SizedBox(height: 16),

            // Sélection durée
            _buildDurationSelection(),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange.shade600, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Aucun client disponible. Ajoutez d'abord des clients dans la section \"Clients\".",
              style: TextStyle(
                color: Colors.orange.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientSelection(List<String> clientNames) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Client",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.person, color: Colors.indigo),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            hint: const Text("Sélectionner un client"),

            items: clientNames
                .map((c) => DropdownMenuItem<String>(
                      value: c,
                      child: Text(c),
                    ))
                .toList(),
            value: clientChoisi,
            onChanged: (val) {
              setState(() {
                clientChoisi = val;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceSelection(List<Map<String, dynamic>> appareilsDispo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Appareil",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.devices, color: Colors.indigo),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            hint: const Text("Sélectionner un appareil"),

            items: appareilsDispo
                .map((a) => DropdownMenuItem<String>(
                      value: a["nom"],
                      child: Text(a["nom"]),
                    ))
                .toList(),
            value: appareilChoisi,
            onChanged: (val) {
              setState(() {
                appareilChoisi = val;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDurationSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Durée de location",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.access_time, color: Colors.indigo.shade600, size: 20),
              const SizedBox(width: 12),
              Text(
                "Durée: ",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: duree > 1 ? () {
                        setState(() {
                          duree--;
                        });
                      } : null,
                      icon: Icon(Icons.remove, size: 18),
                      padding: EdgeInsets.all(8),
                      constraints: BoxConstraints(),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        duree.toString(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: duree < 30 ? () {
                        setState(() {
                          duree++;
                        });
                      } : null,
                      icon: Icon(Icons.add, size: 18),
                      padding: EdgeInsets.all(8),
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(

              "jour${duree > 1 ? 's' : ''}",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceCard() {
    final prixTotal = _calculerPrixTotal();
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.attach_money,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Prix Total",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    "$prixTotal F CFA",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidationButton(List<String> clientNames) {
    final canValidate = clientChoisi != null && appareilChoisi != null && clientNames.isNotEmpty;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: canValidate ? _validerLocation : null,
        icon: isLoading 
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_circle),
        label: Text(isLoading ? "Validation..." : "Confirmer la Location"),
        style: ElevatedButton.styleFrom(
          backgroundColor: canValidate ? const Color(0xFF10B981) : Colors.grey.shade300,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: canValidate ? 4 : 0,
        ),
      ),
    );
  }

  Widget _buildDeviceStatusCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.devices_other, color: Colors.blue.shade600, size: 24),
                const SizedBox(width: 8),
                Text(
                  "État des Appareils",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: appareils.length,
              itemBuilder: (context, index) {
                final appareil = appareils[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: appareil["statut"] == "disponible" 
                          ? Colors.green.shade200 
                          : Colors.red.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: appareil["statut"] == "disponible"
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          appareil["statut"] == "disponible"
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: appareil["statut"] == "disponible"
                              ? Colors.green.shade600
                              : Colors.red.shade600,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appareil["nom"],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              "${appareil["prixJour"]} F/jour",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: appareil["statut"] == "disponible"
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          appareil["statut"] == "disponible" ? "Disponible" : "Loué",
                          style: TextStyle(
                            color: appareil["statut"] == "disponible"
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: Colors.purple.shade600, size: 24),
                const SizedBox(width: 8),
                Text(
                  "Historique des Locations",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...historique.reversed.map((h) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.location_on,
                          color: Colors.purple.shade600,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${h['client']} → ${h['appareil']}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              "${h['duree']} jour${h['duree'] > 1 ? 's' : ''} • ${h['prix']} F",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        h['date'] ?? '',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  int _calculerPrixTotal() {
    if (appareilChoisi == null) return 0;
    try {
      final appareil = appareils.firstWhere(
        (a) => a["nom"] == appareilChoisi,
      );
      return appareil["prixJour"] * duree;
    } catch (e) {
      return 0;
    }
  }

  void _validerLocation() async {
    if (clientChoisi == null || appareilChoisi == null) return;

    setState(() {
      isLoading = true;
    });

    // Simulation d'un délai de traitement
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      final appareilIndex = appareils.indexWhere(
        (a) => a["nom"] == appareilChoisi,
      );
      if (appareilIndex != -1) {
        appareils[appareilIndex]["statut"] = "loué";

        historique.add({
          "client": clientChoisi!,
          "appareil": appareilChoisi!,
          "duree": duree,
          "prix": _calculerPrixTotal(),
          "date": DateTime.now().toString().split(' ')[0],
        });

        clientChoisi = null;
        appareilChoisi = null;
        duree = 1;
      }
      isLoading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text("Location enregistrée avec succès!"),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}
