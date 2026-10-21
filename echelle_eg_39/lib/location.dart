import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'appareil_images.dart';
import 'data_manager.dart';
import 'api_service.dart';
import 'login.page.dart';
import 'rental_booking_dates.dart';
import 'widgets/image_zoom_viewer.dart' show openImageZoom;

class _LocationTokens {
  static const canvas = Color(0xFFF5F5F7);
  static const surface = Colors.white;
  static const ink = Color(0xFF1D1D1F);
  static const body = Color(0xFF333333);
  static const muted = Color(0xFF7A7A7A);
  static const border = Color(0xFFE0E0E0);
  static const divider = Color(0xFFF0F0F0);
  static const primary = Color(0xFF0066CC);
  static const disabledSurface = Color(0xFFE5E5EA);
  static const available = Color(0xFF23865B);
  static const unavailable = Color(0xFFB42318);
  static const confirmation = Color(0xFF9A6700);
}

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
  final _searchController = TextEditingController();
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
      debugPrint('Failed to load rental equipment: $e');
    }
  }

  void _onDataManagerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
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
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      color: _LocationTokens.ink,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.45,
    );

    return Scaffold(
      backgroundColor: _LocationTokens.canvas,
      appBar: AppBar(
        toolbarHeight: 54,
        backgroundColor: _LocationTokens.surface,
        surfaceTintColor: _LocationTokens.surface,
        elevation: 0,
        titleSpacing: 16,
        automaticallyImplyLeading: false,
        title: Text('Location d’appareils', style: titleStyle),
        actions: [
          IconButton(
            onPressed: _loadAppareilsFromAPI,
            tooltip: 'Actualiser',
            style: IconButton.styleFrom(
              backgroundColor: _LocationTokens.canvas,
              foregroundColor: _LocationTokens.primary,
              minimumSize: const Size(40, 40),
              maximumSize: const Size(40, 40),
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.refresh, size: 21),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: _LocationTokens.surface,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _LocationTokens.body,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Rechercher un appareil...',
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _LocationTokens.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: _LocationTokens.muted,
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        tooltip: 'Effacer la recherche',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: const Icon(
                          Icons.close,
                          color: _LocationTokens.muted,
                          size: 18,
                        ),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: _LocationTokens.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: _LocationTokens.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(
                    color: _LocationTokens.primary,
                    width: 1.5,
                  ),
                ),
                filled: true,
                fillColor: _LocationTokens.canvas,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
          Container(
            height: 50,
            color: _LocationTokens.surface,
            padding: const EdgeInsets.fromLTRB(16, 4, 0, 4),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                return ChoiceChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (_) =>
                      setState(() => _selectedCategory = category),
                  showCheckmark: false,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : _LocationTokens.body,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  backgroundColor: _LocationTokens.surface,
                  selectedColor: _LocationTokens.primary,
                  side: BorderSide(
                    color: isSelected
                        ? _LocationTokens.primary
                        : _LocationTokens.border,
                  ),
                  shape: const StadiumBorder(),
                );
              },
            ),
          ),
          Expanded(
            child: _filteredEquipments.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    itemCount: _filteredEquipments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
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
          const Icon(Icons.search_off, size: 48, color: _LocationTokens.muted),
          const SizedBox(height: 16),
          Text(
            'Aucun équipement trouvé',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _LocationTokens.body,
              fontSize: 16,
              fontWeight: FontWeight.w600,
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
    final canRent =
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
    final availabilityColor = !widget.equipment.available || isPeriodUnavailable
        ? _LocationTokens.unavailable
        : _availabilityCheckFailed
        ? _LocationTokens.confirmation
        : _LocationTokens.available;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _LocationTokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _LocationTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildEquipmentPhoto(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.equipment.name,
                        key: ValueKey(
                          'location-equipment-name-${widget.equipment.id}',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: _LocationTokens.ink,
                          fontSize: 20,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.45,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildAvailabilityBadge(
                      availabilityLabel,
                      availabilityColor,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _LocationTokens.canvas,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        widget.equipment.category,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: _LocationTokens.body,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    if (widget.equipment.role != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            widget.equipment.role!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: _LocationTokens.muted,
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        'Prix / jour',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _LocationTokens.body,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      '${NumberFormat.decimalPattern('fr_FR').format(widget.equipment.price)} FCFA',
                      key: ValueKey(
                        'location-equipment-price-${widget.equipment.id}',
                      ),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: _LocationTokens.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 12, bottom: 12),
                  child: Divider(height: 1, color: _LocationTokens.divider),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildDateButton(
                        key: ValueKey(
                          'location-start-date-${widget.equipment.id}',
                        ),
                        label: 'Début',
                        value: rentalDateLabel(_dateDebut),
                        semanticLabel: 'Début : ${rentalDateLabel(_dateDebut)}',
                        onPressed: _isSubmitting ? null : _chooseStartDate,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDateButton(
                        key: ValueKey(
                          'location-return-date-${widget.equipment.id}',
                        ),
                        label: 'Date de retour',
                        value: _dateFin == null
                            ? 'À choisir'
                            : rentalDateLabel(_dateFin!),
                        semanticLabel: _dateFin == null
                            ? 'Choisir la date de retour'
                            : 'Retour : ${rentalDateLabel(_dateFin!)}',
                        onPressed: _isSubmitting ? null : _chooseReturnDate,
                        isEmphasized: _dateFin == null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                _buildAvailabilityFeedback(
                  isPeriodUnavailable: isPeriodUnavailable,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    key: ValueKey('location-rent-${widget.equipment.id}'),
                    onPressed: canRent ? _submitLocationRequest : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _LocationTokens.primary,
                      disabledBackgroundColor: _LocationTokens.disabledSurface,
                      foregroundColor: Colors.white,
                      disabledForegroundColor: _LocationTokens.muted,
                      elevation: 0,
                      shape: const StadiumBorder(),
                      textStyle: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    child: _isSubmitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Louer'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentPhoto() {
    void showZoom() {
      openImageZoom(
        context,
        imageUrl: widget.equipment.imageUrl,
        fallbackUrl: AppareilImages.getImageUrlForType(
          widget.equipment.category,
        ),
        title: widget.equipment.name,
      );
    }

    return AspectRatio(
      aspectRatio: 1.93,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            button: true,
            label: 'Agrandir la photo de ${widget.equipment.name}',
            child: GestureDetector(
              key: ValueKey('location-equipment-photo-${widget.equipment.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: showZoom,
              child: Image.network(
                widget.equipment.imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: _LocationTokens.canvas,
                    alignment: Alignment.center,
                    child: const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(
                        color: _LocationTokens.primary,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  color: _LocationTokens.canvas,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    size: 36,
                    color: _LocationTokens.muted,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: IconButton(
              key: ValueKey('location-equipment-zoom-${widget.equipment.id}'),
              tooltip: 'Agrandir la photo',
              onPressed: showZoom,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.94),
                foregroundColor: _LocationTokens.ink,
                minimumSize: const Size(40, 40),
                maximumSize: const Size(40, 40),
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.zoom_in, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityBadge(String label, Color color) {
    return Semantics(
      label: 'État de l’appareil : $label',
      child: Container(
        constraints: const BoxConstraints(minHeight: 30),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: _LocationTokens.canvas,
          borderRadius: BorderRadius.circular(999),
        ),
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: _LocationTokens.body,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateButton({
    required Key key,
    required String label,
    required String value,
    required String semanticLabel,
    required VoidCallback? onPressed,
    bool isEmphasized = false,
  }) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: SizedBox(
        height: 58,
        child: OutlinedButton(
          key: key,
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: _LocationTokens.primary,
            backgroundColor: _LocationTokens.surface,
            side: const BorderSide(color: _LocationTokens.border),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _LocationTokens.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 15,
                    color: _LocationTokens.primary,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isEmphasized
                            ? _LocationTokens.primary
                            : _LocationTokens.ink,
                        fontSize: 13,
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
    );
  }

  Widget _buildAvailabilityFeedback({required bool isPeriodUnavailable}) {
    final String message;
    final Color foreground;
    final Color background;
    final IconData icon;

    if (_isLoadingAvailability) {
      message = 'Vérification de la période…';
      foreground = _LocationTokens.body;
      background = _LocationTokens.canvas;
      icon = Icons.schedule;
    } else if (_availabilityMessage != null) {
      message = _availabilityMessage!;
      foreground =
          _availabilityCheckFailed ||
              (!isPeriodUnavailable && !widget.equipment.available)
          ? _LocationTokens.confirmation
          : _LocationTokens.unavailable;
      background = foreground == _LocationTokens.confirmation
          ? const Color(0xFFFFF6DB)
          : const Color(0xFFFDF1EF);
      icon = _availabilityCheckFailed
          ? Icons.info_outline
          : Icons.error_outline;
    } else if (_dateFin != null && _isPeriodAvailable == true) {
      message = 'Période disponible pour les dates choisies.';
      foreground = _LocationTokens.available;
      background = const Color(0xFFEAF5EF);
      icon = Icons.check_circle_outline;
    } else {
      message =
          'La disponibilité de la période sera vérifiée après le choix du retour.';
      foreground = _LocationTokens.body;
      background = _LocationTokens.canvas;
      icon = Icons.info_outline;
    }

    return Semantics(
      liveRegion: _isLoadingAvailability || _availabilityMessage != null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoadingAvailability)
              SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            else
              Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: foreground,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: _availabilityMessage == null
                      ? FontWeight.w400
                      : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
