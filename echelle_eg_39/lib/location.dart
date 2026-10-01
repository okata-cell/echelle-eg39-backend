import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'appareil_images.dart';
import 'data_manager.dart';
import 'api_service.dart';
import 'login.page.dart';
import 'rental_booking_dates.dart';
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

typedef LocationEquipmentLoader =
    Future<List<Map<String, dynamic>>> Function({bool? disponible});
typedef LocationAvailabilityLoader =
    Future<Map<String, dynamic>> Function({
      required int appareilId,
      required String dateDebut,
      required String dateFin,
    });
typedef LocationCreator =
    Future<Map<String, dynamic>> Function(
      int appareilId,
      String dateDebut,
      String dateFin,
    );

class LocationScreen extends StatefulWidget {
  const LocationScreen({
    super.key,
    this.loadAppareils = ApiService.getAppareils,
    this.checkAvailability = ApiService.getLocationAvailability,
    this.createLocation = ApiService.createLocation,
    this.today = DateTime.now,
  });

  final LocationEquipmentLoader loadAppareils;
  final LocationAvailabilityLoader checkAvailability;
  final LocationCreator createLocation;
  final DateTime Function() today;

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final _dataManager = DataManager();
  List<Equipment> _apiAppareils = [];

  String _searchQuery = '';
  String _selectedCategory = 'Tous';

  final List<String> _categories = [
    'Tous',
    'GPS',
    'Station totale',
    'Niveau',
    'Mire',
    'Trepied',
    'Drone',
    'Laser',
    'Réflecteur',
    'Canne',
    'Antenne',
    'Accessoire',
    'Scanner 3D',
  ];

  @override
  void initState() {
    super.initState();
    _loadAppareilsFromAPI();
    _dataManager.addListener(_onDataManagerChanged);
  }

  Future<void> _loadAppareilsFromAPI() async {
    try {
      final appareils = await widget.loadAppareils();
      if (mounted && appareils.isNotEmpty) {
        setState(() {
          _apiAppareils = appareils
              .map(
                (a) => Equipment(
                  id: a['id'] as int,
                  name: a['nom'] as String,
                  category: a['type'] as String,
                  price: a['prixLocation'] as int,
                  available: a['horsService'] is bool
                      ? !(a['horsService'] as bool)
                      : a['disponible'] as bool? ?? true,
                  imageUrl:
                      a['imageUrl'] as String? ??
                      AppareilImages.getImageUrlForType(
                        a['type'] as String? ?? '',
                      ),
                  role: _getRoleDescription(a['type'] as String? ?? ''),
                ),
              )
              .toList();
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

  @override
  void dispose() {
    _dataManager.removeListener(_onDataManagerChanged);
    super.dispose();
  }

  List<Equipment> get _filteredEquipments {
    return _apiAppareils.where((eq) {
      final matchesSearch = eq.name.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final matchesCategory =
          _selectedCategory == 'Tous' || eq.category == _selectedCategory;
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
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF9CA3AF),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              setState(() => _searchQuery = '');
                            },
                            icon: const Icon(
                              Icons.clear,
                              color: Color(0xFF9CA3AF),
                            ),
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
                      borderSide: const BorderSide(
                        color: Color(0xFF2563EB),
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
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
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
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
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF374151),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
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
                        checkAvailability: widget.checkAvailability,
                        createLocation: widget.createLocation,
                        today: widget.today,
                        onRefresh: _loadAppareilsFromAPI,
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
          Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
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
  final LocationAvailabilityLoader checkAvailability;
  final LocationCreator createLocation;
  final DateTime Function() today;
  final VoidCallback onRefresh;

  const _EquipmentCard({
    super.key,
    required this.equipment,
    required this.checkAvailability,
    required this.createLocation,
    required this.today,
    required this.onRefresh,
  });

  @override
  State<_EquipmentCard> createState() => _EquipmentCardState();
}

class _EquipmentCardState extends State<_EquipmentCard> {
  late DateTime _dateDebut;
  DateTime? _dateFin;
  bool _isLoadingAvailability = false;
  bool? _isPeriodAvailable;
  bool _availabilityCheckFailed = false;
  String? _availabilityMessage;
  bool _isSubmitting = false;
  int _availabilityRequestId = 0;

  @override
  void initState() {
    super.initState();
    _dateDebut = DateUtils.dateOnly(widget.today());
  }

  @override
  void didUpdateWidget(_EquipmentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.equipment.id != widget.equipment.id) {
      _dateDebut = DateUtils.dateOnly(widget.today());
      _dateFin = null;
      _isPeriodAvailable = null;
      _availabilityCheckFailed = false;
      _availabilityMessage = null;
      _isLoadingAvailability = false;
      _availabilityRequestId++;
    }
  }

  Future<void> _chooseStartDate() async {
    final today = DateUtils.dateOnly(widget.today());
    final initialDate = _dateDebut.isBefore(today) ? today : _dateDebut;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Choisissez la date de début',
      confirmText: 'Continuer',
    );
    if (!mounted || pickedDate == null) return;

    final dateDebut = DateUtils.dateOnly(pickedDate);
    if (dateDebut == _dateDebut) return;

    setState(() {
      _dateDebut = dateDebut;
      _dateFin = null;
      _isPeriodAvailable = null;
      _availabilityCheckFailed = false;
      _availabilityMessage = null;
      _isLoadingAvailability = false;
      _availabilityRequestId++;
    });
  }

  Future<void> _chooseReturnDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dateFin ?? _dateDebut,
      firstDate: _dateDebut,
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Choisissez la date de retour',
      confirmText: 'Continuer',
    );
    if (!mounted || pickedDate == null) return;

    final dateFin = DateUtils.dateOnly(pickedDate);
    final requestId = ++_availabilityRequestId;
    setState(() {
      _dateFin = dateFin;
      _isPeriodAvailable = null;
      _availabilityCheckFailed = false;
      _availabilityMessage = null;
      _isLoadingAvailability = true;
    });

    try {
      final availability = await widget.checkAvailability(
        appareilId: widget.equipment.id,
        dateDebut: rentalDateIso(_dateDebut),
        dateFin: rentalDateIso(dateFin),
      );
      if (!mounted || requestId != _availabilityRequestId) return;
      final available = availability['disponible'] == true;
      setState(() {
        _isPeriodAvailable = available;
        _availabilityCheckFailed = false;
        _availabilityMessage = available
            ? null
            : availability['raison'] == 'hors_service'
            ? 'Cet appareil est temporairement hors service.'
            : 'Cette période chevauche une autre réservation.';
      });
    } catch (error) {
      if (!mounted || requestId != _availabilityRequestId) return;
      setState(() {
        _isPeriodAvailable = null;
        _availabilityCheckFailed = true;
        _availabilityMessage =
            'Vérification indisponible. Envoyez la demande ; la disponibilité sera confirmée par le serveur.';
      });
      debugPrint('Échec de vérification du créneau: $error');
    } finally {
      if (mounted && requestId == _availabilityRequestId) {
        setState(() => _isLoadingAvailability = false);
      }
    }
  }

  Future<void> _submitLocationRequest() async {
    final dateFin = _dateFin;
    if (_isSubmitting ||
        dateFin == null ||
        _isLoadingAvailability ||
        (_isPeriodAvailable != true && !_availabilityCheckFailed) ||
        !widget.equipment.available) {
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      final token = await ApiService.ensureAuthenticated();
      if (token == null || !mounted) {
        _showLoginRequiredDialog();
        return;
      }

      await widget.createLocation(
        widget.equipment.id,
        rentalDateIso(_dateDebut),
        rentalDateIso(dateFin),
      );

      if (!mounted) return;
      setState(() {
        _dateFin = null;
        _isPeriodAvailable = null;
        _availabilityCheckFailed = false;
        _availabilityMessage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Demande de location envoyée pour ${widget.equipment.name}',
          ),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      widget.onRefresh();
    } catch (error) {
      if (mounted) {
        if (error is ApiException && error.statusCode == 409) {
          setState(() {
            _isPeriodAvailable = false;
            _availabilityCheckFailed = false;
            _availabilityMessage = error.message;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
    final isPeriodUnavailable = _dateFin != null && _isPeriodAvailable == false;
    final isAvailable =
        widget.equipment.available &&
        _dateFin != null &&
        !_isLoadingAvailability &&
        (_isPeriodAvailable == true || _availabilityCheckFailed) &&
        !_isSubmitting;
    final availabilityLabel = !widget.equipment.available
        ? 'Hors service'
        : isPeriodUnavailable
        ? 'Indisponible'
        : _availabilityCheckFailed
        ? 'À confirmer'
        : 'Disponible';
    final availabilityBadgeColor =
        !widget.equipment.available || isPeriodUnavailable
        ? const Color(0xFFFEE2E2)
        : _availabilityCheckFailed
        ? const Color(0xFFFEF3C7)
        : const Color(0xFFD1FAE5);
    final availabilityTextColor =
        !widget.equipment.available || isPeriodUnavailable
        ? const Color(0xFFDC2626)
        : _availabilityCheckFailed
        ? const Color(0xFFB45309)
        : const Color(0xFF059669);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
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
              openImageZoom(context, imageUrl: widget.equipment.imageUrl);
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: availabilityBadgeColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          availabilityLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: availabilityTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
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
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting ? null : _chooseStartDate,
                      icon: const Icon(Icons.event_outlined, size: 16),
                      label: Text(
                        'Début : ${rentalDateLabel(_dateDebut)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 11),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting ? null : _chooseReturnDate,
                      icon: const Icon(Icons.event_outlined, size: 16),
                      label: Text(
                        _dateFin == null
                            ? 'Choisir la date de retour'
                            : 'Retour : ${rentalDateLabel(_dateFin!)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 11),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  if (_isLoadingAvailability) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Vérification de la période…',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ] else if (_availabilityMessage != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _availabilityMessage!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: const Color(0xFFDC2626),
                      ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
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
                                'Louer',
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
