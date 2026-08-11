import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'appareil_images.dart';
import 'data_manager.dart';
import 'api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.page.dart';
import 'widgets/image_zoom_viewer.dart' show openImageZoom;

class Equipment {
  final int id;
  final String name;
  final String category;
  final int price;
  final bool available;
  final String imageUrl;
  final String? role;

  Equipment({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.available,
    required this.imageUrl,
    this.role,
  });
}

class LocationScreen extends StatefulWidget {
  const LocationScreen({Key? key}) : super(key: key);

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final _dataManager = DataManager();
  List<Equipment> _apiAppareils = [];

  String _searchQuery = '';
  String _selectedCategory = 'Tous';
  String _currentUserId = '';

  final List<String> _categories = [
    'Tous', 'GPS', 'Station totale', 'Niveau', 'Mire',
    'Trepied', 'Drone', 'Laser', 'Réflecteur', 'Canne',
    'Antenne', 'Accessoire', 'Scanner 3D'
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadAppareilsFromAPI();
    _dataManager.addListener(_onDataManagerChanged);
  }

  Future<void> _loadAppareilsFromAPI() async {
    try {
      final appareils = await ApiService.getAppareils();
      if (mounted && appareils.isNotEmpty) {
        setState(() {
          _apiAppareils = appareils.map((a) => Equipment(
                id: a['id'] as int,
                name: a['nom'] as String,
                category: a['type'] as String,
                price: a['prixLocation'] as int,
                available: a['disponible'] as bool? ?? true,
                imageUrl: a['imageUrl'] as String? ??
                    AppareilImages.getImageUrlForType(
                      a['type'] as String? ?? '',
                    ),
                role: _getRoleDescription(a['type'] as String? ?? ''),
              )).toList();
        });
      }
    } catch (e) {
      print('⚠️ Failed to load appareils from API: $e');
    }
  }

  void _onDataManagerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail') ?? '';
    if (mounted) {
      setState(() => _currentUserId = email);
    }
  }

  @override
  void dispose() {
    _dataManager.removeListener(_onDataManagerChanged);
    super.dispose();
  }

  List<Equipment> get _filteredEquipments {
    return _apiAppareils.where((eq) {
      final matchesSearch = eq.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'Tous' || eq.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  String _getRoleDescription(String type) {
    switch (type.toLowerCase()) {
      case 'gps':
        return 'Positionnement et levés de précision';
      case 'station totale':
        return 'Mesures d\'implantation et de bornage';
      case 'niveau':
        return 'Nivellement et contrôle d\'altitude';
      case 'théodolite':
        return 'Relevés angulaires de haute précision';
      case 'drone':
        return 'Cartographie aérienne et modélisation 3D';
      case 'mire':
        return 'Cibles de mesure pour stations totales';
      case 'trepied':
        return 'Support stable pour instruments';
      case 'canne':
        return 'Support portable pour antenne GPS';
      case 'antenne':
        return 'Réception satellite RTK';
      case 'reflecteur':
        return 'Cible de mesure sans prisme';
      case 'scanner 3d':
        return 'Acquisition 3D et nuages de points';
      default:
        return 'Équipement topographique professionnel';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Location d\'appareils',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _loadAppareilsFromAPI,
            icon: const Icon(Icons.refresh, color: Color(0xFF2563EB)),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Rechercher un appareil...',
                    hintStyle: GoogleFonts.poppins(
                      color: const Color(0xFF9CA3AF),
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              setState(() => _searchQuery = '');
                            },
                            icon: const Icon(Icons.clear, color: Color(0xFF9CA3AF)),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = _selectedCategory == category;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            category,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                          backgroundColor: const Color(0xFFF3F4F6),
                          selectedColor: const Color(0xFF2563EB),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF374151),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _filteredEquipments.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredEquipments.length,
                    itemBuilder: (context, index) {
                      final equipment = _filteredEquipments[index];
                      return _EquipmentCard(
                        key: ValueKey('card_${equipment.id}'),
                        equipment: equipment,
                        userId: _currentUserId,
                        onRefresh: () {
                          _loadCurrentUser();
                          _loadAppareilsFromAPI();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun équipement trouvé',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _EquipmentCard extends StatefulWidget {
  final Equipment equipment;
  final String userId;
  final VoidCallback onRefresh;

  const _EquipmentCard({
    super.key,
    required this.equipment,
    required this.userId,
    required this.onRefresh,
  });

  @override
  State<_EquipmentCard> createState() => _EquipmentCardState();
}

class _EquipmentCardState extends State<_EquipmentCard> {
  DateTime? _cooldownUntil;
  Timer? _timer;
  bool _isSubmitting = false;
  bool _hasPendingRequest = false;

  String get _cooldownKey => 'cooldown_${widget.userId}_${widget.equipment.id}';
  String get _pendingKey => 'pending_${widget.userId}_${widget.equipment.id}';

  @override
  void initState() {
    super.initState();
    _loadCooldown();
    _loadPending();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadCooldown();
    });
  }

  Future<void> _loadPending() async {
    if (widget.userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasPendingRequest = prefs.getBool(_pendingKey) ?? false;
    });
  }

  @override
  void didUpdateWidget(_EquipmentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.equipment.id != widget.equipment.id) {
      _loadCooldown();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadCooldown() async {
    if (widget.userId.isEmpty) {
      if (mounted) setState(() => _cooldownUntil = null);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_cooldownKey);
    if (stored != null) {
      final until = DateTime.parse(stored);
      if (until.isAfter(DateTime.now())) {
        if (mounted) setState(() => _cooldownUntil = until);
      } else {
        await prefs.remove(_cooldownKey);
        if (mounted) setState(() => _cooldownUntil = null);
      }
    } else {
      if (mounted) setState(() => _cooldownUntil = null);
    }
  }

  Future<void> _saveCooldown({DateTime? dateDebut, DateTime? dateFin}) async {
    if (widget.userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    DateTime until;
    if (dateDebut != null && dateFin != null) {
      final now = DateTime.now();
      if (now.isBefore(dateDebut)) {
        until = dateFin.add(const Duration(days: 1));
        await prefs.setString('${_cooldownKey}_start', dateDebut.toIso8601String());
      } else {
        until = dateFin.add(const Duration(days: 1));
      }
    } else if (dateFin != null) {
      until = dateFin.add(const Duration(days: 1));
    } else {
      until = DateTime.now().add(const Duration(hours: 24));
    }
    await prefs.setString(_cooldownKey, until.toIso8601String());
    if (mounted) setState(() => _cooldownUntil = until);
  }

  Future<void> _submitLocationRequest() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final token = await ApiService.ensureAuthenticated();
      if (token == null || !mounted) {
        _showLoginRequiredDialog();
        return;
      }

      final now = DateTime.now();
      final dateDebut = now.toIso8601String().split('T')[0];
      final dateFin = now.add(const Duration(days: 7)).toIso8601String().split('T')[0];

      await ApiService.createLocation(
        widget.equipment.id,
        dateDebut,
        dateFin,
      );

      await _saveCooldown(dateDebut: now, dateFin: now.add(const Duration(days: 7)));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Demande de location envoyée pour ${widget.equipment.name}'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Connexion requise'),
        content: const Text('Veuillez vous connecter pour louer un appareil.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
            ),
            child: const Text('Se connecter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOnCooldown = _cooldownUntil != null && _cooldownUntil!.isAfter(DateTime.now());
    final isAvailable = widget.equipment.available && !isOnCooldown && !_hasPendingRequest;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Image
          GestureDetector(
            onTap: () {
              openImageZoom(
                context,
                imageUrl: widget.equipment.imageUrl,
              );
            },
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: Image.network(
                widget.equipment.imageUrl,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    width: 120,
                    height: 120,
                    color: const Color(0xFFF3F4F6),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF2563EB),
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 120,
                    height: 120,
                    color: const Color(0xFFF3F4F6),
                    child: Icon(
                      Icons.image_not_supported,
                      size: 32,
                      color: Colors.grey[400],
                    ),
                  );
                },
              ),
            ),
          ),
          // Informations
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.equipment.name,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? const Color(0xFFD1FAE5)
                              : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isAvailable ? 'Disponible' : 'Indisponible',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isAvailable
                                ? const Color(0xFF059669)
                                : const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.equipment.category,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                  if (widget.equipment.role != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.equipment.role!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF6B7280),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Prix / jour',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF9CA3AF),
                            ),
                          ),
                          Text(
                            '${widget.equipment.price.toString()} FCFA',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: isAvailable ? _submitLocationRequest : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isAvailable
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFD1D5DB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: isAvailable ? 2 : 0,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isOnCooldown
                                    ? 'En cours'
                                    : _hasPendingRequest
                                        ? 'En attente'
                                        : 'Louer',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
