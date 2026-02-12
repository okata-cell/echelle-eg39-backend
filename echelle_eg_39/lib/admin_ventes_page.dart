import 'package:flutter/material.dart';
import 'data_manager.dart';
import 'admin_demandes_achat.dart';

class AdminVentesPageFixed extends StatefulWidget {
  const AdminVentesPageFixed({Key? key}) : super(key: key);

  @override
  State<AdminVentesPageFixed> createState() => _AdminVentesPageFixedState();
}

class _AdminVentesPageFixedState extends State<AdminVentesPageFixed> 
    with SingleTickerProviderStateMixin {
  
  late TabController _tabController;
  
  // Variables pour le formulaire de nouvelle vente
  final _formKey = GlobalKey<FormState>();
  final _dataManager = DataManager();
  
  String? _selectedClientId;  // Utiliser l'ID au lieu de l'objet Client
  Map<String, dynamic>? _selectedProduit;
  DateTime _dateCommande = DateTime.now();
  String _statut = 'Confirmée';
  
  // Controllers pour les champs de saisie
  final _dateController = TextEditingController();
  
  // Données simplifiées et sécurisées
  final List<Map<String, dynamic>> _ventes = [
    {
      'id': 'V-001',
      'client': 'Client A',
      'produit': 'GPS e-survey E600',
      'prix': 2500000.0,
      'date': '2024-01-15',
      'statut': 'Complétée',
    },
    {
      'id': 'V-002',
      'client': 'Client B', 
      'produit': 'Station totale Leica TS09',
      'prix': 4200000.0,
      'date': '2024-01-16',
      'statut': 'En cours',
    },
    {
      'id': 'V-003',
      'client': 'Client C',
      'produit': 'Niveau automatique Leica',
      'prix': 1200000.0,
      'date': '2024-01-17',
      'statut': 'Confirmée',
    },
  ];

  final List<Map<String, dynamic>> _produits = [
    {
      'id': 1,
      'nom': 'GPS e-survey E600',
      'categorie': 'GPS',
      'prix': 2500000.0,
      'stock': 5,
      'seuil': 2,
    },
    {
      'id': 2,
      'nom': 'GPS e-survey E800',
      'categorie': 'GPS', 
      'prix': 3500000.0,
      'stock': 1,
      'seuil': 2,
    },
    {
      'id': 3,
      'nom': 'Station totale Leica TS09',
      'categorie': 'Station totale',
      'prix': 4200000.0,
      'stock': 0,
      'seuil': 1,
    },
  ];

  @override
  void initState() {
    super.initState();
    try {
      _tabController = TabController(length: 5, vsync: this);
    } catch (e) {
      // En cas d'erreur, utiliser un TabController basique
      _tabController = TabController(length: 5, vsync: this);
    }
    
    // Initialiser le gestionnaire de données
    _dataManager.initialize();
    
    // Initialiser le contrôleur de date
    _dateController.text = '${_dateCommande.day}/${_dateCommande.month}/${_dateCommande.year}';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Calculs sécurisés
  double get chiffreAffairesTotal => 
      _ventes.fold(0.0, (sum, vente) => sum + (vente['prix'] ?? 0.0));
  
  int get ventesAujourdhui => 
      _ventes.where((v) => v['date'] == '2024-01-17').length;
  
  int get commandesEnAttente => 
      _ventes.where((v) => v['statut'] == 'En cours').length;

  @override
  Widget build(BuildContext context) {
    final nombreDemandesEnAttente = _dataManager.nombreDemandesEnAttente;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestion des Ventes ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
        elevation: 8,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_bag),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminDemandesAchatPage(),
                    ),
                  );
                },
                tooltip: 'Demandes d\'achat clients',
              ),
              if (nombreDemandesEnAttente > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$nombreDemandesEnAttente',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Tableau de bord'),
            Tab(icon: Icon(Icons.list_alt), text: 'Commandes'),
            Tab(icon: Icon(Icons.inventory), text: 'Stock'),
            Tab(icon: Icon(Icons.analytics), text: 'Rapports'),
            Tab(icon: Icon(Icons.add_shopping_cart), text: 'Nouvelle vente'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildTableauDeBord(),
            _buildCommandes(),
            _buildGestionStock(),
            _buildRapports(),
            _buildNouvelleVente(),
          ],
        ),
      ),
    );
  }

  Widget _buildTableauDeBord() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cartes de statistiques
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Chiffre d\'Affaires',
                  '${_formatNumber(chiffreAffairesTotal)} FCFA',
                  Icons.monetization_on,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Ventes Aujourd\'hui',
                  '$ventesAujourdhui',
                  Icons.shopping_cart,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Commandes en Attente',
                  '$commandesEnAttente',
                  Icons.pending_actions,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Total Ventes',
                  '${_ventes.length}',
                  Icons.assessment,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Ventes récentes
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.recent_actors, color: Colors.indigo.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'Ventes Récentes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._ventes.take(3).map((vente) => _buildVenteItem(vente)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandes() {
    debugPrint('_buildCommandes called, _ventes length: ${_ventes.length}');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _ventes.length,
      itemBuilder: (context, index) {
        debugPrint('Building item at index $index');
        final vente = _ventes[index];
        debugPrint('vente: $vente, type: ${vente.runtimeType}');
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      vente['id'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    _buildStatutBadge(vente['statut'] ?? ''),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Client: ${vente['client'] ?? ''}'),
                Text('Produit: ${vente['produit'] ?? ''}'),
                Text(
                  'Prix: ${_formatNumber(vente['prix'] ?? 0.0)} FCFA',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Date: ${vente['date'] ?? ''}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGestionStock() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _produits.length,
      itemBuilder: (context, index) {
        final produit = _produits[index];
        final stockFaible = (produit['stock'] ?? 0) <= (produit['seuil'] ?? 0);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        produit['nom'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text('Catégorie: ${produit['categorie'] ?? ''}'),
                      Text(
                        'Prix: ${_formatNumber(produit['prix'] ?? 0.0)} FCFA',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            stockFaible ? Icons.warning : Icons.inventory,
                            color: stockFaible ? Colors.orange : Colors.green,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Stock: ${produit['stock'] ?? 0}',
                            style: TextStyle(
                              color: stockFaible ? Colors.orange : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRapports() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rapport de Ventes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildRapportItem('Ventes ce mois', '${_ventes.length} commandes'),
                  _buildRapportItem('Chiffre d\'affaires', '${_formatNumber(chiffreAffairesTotal)} FCFA'),
                  _buildRapportItem('Produit le plus vendu', 'GPS e-survey E600'),
                  _buildRapportItem('Moyenne par commande', '${_formatNumber(chiffreAffairesTotal / _ventes.length)} FCFA'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String titre, String valeur, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              valeur,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              titre,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVenteItem(Map<String, dynamic> vente) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vente['client'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                vente['produit'] ?? '',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_formatNumber(vente['prix'] ?? 0.0)} FCFA',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              _buildStatutBadge(vente['statut'] ?? ''),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatutBadge(String statut) {
    Color color;
    switch (statut) {
      case 'Complétée':
        color = Colors.green;
        break;
      case 'Confirmée':
        color = Colors.blue;
        break;
      case 'En cours':
        color = Colors.orange;
        break;
      case 'Annulée':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        statut,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRapportItem(String label, String valeur) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            valeur,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildNouvelleVente() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre de la section
            Row(
              children: [
                Icon(Icons.add_shopping_cart, color: Colors.indigo.shade600, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Nouvelle Vente',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Sélection du client
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, color: Colors.indigo.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Sélection du Client',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedClientId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Client',
                        hintText: 'Sélectionnez un client',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      items: _dataManager.clients.map((Client client) {
                        return DropdownMenuItem<String>(
                          value: client.id,
                          child: Text(
                            client.email != null && client.email!.isNotEmpty
                                ? "${client.name} (${client.email})"
                                : client.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedClientId = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Veuillez sélectionner un client';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Sélection du produit
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.inventory, color: Colors.indigo.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Sélection du Produit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: _selectedProduit,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Produit',
                        hintText: 'Sélectionnez un produit',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.inventory),
                      ),
                      selectedItemBuilder: (BuildContext context) {
                        return _produits.map((Map<String, dynamic> produit) {
                          return Text(
                            produit['nom'] ?? '',
                            overflow: TextOverflow.ellipsis,
                          );
                        }).toList();
                      },
                      items: _produits.map((Map<String, dynamic> produit) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: produit,
                          child: Text(
                            "${produit['nom'] ?? ''} - ${_formatNumber(produit['prix'] ?? 0.0)} FCFA",
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (Map<String, dynamic>? newValue) {
                        setState(() {
                          _selectedProduit = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Veuillez sélectionner un produit';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Date de commande
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.indigo.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Date de Commande',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dateController,
                      decoration: const InputDecoration(
                        labelText: 'Date de commande',
                        hintText: 'Cliquez pour sélectionner une date',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      readOnly: true,
                      onTap: () => _selectDate(context),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez sélectionner une date';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Statut
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.indigo.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Statut',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.schedule, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Statut initial: $_statut',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Le statut changera automatiquement de "Confirmée" vers "En cours" après l\'enregistrement.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Bouton d'enregistrement
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _enregistrerVente,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade600,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Enregistrer la vente',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateCommande,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    
    if (picked != null && picked != _dateCommande) {
      setState(() {
        _dateCommande = picked;
        _dateController.text = '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }

  void _enregistrerVente() {
    if (_formKey.currentState!.validate()) {
      // Générer un nouvel ID de vente
      String newId = 'V-${(_ventes.length + 1).toString().padLeft(3, '0')}';

      // Créer la nouvelle vente
      Client client = _dataManager.clients.firstWhere(
        (client) => client.id == _selectedClientId
      );

      // Sauvegarder les valeurs avant de les réinitialiser
      final selectedProduit = _selectedProduit!;
      final selectedClientId = _selectedClientId!;
      final dateText = '${_dateCommande.day}/${_dateCommande.month}/${_dateCommande.year}';

      Map<String, dynamic> nouvelleVente = {
        'id': newId,
        'client': client.name,
        'produit': selectedProduit['nom'],
        'prix': selectedProduit['prix'],
        'date': dateText,
        'statut': 'En cours', // Le statut change directement vers "En cours"
      };

      // Ajouter à la liste des ventes
      setState(() {
        _ventes.add(nouvelleVente);
      });

      // Réinitialiser le formulaire
      setState(() {
        _selectedClientId = null;
        _selectedProduit = null;
        _dateCommande = DateTime.now();
        _dateController.text = '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';
      });

      // Afficher un message de succès
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vente enregistrée avec succès! ID: $newId'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Afficher les détails de la vente créée
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Vente Enregistrée'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ID: $newId'),
                Text('Client: ${client.name}'),
                Text('Produit: ${selectedProduit['nom']}'),
                Text('Prix: ${_formatNumber(selectedProduit['prix'])} FCFA'),
                Text('Date: $dateText'),
                Text('Statut: En cours'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  String _formatNumber(double number) {
    return number.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
  }
}
