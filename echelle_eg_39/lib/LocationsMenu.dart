import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _showTrash = false; // New: track if showing trash bin
  
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 LocationPage ADMIN - initState()');
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
      // D'abord vérifier et expirer les locations automatiques
      await _checkAndExpireLocations();
      
      // Ensuite charger les locations
      final locations = await ApiService.getLocations();
      // DEBUG: voir exactement ce qui vient du backend
      debugPrint('🔍 RAW API response: ${locations.map((l) => 'ID=${l['id']} statut=${l['statut']}').toList()}');
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

  // Vérifier et expirer les locations automatiquement
  Future<void> _checkAndExpireLocations() async {
    try {
      final token = await ApiService.getToken();
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/locations/check-expired'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['expired'] != null && (data['expired'] as List).length > 0) {
          debugPrint('✅ ${(data['expired'] as List).length} location(s) expirée(s) automatiquement');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Erreur expiration automatique: $e');
    }
  }

  // Fonction pour reset les statuts via API backend
  Future<void> _resetStatutsEnAttente() async {
    try {
      final token = await ApiService.getToken();
      final response = await http.patch(
        Uri.parse('${ApiService.baseUrl}/locations/reset-statuts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${data["message"]}'),
              backgroundColor: Colors.green,
            ),
          );
          _loadLocationsFromAPI();
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur reset: $e');
    }
  }

  // Fonction pour corriger la contrainte DB
  Future<void> _fixDatabaseConstraint() async {
    try {
      final token = await ApiService.getToken();
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/locations/fix-constraint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.statusCode == 200 ? '✅ Contrainte corrigée!' : '❌ Erreur: ${response.body}'),
            backgroundColor: response.statusCode == 200 ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur fix constraint: $e');
    }
  }

  List<Map<String, dynamic>> _getPendingLocations() {
    debugPrint('🔍 DEBUG: statuts = ${_locationsFromAPI.map((l) => l['statut']).toSet()}');
    return _locationsFromAPI.where((loc) {
      final statut = loc['statut']?.toString().toLowerCase().trim();
      return statut == 'en_attente' || statut == 'pending';
    }).toList();
  }

  List<Map<String, dynamic>> _getActiveLocations() {
    return _locationsFromAPI.where((loc) {
      final statut = loc['statut']?.toString().toLowerCase().trim();
      return statut == 'en_cours' || statut == 'active';
    }).toList();
  }

  List<Map<String, dynamic>> _getTerminatedLocations() {
    final terminated = _locationsFromAPI.where((loc) {
      final statut = loc['statut']?.toString().toLowerCase().trim();
      return statut == 'termine';
    }).toList();
    debugPrint('📋 Locations terminées trouvées: ${terminated.length}');
    for (var loc in terminated) {
      debugPrint('  - ${loc['appareilNom']} - statut: ${loc['statut']}');
    }
    return terminated;
  }

@override
  Widget build(BuildContext context) {
    final pendingCount = _getPendingLocations().length;
    final activeCount = _getActiveLocations().length;
    debugPrint('📊 ADMIN Locations - Pending: $pendingCount | Active: $activeCount');
    
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
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () => _loadLocationsFromAPI(retry: true),
              tooltip: 'Rafraîchir',
            ),
            flexibleSpace: FlexibleSpaceBar(

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
                icon: Icon(
                  _showTrash ? Icons.close : Icons.delete_outline,
                  color: Colors.white,
                ),
                onPressed: () {
                  debugPrint('🗑️ Bouton corbeille appuyé, _showTrash: $_showTrash');
                  setState(() {
                    _showTrash = !_showTrash;
                  });
                  debugPrint('✅ Après setState, _showTrash: $_showTrash');
                },
                tooltip: _showTrash ? 'Fermer la corbeille' : 'Corbeille',
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
                  
                  // New: Corbeille section - shows terminated locations
                  if (_showTrash) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      title: 'Corbeille (terminées)',
                      icon: Icons.delete_outline,
                      count: _getTerminatedLocations().length,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    if (_getTerminatedLocations().isEmpty)
                      _buildEmptyTrashCard()
                    else ...[
                      ..._getTerminatedLocations().map((loc) => _buildTerminatedLocationCard(loc)),
                      const SizedBox(height: 16),
                      // Bouton pour supprimer toutes les demandes terminées
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showDeleteAllConfirmation(),
                          icon: const Icon(Icons.delete_sweep),
                          label: const Text('Supprimer toutes les demandes terminées'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // New: Show confirmation dialog to delete all terminated locations
  Future<void> _showDeleteAllConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Êtes-vous sûr de vouloir supprimer toutes les demandes terminées ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteAllTerminatedLocations();
    }
  }

  // New: Delete all terminated locations
  Future<void> _deleteAllTerminatedLocations() async {
    try {
      final token = await ApiService.getToken();
      final response = await http.delete(
        Uri.parse('${ApiService.baseUrl}/locations/terminate-all'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Toutes les demandes terminées ont été supprimées'),
              backgroundColor: Colors.green,
            ),
          );
          _loadLocationsFromAPI();
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur suppression: $e');
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

  // New: Build card for terminated locations
  Widget _buildTerminatedLocationCard(Map<String, dynamic> loc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc['appareilNom'] ?? 'Appareil',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    loc['clientNom'] ?? 'Client',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Terminée',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // New: Build empty trash card
  Widget _buildEmptyTrashCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.delete_outline, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'Corbeille vide',
            style: TextStyle(color: Colors.grey[600]),
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
                            _formatDateRange(loc['dateDebut'], loc['dateFin']),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        loc['appareilNom'] ?? 'Appareil',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (loc['statut'] ?? '') == 'termine' 
                          ? Colors.grey 
                          : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        (loc['statut'] ?? '') == 'termine' ? 'Terminé' : 'En cours',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: (loc['statut'] ?? '') == 'termine' 
                            ? Colors.white 
                            : Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${loc['clientNom']} • ${_formatDateRange(loc['dateDebut'], loc['dateFin'])}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${loc['montantTotal']} F',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _showEquipmentStatusDialog(loc),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, size: 12, color: Colors.blue),
                      SizedBox(width: 4),
                      Text(
                        'Statut',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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

  /// Format date en format français lisible (ex: 24 avril 2026)
  String _formatDateLong(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 
                      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateStr ?? '';
    }
  }

  /// Format range de dates (ex: du 24 avril 2026 au 30 avril 2026)
  String _formatDateRange(String? dateDebut, String? dateFin) {
    return 'du ${_formatDateLong(dateDebut)} au ${_formatDateLong(dateFin)}';
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

  /// Afficher le dialogue de statut de l'appareil
  void _showEquipmentStatusDialog(Map<String, dynamic> loc) {
    final appareilNom = loc['appareilNom'] ?? 'Appareil';
    final clientNom = loc['clientNom'] ?? 'Client';
    final clientTel = loc['clientTelephone'] ?? 'Non défini';
    final dateDebut = loc['dateDebut'] ?? '';
    final dateFin = loc['dateFin'] ?? '';
    final montant = loc['montantTotal'] ?? 0;
    final statut = loc['statut'] ?? 'en_cours';
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.devices, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            const Text('Statut de l\'appareil'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusRow('Appareil', appareilNom, Icons.inventory_2),
            const Divider(),
            _buildStatusRow('Client', clientNom, Icons.person),
            _buildStatusRow('Téléphone', clientTel, Icons.phone),
            const Divider(),
            _buildStatusRow('Date début', _formatDate(dateDebut), Icons.play_arrow),
            _buildStatusRow('Date fin', _formatDate(dateFin), Icons.stop),
            const Divider(),
            _buildStatusRow('Montant', '$montant F', Icons.attach_money),
            const Divider(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'En location (actif)',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
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
                              content: Text('✅ Demande rejetée avec succès'),
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
