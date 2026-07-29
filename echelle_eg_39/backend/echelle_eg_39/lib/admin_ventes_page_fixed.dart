import 'package:flutter/material.dart';

class AdminVentesPageFixed extends StatefulWidget {
  const AdminVentesPageFixed({Key? key}) : super(key: key);

  @override
  State<AdminVentesPageFixed> createState() => _AdminVentesPageFixedState();
}

class _AdminVentesPageFixedState extends State<AdminVentesPageFixed> 
    with SingleTickerProviderStateMixin {
  
  late TabController _tabController;
  
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
      _tabController = TabController(length: 4, vsync: this);
    } catch (e) {
      // En cas d'erreur, utiliser un TabController basique
      _tabController = TabController(length: 4, vsync: this);
    }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestion des Ventes - Admin',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
        elevation: 8,
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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _ventes.length,
      itemBuilder: (context, index) {
        final vente = _ventes[index];
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

  String _formatNumber(double number) {
    return number.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
  }
}
