import 'dart:async';
import 'package:flutter/material.dart';
import 'data_manager.dart';
import 'api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.page.dart';
import 'widgets/image_zoom_viewer.dart';

class Equipment {
  final int id;
  final String name;
  final String category;
  final int price;
  final bool available;
  final String imageUrl;

  Equipment({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.available,
    required this.imageUrl,
  });
}

class LocationScreen extends StatefulWidget {
  const LocationScreen({Key? key}) : super(key: key);

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final _dataManager = DataManager();

  String _searchQuery = '';
  String _selectedCategory = 'Tous';
  String _currentUserId = '';

  final List<String> _categories = [
    'Tous', 'GPS', 'Station totale', 'Niveau', 'Mire',
    'Trepied', 'Drone', 'Laser', 'Réflecteur'
  ];

  List<Equipment> get _equipments => _dataManager.appareils.map((a) => Equipment(
    id: int.parse(a.id.substring(4)),
    name: a.nom,
    category: a.type,
    price: a.prixLocation,
    available: a.disponible,
    imageUrl: a.imageUrl,
  )).toList();

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _dataManager.initialize();
    _dataManager.addListener(() => setState(() {}));
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
    _dataManager.removeListener(() => setState(() {}));
    super.dispose();
  }

  List<Equipment> get _filteredEquipments {
    return _equipments.where((eq) {
      final matchesSearch = eq.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'Tous' || eq.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Location d\'appareils',
          style: TextStyle(color: Color(0xFF111827)),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
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
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
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
                          label: Text(category),
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
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
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
                    _dataManager.initialize();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EquipmentCard – StatefulWidget with 24h cooldown per equipment per user
// ─────────────────────────────────────────────────────────────────────────────

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

  String get _cooldownKey =>
      'cooldown_${widget.userId}_${widget.equipment.id}';

  @override
  void initState() {
    super.initState();
    _loadCooldown();
    // Refresh countdown display every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadCooldown();
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
        // Cooldown expired – clean up
        await prefs.remove(_cooldownKey);
        if (mounted) setState(() => _cooldownUntil = null);
      }
    } else {
      if (mounted) setState(() => _cooldownUntil = null);
    }
  }

  Future<void> _saveCooldown() async {
    if (widget.userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final until = DateTime.now().add(const Duration(hours: 24));
    await prefs.setString(_cooldownKey, until.toIso8601String());
    if (mounted) setState(() => _cooldownUntil = until);
  }

  bool get _isInCooldown =>
      _cooldownUntil != null && _cooldownUntil!.isAfter(DateTime.now());

  Duration get _remaining {
    if (_cooldownUntil == null) return Duration.zero;
    final r = _cooldownUntil!.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  String _formatCountdown(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}min';
    return '${m}min';
  }

  // ───────────────────────── Reservation dialog ─────────────────────────────

  void _handleReservePressed() async {
    // Check authentication first - avec reconnexion automatique si nécessaire
    final token = await ApiService.ensureAuthenticated();
    if (!mounted) return;

    if (token == null) {
      // Not logged in → prompt login
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Connexion requise'),
          content: const Text('Veuillez vous connecter pour réserver un appareil.'),
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
              child: const Text('Se connecter'),
            ),
          ],
        ),
      );
      return;
    }

    // Re-check cooldown (in case state is stale)
    await _loadCooldown();
    if (!mounted) return;

    if (_isInCooldown) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Vous avez déjà réservé cet appareil. Prochaine réservation dans ${_formatCountdown(_remaining)}.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _showReservationDialog();
  }

  void _showReservationDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final userName  = prefs.getString('userName')  ?? 'Client connecté';
    final userEmail = prefs.getString('userEmail') ?? 'client@exemple.com';
    final userPhone = prefs.getString('userPhone') ?? '+228 00 00 00 00';

    if (!mounted) return;

    DateTime? selectedStartDate;
    DateTime? selectedEndDate;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('Réserver ${widget.equipment.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Date de début
                  ListTile(
                    title: Text(selectedStartDate == null
                        ? 'Sélectionner date de début'
                        : 'Début : ${selectedStartDate!.toLocal().toString().split(' ')[0]}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedStartDate = picked;
                          if (selectedEndDate != null &&
                              selectedEndDate!.isBefore(picked)) {
                            selectedEndDate = picked.add(const Duration(days: 1));
                          }
                        });
                      }
                    },
                  ),
                  // Date de fin
                  ListTile(
                    title: Text(selectedEndDate == null
                        ? 'Sélectionner date de fin'
                        : 'Fin : ${selectedEndDate!.toLocal().toString().split(' ')[0]}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedStartDate ?? DateTime.now(),
                        firstDate: selectedStartDate ?? DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedEndDate = picked);
                      }
                    },
                  ),
                  // Résumé durée / total
                  if (selectedStartDate != null && selectedEndDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'Durée : ${selectedEndDate!.difference(selectedStartDate!).inDays + 1} jour(s)\n'
                        'Total : ${((selectedEndDate!.difference(selectedStartDate!).inDays + 1) * widget.equipment.price).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} FCFA',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _isSubmitting ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: (selectedStartDate != null &&
                          selectedEndDate != null &&
                          !_isSubmitting)
                      ? () async {
                          setDialogState(() => _isSubmitting = true);
                          try {
                            final days =
                                selectedEndDate!.difference(selectedStartDate!).inDays + 1;
                            final total = days * widget.equipment.price;

                            try {
                              await ApiService.createLocationRequest(
                                widget.equipment.id,
                                selectedStartDate!.toIso8601String(),
                                selectedEndDate!.toIso8601String(),
                                days,
                                total,
                              );
                            } catch (apiError) {
                              // Backend unavailable → save locally
                              debugPrint('API non disponible, sauvegarde locale: $apiError');
                              final locationRequests =
                                  prefs.getStringList('local_locations') ?? [];
                              locationRequests.add(
                                '${widget.equipment.id}|${widget.equipment.name}'
                                '|${selectedStartDate!.toIso8601String()}'
                                '|${selectedEndDate!.toIso8601String()}'
                                '|$days|$total'
                                '|$userName|$userEmail|$userPhone',
                              );
                              await prefs.setStringList('local_locations', locationRequests);
                            }

                            // ✅ Save 24h cooldown for this user + equipment
                            await _saveCooldown();

                            if (!mounted) return;
                            Navigator.of(ctx).pop();

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${widget.equipment.name} réservé avec succès ! '
                                  'Prochaine réservation possible dans 24h.',
                                ),
                                backgroundColor: const Color(0xFF059669),
                                duration: const Duration(seconds: 4),
                              ),
                            );

                            widget.onRefresh();
                          } catch (e) {
                            setDialogState(() => _isSubmitting = false);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erreur : $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      : null,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Confirmer'),
                ),
              ],
            );
          },
        );
      },
    );

    // Reset submit flag when dialog closes
    if (mounted) setState(() => _isSubmitting = false);
  }

  // ─────────────────────────────── UI ────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final equipment = widget.equipment;
    final inCooldown = _isInCooldown;
    final canReserve = equipment.available && !inCooldown;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Image (tappable → zoom plein écran)
          SizedBox(
            width: 128,
            height: 128,
            child: ZoomableImage(
              imageUrl: equipment.imageUrl,
              title: equipment.name,
              width: 128,
              height: 128,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),

          // Details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    equipment.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    equipment.category,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${equipment.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} FCFA/jour',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Availability badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: equipment.available
                              ? const Color(0xFFD1FAE5)
                              : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          equipment.available ? 'Disponible' : 'Indisponible',
                          style: TextStyle(
                            fontSize: 12,
                            color: equipment.available
                                ? const Color(0xFF059669)
                                : const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                      const Spacer(),

                      // Reserve button (with cooldown label)
                      _buildReserveButton(canReserve, inCooldown),
                    ],
                  ),

                  // Cooldown hint below button row
                  if (inCooldown)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Icon(Icons.access_time,
                              size: 12, color: Color(0xFFD97706)),
                          const SizedBox(width: 4),
                          Text(
                            'Dispo dans ${_formatCountdown(_remaining)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFD97706),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReserveButton(bool canReserve, bool inCooldown) {
    if (inCooldown) {
      return ElevatedButton.icon(
        onPressed: null, // disabled
        icon: const Icon(Icons.lock_clock, size: 16),
        label: Text(
          _formatCountdown(_remaining),
          style: const TextStyle(fontSize: 11),
        ),
        style: ElevatedButton.styleFrom(
          disabledBackgroundColor: const Color(0xFFFEF3C7),
          disabledForegroundColor: const Color(0xFFD97706),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: canReserve ? _handleReservePressed : null,
      icon: const Icon(Icons.calendar_today, size: 16),
      label: const Text('Réserver', style: TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 209, 216, 231),
        disabledBackgroundColor: const Color(0xFFD1D5DB),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
