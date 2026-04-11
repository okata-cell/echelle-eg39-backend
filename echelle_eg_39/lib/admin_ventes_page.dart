import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_service.dart';

/// Page admin pour gérer les demandes d'achat (copie de LocationsMenu)
class AdminVentesPageFixed extends StatefulWidget {
  const AdminVentesPageFixed({Key? key}) : super(key: key);

  @override
  State<AdminVentesPageFixed> createState() => _AdminVentesPageFixedState();
}

class _AdminVentesPageFixedState extends State<AdminVentesPageFixed> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _demandesFromAPI = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDemandesFromAPI();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Charger les demandes d'achat depuis l'API
  Future<void> _loadDemandesFromAPI() async {
    setState(() => _isLoading = true);
    try {
      final token = await ApiService.ensureAuthenticated();
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/demandes'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _demandesFromAPI = List<Map<String, dynamic>>.from(data['demandes'] ?? []);
          _isLoading = false;
        });
        print('📡 Admin Demandes Achat: ${_demandesFromAPI.length} demandes chargées');
      } else {
        setState(() => _isLoading = false);
        print('❌ Erreur chargement demandes: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('❌ Exception chargement demandes: $e');
    }
  }

  /// Demandes en attente
  List<Map<String, dynamic>> _getPendingDemandes() {
    return _demandesFromAPI.where((d) {
      final statut = d['statut']?.toString().toLowerCase().trim();
      return statut == 'en_attente' || statut == 'pending';
    }).toList();
  }

  /// Demandes actives/approuvées
  List<Map<String, dynamic>> _getActiveDemandes() {
    return _demandesFromAPI.where((d) {
      final statut = d['statut']?.toString().toLowerCase().trim();
      return statut == 'approuvee' || statut == 'approuvé' || statut == 'approved';
    }).toList();
  }

  /// Demandes terminées/rejetées
  List<Map<String, dynamic>> _getCompletedDemandes() {
    return _demandesFromAPI.where((d) {
      final statut = d['statut']?.toString().toLowerCase().trim();
      return statut == 'termine' || statut == 'rejetee' || statut == 'rejetée' || statut == 'livree';
    }).toList();
  }

  /// Formater une date
  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  /// Formater date en français
  String _formatDateFr(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 
                      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  /// Approuver une demande
  Future<void> _approveDemande(int id) async {
    try {
      final token = await ApiService.ensureAuthenticated();
      final response = await http.patch(
        Uri.parse('${ApiService.baseUrl}/demandes/$id/statut'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'statut': 'approuvee',
          'commentaire_admin': 'Demande approuvée par l\'admin',
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Demande approuvée avec succès!'),
              backgroundColor: Colors.green,
            ),
          );
          _loadDemandesFromAPI();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Erreur: ${response.body}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Rejeter une demande
  Future<void> _rejectDemande(int id, String motif) async {
    try {
      final token = await ApiService.ensureAuthenticated();
      final response = await http.patch(
        Uri.parse('${ApiService.baseUrl}/demandes/$id/statut'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'statut': 'rejetee',
          'commentaire_admin': motif,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Demande rejetée'),
              backgroundColor: Colors.orange,
            ),
          );
          _loadDemandesFromAPI();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Erreur: ${response.body}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _getPendingDemandes().length;
    final activeCount = _getActiveDemandes().length;
    final completedCount = _getCompletedDemandes().length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
        title: const Text('Demandes d\'Achat'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          isScrollable: true,
          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pending_actions, size: 16),
                  const SizedBox(width: 4),
                  Text('En att. ($pendingCount)', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_circle_outline, size: 16),
                  const SizedBox(width: 4),
                  Text('Approuv. ($activeCount)', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline, size: 16),
                  const SizedBox(width: 4),
                  Text('Termin. ($completedCount)', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDemandesFromAPI,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // En attente
                _buildDemandesList(_getPendingDemandes(), 'en_attente'),
                // Approuvées
                _buildDemandesList(_getActiveDemandes(), 'approuvee'),
                // Terminées
                _buildDemandesList(_getCompletedDemandes(), 'termine'),
              ],
            ),
    );
  }

  Widget _buildDemandesList(List<Map<String, dynamic>> demandes, String type) {
    if (demandes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'en_attente' ? Icons.pending_actions :
              type == 'approuvee' ? Icons.check_circle : Icons.done_all,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              type == 'en_attente' ? 'Aucune demande en attente' :
              type == 'approuvee' ? 'Aucune demande approuvée' : 'Aucune demande terminée',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDemandesFromAPI,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: demandes.length,
        itemBuilder: (context, index) => _buildDemandeCard(demandes[index], type),
      ),
    );
  }

  Widget _buildDemandeCard(Map<String, dynamic> demande, String type) {
    final appareilNom = demande['appareilNom'] ?? 'Produit';
    final clientNom = demande['clientNom'] ?? 'Client';
    final total = demande['total'] ?? 0;
    final quantite = demande['quantite'] ?? 1;
    final createdAt = demande['createdAt'] ?? '';
    final code = demande['code'] ?? '';

    Color borderColor;
    Color statusColor;
    IconData statusIcon;

    switch (type) {
      case 'en_attente':
        borderColor = Colors.orange;
        statusColor = Colors.orange;
        statusIcon = Icons.pending_actions;
        break;
      case 'approuvee':
        borderColor = Colors.green;
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      default:
        borderColor = Colors.grey;
        statusColor = Colors.grey;
        statusIcon = Icons.done_all;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // En-tête avec code
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: borderColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Icon(statusIcon, size: 16, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  code,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDateFr(createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Corps de la carte
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Appareil
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.shopping_cart, color: Colors.blue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$appareilNom (x$quantite)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            clientNom,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$total F',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Boutons d'action pour les demandes en attente
                if (type == 'en_attente') ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showRejectDialog(demande['id']),
                          icon: const Icon(Icons.cancel, size: 18),
                          label: const Text('Rejeter'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _approveDemande(demande['id']),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Approuver'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Dialogue de rejet
  void _showRejectDialog(int id) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel, color: Colors.red),
            SizedBox(width: 12),
            Text('Rejeter la demande'),
          ],
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Motif du rejet',
            hintText: 'Ex: Stock insuffisant, prix incorrect...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _rejectDemande(id, controller.text);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
  }
}
