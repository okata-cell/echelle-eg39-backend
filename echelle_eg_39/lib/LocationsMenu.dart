import 'package:flutter/material.dart';
import 'dart:async';
import 'data_manager.dart';
import 'api_service.dart';
import 'package:intl/intl.dart';

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
  
  List<Map<String, dynamic>> _appareilsFromAPI = [];
  bool _isLoadingAppareils = true;
  String? _errorLoadingAppareils;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _dataManager.initialize();
    _loadLocationsFromAPI();
    _loadAppareilsFromAPI();
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text.toLowerCase()));
    _autoRefreshTimer = Timer.periodic(Duration(seconds: 30), (_) => _loadLocationsFromAPI());
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAppareilsFromAPI() async {
    setState(() => _isLoadingAppareils = true);
    try {
      final appareils = await ApiService.getAppareils(disponible: true);
      setState(() => _appareilsFromAPI = appareils);
    } catch (e) {
      setState(() => _errorLoadingAppareils = e.toString());
    } finally {
      setState(() => _isLoadingAppareils = false);
    }
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
      debugPrint('📡 Locations admin: ${locations.length} ( ${_getFilteredLocations().length} attente)');
    } catch (e) {
      setState(() {
        _errorLoadingLocations = e.toString();
        _isLoadingLocations = false;
      });
      debugPrint('❌ Erreur locations: $e');
    }
  }

  List<Map<String, dynamic>> _getFilteredLocations() {
    return _locationsFromAPI.where((loc) => loc['statut'] == 'en_attente').toList();
  }

  List<Map<String, dynamic>> _getFilteredAppareils() {
    return _appareilsFromAPI.where((a) => a['disponible'] == true).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF6366F1),
            flexibleSpace: FlexibleSpaceBar(
              title: Row(
                children: [
                  const Text("Admin Locations", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('${_getFilteredLocations().length} attente', style: TextStyle(color: Colors.white70)),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.hourglass_empty, color: Colors.orange),
                              const SizedBox(width: 8),
                              Text('En attente (${_getFilteredLocations().length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _createTestPending,
                            icon: const Icon(Icons.add),
                            label: const Text('Créer TEST en attente'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingLocations)
                    const Card(child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())))
                  else if (_errorLoadingLocations != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(Icons.error, color: Colors.red, size: 48),
                            Text('Erreur: $_errorLoadingLocations'),
                            ElevatedButton(onPressed: _loadLocationsFromAPI, child: Text('Retry')),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    // Pending list
                    if (_getFilteredLocations().isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Icon(Icons.inbox, color: Colors.grey, size: 64),
                              const SizedBox(height: 16),
                              const Text('Aucune location en attente', style: TextStyle(fontSize: 18)),
                              const SizedBox(height: 8),
                              const Text('Utilisez "Créer TEST" ou attendez les clients'),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._getFilteredLocations().map((loc) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(child: Icon(Icons.inventory_2)),
                          title: Text('${loc['appareilNom'] ?? ''}'),
                          subtitle: Text('${loc['clientNom'] ?? ''} (${loc['clientEmail'] ?? ''})'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _performApprove(loc['id']),
                                icon: Icon(Icons.check_circle, color: Colors.green, size: 24),
                                tooltip: 'Valider',
                              ),
                              IconButton(
                                onPressed: () => _showRejectDialog(loc),
                                icon: Icon(Icons.cancel, color: Colors.red, size: 24),
                                tooltip: 'Rejeter',
                              ),
                            ],
                          ),
                        ),
                      )),
                    const SizedBox(height: 16),
                    // DEBUG all locations
                    Card(
                      child: ExpansionTile(
                        leading: const Icon(Icons.bug_report_outlined),
                        title: Text('DEBUG: ${_locationsFromAPI.length} total (${_locationsFromAPI.where((l) => l['statut'] == 'en_cours').length} en cours)'),
                        childrenPadding: const EdgeInsets.all(16),
                        children: _locationsFromAPI.map((loc) => ListTile(
                          dense: true,
                          leading: Icon(loc['statut'] == 'en_attente' ? Icons.hourglass_empty : Icons.check, color: loc['statut'] == 'en_attente' ? Colors.orange : Colors.green),
                          title: Text('${loc['code']} - ${loc['appareilNom']}'),
                          subtitle: Text('${loc['clientNom']} | ${loc['statut']}'),
                          trailing: Text('${loc['montantTotal']} FCFA'),
                          onTap: () => _showLocationDetails(loc),
                        )).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performApprove(int id) async {
    try {
      await ApiService.approveLocation(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Location validée!'), backgroundColor: Colors.green));
        _loadLocationsFromAPI();
        _loadAppareilsFromAPI();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _createTestPending() async {
    try {
      final today = DateTime.now();
      final result = await ApiService.createLocation(
        1, // GPS E600
        today.add(Duration(days: 1)).toIso8601String().split('T')[0],
        today.add(Duration(days: 3)).toIso8601String().split('T')[0],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ TEST créée: ${result['location']['code']}'), backgroundColor: Colors.green),
        );
        _loadLocationsFromAPI();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Erreur TEST: $e'), backgroundColor: Colors.red));
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
              Icon(Icons.cancel, color: Colors.red),
              const SizedBox(width: 8),
              Text('Rejeter ${location['code']}'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cette raison sera visible par le client',
                          style: TextStyle(color: Colors.orange.shade800),
                        ),
                      ),
                    ],
                  ),
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
                decoration: const InputDecoration(
                  labelText: 'Raison du rejet',
                  hintText: 'Appareil indisponible, dates impossibles...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.message),
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
                            SnackBar(
                              content: Text("Demande ${location['code']} rejetée"),
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              label: const Text('Rejeter'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationDetails(Map<String, dynamic> location) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${location['code']} (${location['statut']})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client: ${location['clientNom']}'),
            Text('Email: ${location['clientEmail']}'),
            Text('Tel: ${location['clientPhone']}'),
            Text('Appareil: ${location['appareilNom']}'),
            Text('Total: ${location['montantTotal']} FCFA'),
            Text('${location['dateDebut']} → ${location['dateFin']}'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }
}
