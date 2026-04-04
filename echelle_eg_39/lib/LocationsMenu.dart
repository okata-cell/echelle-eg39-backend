import 'package:flutter/material.dart';
import 'dart:async';
import 'data_manager.dart';
import 'api_service.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({Key? key}) : super(key: key);
  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  final DataManager _dataManager = DataManager();
  
  List<Map<String, dynamic>> _locationsFromAPI = [];
  bool _isLoadingLocations = true;
  String? _errorLoadingLocations;
  
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _dataManager.initialize();
    _loadLocationsFromAPI();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadLocationsFromAPI());
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLocationsFromAPI({bool retry = false}) async {
    setState(() {
      _isLoadingLocations = true;
      if (retry) _errorLoadingLocations = null;
    });
    
    try {
      final locations = await ApiService.getLocations();
      setState(() {
        _locationsFromAPI = locations;
        _isLoadingLocations = false;
      });
      debugPrint('📡 Locations admin: ${locations.length} ( ${_getPendingLocations().length} en attente)');
      debugPrint('📡 Détails locations: ${locations.map((l) => 'ID: ${l['id']}, Statut: ${l['statut']}, Client: ${l['clientNom']}').join(', ')}');
    } catch (e) {
      setState(() {
        _errorLoadingLocations = e.toString();
        _isLoadingLocations = false;
      });
      debugPrint('❌ Erreur locations: $e');
    }
  }

  List<Map<String, dynamic>> _getPendingLocations() {
    return _locationsFromAPI.where((loc) => 
      loc['statut'] == 'en_attente' || loc['statut'] == 'attente'
    ).toList();
  }

  List<Map<String, dynamic>> _getActiveLocations() {
    return _locationsFromAPI.where((loc) => 
      loc['statut'] == 'en_cours' || loc['statut'] == 'approuve'
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _getPendingLocations().length;
    final activeCount = _getActiveLocations().length;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        slivers: [
          // Header avec statistiques
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF6366F1),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                "Demandes de Location",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatCard(
                          icon: Icons.hourglass_empty,
                          label: 'En attente',
                          value: pendingCount,
                          color: Colors.orange,
                        ),
                        _buildStatCard(
                          icon: Icons.check_circle,
                          label: 'Actives',
                          value: activeCount,
                          color: Colors.green,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () => _loadLocationsFromAPI(retry: true),
              ),
            ],
          ),
          
          // Contenu principal
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section: Demandes en attente
                  _buildSectionHeader(
                    title: 'Demandes en attente',
                    icon: Icons.pending_actions,
                    count: pendingCount,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  
                  if (_isLoadingLocations)
                    _buildLoadingCard()
                  else if (_errorLoadingLocations != null)
                    _buildErrorCard()
                  else if (pendingCount == 0)
                    _buildEmptyPendingCard()
                  else
                    ..._getPendingLocations().map((loc) => _buildPendingLocationCard(loc)),
                  
                  const SizedBox(height: 24),
                  
                  // Section: Locations actives
                  _buildSectionHeader(
                    title: 'Locations actives',
                    icon: Icons.play_circle_outline,
                    count: activeCount,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 12),
                  
                  if (activeCount == 0)
                    _buildEmptyActiveCard()
                  else
                    ..._getActiveLocations().map((loc) => _buildActiveLocationCard(loc)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required int count,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingLocationCard(Map<String, dynamic> loc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icône appareil
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.gps_fixed,
                    color: Color(0xFF6366F1),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                // Infos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc['appareilNom'] ?? 'Appareil',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              loc['clientNom'] ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            '${_formatDate(loc['dateDebut'])} - ${_formatDate(loc['dateFin'])}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Montant
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${loc['montantTotal']} F',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                    const Text(
                      'FCFA',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Boutons d'action
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _performApprove(loc['id']),
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    label: const Text('Approuver', style: TextStyle(color: Colors.green)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: const Color(0xFFE2E8F0),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _showRejectDialog(loc),
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    label: const Text('Rejeter', style: TextStyle(color: Colors.red)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveLocationCard(Map<String, dynamic> loc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check_circle, color: Colors.green, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc['appareilNom'] ?? 'Appareil',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${loc['clientNom']} • ${_formatDate(loc['dateDebut'])} - ${_formatDate(loc['dateFin'])}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${loc['montantTotal']} F',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Color(0xFF6366F1)),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 40),
          const SizedBox(height: 12),
          Text(
            'Erreur: $_errorLoadingLocations',
            style: TextStyle(color: Colors.red.shade700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _loadLocationsFromAPI(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPendingCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inbox_outlined, color: Colors.orange.shade400, size: 40),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucune demande en attente',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Les nouvelles demandes de location apparaîtront ici',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActiveCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text(
          'Aucune location active',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _performApprove(int id) async {
    try {
      await ApiService.approveLocation(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Demande approuvée avec succès!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadLocationsFromAPI();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showRejectDialog(Map<String, dynamic> location) {
    final controller = TextEditingController();
    bool isValid = false;
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.cancel, color: Colors.red),
              ),
              const SizedBox(width: 12),
              const Text('Rejeter la demande'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'La raison sera visible par le client',
                        style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 3,
                onChanged: (value) {
                  setDialogState(() {
                    isValid = value.trim().isNotEmpty;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Motif du rejet',
                  hintText: 'Ex: Appareil indisponible, dates impossibles...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.message_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              onPressed: isValid
                  ? () async {
                      Navigator.pop(dialogContext);
                      try {
                        await ApiService.rejectLocation(location['id'], controller.text.trim());
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('❌ Demande rejetée'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          _loadLocationsFromAPI();
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    }
                  : null,
              icon: const Icon(Icons.close),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              label: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  }
}
