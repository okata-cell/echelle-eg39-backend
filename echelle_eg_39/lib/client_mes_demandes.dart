import 'package:flutter/material.dart';
import 'data_manager.dart';
import 'api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClientMesDemandesPage extends StatefulWidget {
  const ClientMesDemandesPage({Key? key}) : super(key: key);

  @override
  State<ClientMesDemandesPage> createState() => _ClientMesDemandesPageState();
}

class _ClientMesDemandesPageState extends State<ClientMesDemandesPage> {
  final _dataManager = DataManager();
  List<Map<String, dynamic>> _demandesFromAPI = [];
  bool _isLoading = true;
  String? _error;
  String _clientEmail = '';

  @override
  void initState() {
    super.initState();
    _dataManager.initialize();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadClientEmail();
    await _loadDemandesFromAPI();
  }

  Future<void> _loadClientEmail() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _clientEmail = prefs.getString('userEmail') ?? '';
    });
  }

  Future<void> _loadDemandesFromAPI() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      
      final demandes = await ApiService.getDemandesAchat();
      if (mounted) {
        setState(() {
          _demandesFromAPI = demandes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _dataManager.removeListener(() => setState(() {}));
    super.dispose();
  }

  /// Get filtered demandes from API for the current user
  List<Map<String, dynamic>> get _mesDemandesAchat {
    if (_clientEmail.isEmpty) return [];
    return _demandesFromAPI.where((d) => 
      d['clientEmail'] == _clientEmail
    ).toList();
  }

  Color _getStatutColor(String statut) {
    switch (statut) {
      case 'en_attente':
        return const Color(0xFFF59E0B);
      case 'approuvee':
        return const Color(0xFF059669);
      case 'rejetee':
        return const Color(0xFFDC2626);
      case 'livree':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _getStatutLabel(String statut) {
    switch (statut) {
      case 'en_attente':
        return 'En attente';
      case 'approuvee':
        return 'Approuvée';
      case 'rejetee':
        return 'Rejetée';
      case 'livree':
        return 'Livrée';
      default:
        return statut;
    }
  }

  IconData _getStatutIcon(String statut) {
    switch (statut) {
      case 'en_attente':
        return Icons.pending;
      case 'approuvee':
        return Icons.check_circle;
      case 'rejetee':
        return Icons.cancel;
      case 'livree':
        return Icons.local_shipping;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Mes demandes d\'achat',
          style: TextStyle(color: Color(0xFF111827)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Erreur: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDemandesFromAPI,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : _mesDemandesAchat.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucune demande d\'achat',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Vos demandes apparaîtront ici',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _mesDemandesAchat.length,
                      itemBuilder: (context, index) {
                        final demande = _mesDemandesAchat[index];
                        return _buildDemandeCard(demande);
                      },
                    ),
    );
  }

  Widget _buildDemandeCard(Map<String, dynamic> demande) {
    // Support both API response format and local model format
    final produitNom = demande['appareilNom'] ?? demande['produitNom'] ?? 'Produit';
    final statut = demande['statut']?.toString() ?? 'en_attente';
    final quantite = demande['quantite'] ?? 1;
    final produitPrix = demande['appareilPrix'] ?? demande['produitPrix'] ?? 0;
    final total = demande['total'] ?? (produitPrix * quantite);
    final createdAt = demande['createdAt'] ?? demande['dateCommande'];
    final id = demande['id']?.toString() ?? '';
    final commentaireAdmin = demande['commentaireAdmin'] ?? demande['commentaire_admin'];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec produit et statut
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    produitNom,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatutColor(statut).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatutIcon(statut),
                        size: 14,
                        color: _getStatutColor(statut),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getStatutLabel(statut),
                        style: TextStyle(
                          color: _getStatutColor(statut),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Détails de la commande
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Quantité',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      Text(
                        '$quantite',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Prix unitaire',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      Text(
                        '${produitPrix.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')} FCFA',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Text(
                        '${total.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')} FCFA',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Date de commande
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Color(0xFF6B7280)),
                const SizedBox(width: 6),
                Text(
                  createdAt != null 
                      ? 'Commandé le ${_formatDate(createdAt)}'
                      : 'Date inconnue',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),

            // ID de commande
            if (id.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.tag, size: 14, color: Color(0xFF6B7280)),
                  const SizedBox(width: 6),
                  Text(
                    'Réf: $id',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ],

            // Commentaire admin si présent - CORRECTION: Afficher le commentaire depuis l'API
            if (commentaireAdmin != null && commentaireAdmin.toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statut == 'rejetee'
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: statut == 'rejetee'
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF059669),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.comment,
                      size: 16,
                      color: statut == 'rejetee'
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF059669),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statut == 'rejetee'
                                ? 'Raison du rejet :'
                                : 'Commentaire :',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: statut == 'rejetee'
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF059669),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            commentaireAdmin.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: statut == 'rejetee'
                                  ? const Color(0xFF991B1B)
                                  : const Color(0xFF166534),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Message selon le statut
            if (statut == 'en_attente') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info, size: 16, color: Color(0xFFD97706)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Votre demande est en cours de traitement',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (statut == 'approuvee') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Color(0xFF059669)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Félicitations ! Votre demande a été approuvée.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (statut == 'rejetee') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.cancel, size: 16, color: Color(0xFFDC2626)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Votre demande a été refusée. Veuillez contacter le service client.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Date inconnue';
    try {
      final dateStr = date.toString();
      final parsed = DateTime.parse(dateStr);
      return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year} à ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return date.toString();
    }
  }
}
