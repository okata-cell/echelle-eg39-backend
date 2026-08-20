import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'admin/admin_components.dart';
import 'admin/admin_tokens.dart';
import 'api_service.dart';
import 'appareil_images.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  List<Map<String, dynamic>> _locations = [];
  final Set<int> _busyLocationIds = <int>{};
  Timer? _autoRefreshTimer;
  bool _isLoading = true;
  String? _errorMessage;
  String _filter = 'en_attente';
  bool _isLoadingLocations = false;
  List<Map<String, dynamic>> _cachedVisibleLocations = [];
  final Map<String, int> _countCache = {};
  int _lastLocationsLength = 0;
  String _lastFilter = 'en_attente';

  @override
  void initState() {
    super.initState();
    print('📱 LocationPage ADMIN - initState()');
    _loadLocations();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadLocations(silent: true),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLocations({bool silent = false}) async {
    if (_isLoadingLocations) {
      print('⏳ _loadLocations ignoré (déjà en cours)');
      return;
    }
    _isLoadingLocations = true;
    print('🔄 _loadLocations démarré (silent=$silent)');

    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      await _checkAndExpireLocations();
      print('📡 Appel API getLocations...');
      final locations = await ApiService.getLocations().timeout(
        const Duration(seconds: 10),
      );
      print('✅ API getLocations OK: ${locations.length} locations reçues');

      if (!mounted) return;
      setState(() {
        _locations = locations;
        _isLoading = false;
        _errorMessage = null;
        _cachedVisibleLocations = [];
        _countCache.clear();
        _lastLocationsLength = 0;
      });
      print('✅ UI mise à jour avec ${locations.length} locations');
    } catch (error) {
      print('❌ Erreur _loadLocations: $error');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    } finally {
      _isLoadingLocations = false;
      print('🔄 _loadLocations terminé');
    }
  }

  Future<void> _checkAndExpireLocations() async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return;
      await http.get(
        Uri.parse('${ApiService.baseUrl}/locations/check-expired'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 3));
    } catch (error) {
      debugPrint('⚠️ Vérification expiration locations : $error');
    }
  }

  String _status(Map<String, dynamic> location) {
    return adminStatusKey(location['statut']);
  }

  List<Map<String, dynamic>> _historyLocations() {
    return _locations.where((location) {
      final status = _status(location);
      return status == 'termine' || status == 'rejetee';
    }).toList();
  }

  List<Map<String, dynamic>> _getFilteredLocations() {
    switch (_filter) {
      case 'en_attente':
        return _locations.where((location) => _status(location) == 'en_attente').toList();
      case 'en_cours':
        return _locations.where((location) => _status(location) == 'en_cours').toList();
      case 'corbeille':
        return _historyLocations();
      case 'tous':
      default:
        return List.from(_locations);
    }
  }

  List<Map<String, dynamic>> get _visibleLocations {
    if (_cachedVisibleLocations.isEmpty ||
        _lastFilter != _filter ||
        _lastLocationsLength != _locations.length) {
      _cachedVisibleLocations = _getFilteredLocations();
      _lastFilter = _filter;
      _lastLocationsLength = _locations.length;
    }
    return _cachedVisibleLocations;
  }

  int _countFor(String filter) {
    if (!_countCache.containsKey(filter)) {
      int count;
      switch (filter) {
        case 'en_attente':
          count = _locations.where((location) => _status(location) == 'en_attente').length;
          break;
        case 'en_cours':
          count = _locations.where((location) => _status(location) == 'en_cours').length;
          break;
        case 'corbeille':
          count = _historyLocations().length;
          break;
        case 'tous':
        default:
          count = _locations.length;
          break;
      }
      _countCache[filter] = count;
    }
    return _countCache[filter]!;
  }

  Future<void> _approveLocation(int locationId) async {
    if (!_startMutation(locationId)) return;

    try {
      await ApiService.approveLocation(locationId);
      if (mounted) {
        showAdminMessage(
          context,
          'Location #$locationId approuvée.',
          backgroundColor: AdminPalette.approvalGreen,
        );
        await _loadLocations();
      }
    } catch (error) {
      if (mounted) {
        showAdminMessage(
          context,
          'Approbation impossible : $error',
          backgroundColor: AdminPalette.destructiveRed,
        );
      }
    } finally {
      _finishMutation(locationId);
    }
  }

  Future<void> _rejectLocation(int locationId) async {
    if (_busyLocationIds.contains(locationId)) return;

    final reason = await showAdminRejectionSheet(
      context,
      entityLabel: 'la location #$locationId',
    );
    if (!mounted || reason == null || reason.trim().isEmpty) return;
    if (!_startMutation(locationId)) return;

    try {
      await ApiService.rejectLocation(locationId, reason);
      if (mounted) {
        showAdminMessage(
          context,
          'Location #$locationId rejetée.',
          backgroundColor: AdminPalette.destructiveRed,
        );
        await _loadLocations();
      }
    } catch (error) {
      if (mounted) {
        showAdminMessage(
          context,
          'Rejet impossible : $error',
          backgroundColor: AdminPalette.destructiveRed,
        );
      }
    } finally {
      _finishMutation(locationId);
    }
  }

  Future<void> _deleteLocation(int locationId) async {
    if (_busyLocationIds.contains(locationId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer de la corbeille ?'),
        content: Text('La location #$locationId sera supprimée définitivement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminPalette.destructiveRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true || !_startMutation(locationId)) return;

    try {
      await ApiService.deleteLocation(locationId);
      if (mounted) {
        showAdminMessage(
          context,
          'Location #$locationId supprimée.',
          backgroundColor: AdminPalette.destructiveRed,
        );
        await _loadLocations();
      }
    } catch (error) {
      if (mounted) {
        showAdminMessage(
          context,
          'Suppression impossible : $error',
          backgroundColor: AdminPalette.destructiveRed,
        );
      }
    } finally {
      _finishMutation(locationId);
    }
  }

  bool _startMutation(int locationId) {
    if (!mounted || _busyLocationIds.contains(locationId)) return false;
    setState(() => _busyLocationIds.add(locationId));
    return true;
  }

  void _finishMutation(int locationId) {
    if (!mounted) return;
    setState(() => _busyLocationIds.remove(locationId));
  }

  String _display(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _formatDateLong(Object? value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return 'date inconnue';

    try {
      final date = DateTime.parse(raw).toLocal();
      const months = [
        'janvier',
        'février',
        'mars',
        'avril',
        'mai',
        'juin',
        'juillet',
        'août',
        'septembre',
        'octobre',
        'novembre',
        'décembre',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return raw;
    }
  }

  Widget _buildEquipmentLeading(Map<String, dynamic> location) {
    final fallbackUrl = AppareilImages.getImageUrl(
      location['appareilId']?.toString() ?? '',
      location['appareilType']?.toString() ?? '',
    );
    final imageUrl = location['imageUrl']?.toString();

    return SizedBox(
      width: 50,
      height: 50,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AdminRadii.field),
        child: Image.network(
          imageUrl == null || imageUrl.isEmpty ? fallbackUrl : imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AdminPalette.blueprintBlue.withValues(alpha: 0.1),
            child: const Icon(Icons.gps_fixed, color: AdminPalette.blueprintBlue),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationDetails(Map<String, dynamic> location) {
    final clientPhone = _display(location['clientTelephone']);
    final reason = _display(location['commentaireAdmin']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AdminSpacing.lg,
          runSpacing: AdminSpacing.xs,
          children: [
            _buildMeta('Du ${_formatDateLong(location['dateDebut'])}'),
            _buildMeta('au ${_formatDateLong(location['dateFin'])}'),
            if (clientPhone.isNotEmpty) _buildMeta('☎ $clientPhone'),
          ],
        ),
        if (reason.isNotEmpty) ...[
          const SizedBox(height: AdminSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AdminSpacing.md),
            decoration: BoxDecoration(
              color: AdminPalette.destructiveRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AdminRadii.field),
              border: Border.all(
                color: AdminPalette.destructiveRed.withValues(alpha: 0.22),
              ),
            ),
            child: Text(
              'Note admin : $reason',
              style: const TextStyle(
                color: AdminPalette.destructiveRed,
                height: 1.35,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMeta(String text) {
    return Text(
      text,
      style: const TextStyle(color: AdminPalette.secondaryText, fontSize: 12),
    );
  }

  Widget _buildLocationItem(Map<String, dynamic> location, int index) {
    try {
      final locationId = (location['id'] is num)
          ? (location['id'] as num).toInt()
          : int.tryParse(location['id']?.toString() ?? '');
      
      // Debug: afficher le type et la valeur de l'ID
      print('🔍 location[id] type: ${location['id'].runtimeType}, value: ${location['id']}, parsed: $locationId');
      
      if (locationId == null) {
        print('⚠️ Location ID invalide à l\'index $index: ${location['id']}');
        return const SizedBox.shrink();
      }

    final amount = formatAdminAmount(location['montantTotal']);
    final equipment = _display(location['appareilNom'], fallback: 'Appareil non renseigné');
    final client = _display(location['clientNom'], fallback: 'Client non renseigné');
    final isHistory = _status(location) == 'termine' || _status(location) == 'rejetee';
    final isBusy = _busyLocationIds.contains(locationId);

    Widget footer;
    if (isAdminPending(location['statut'])) {
      footer = AdminDecisionBar(
        isBusy: isBusy,
        onApprove: () => _approveLocation(locationId),
        onReject: () => _rejectLocation(locationId),
      );
    } else if (isHistory) {
      footer = Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            onPressed: isBusy ? null : () => _deleteLocation(locationId),
            tooltip: 'Supprimer',
            icon: const Icon(Icons.delete_outline),
            color: AdminPalette.destructiveRed,
          ),
        ],
      );
    } else {
      footer = Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => _showLocationDetails(location),
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text('Voir le détail'),
          style: TextButton.styleFrom(foregroundColor: AdminPalette.blueprintBlue),
        ),
      );
    }

    return AdminWorkItemCard(
      key: ValueKey('loc_$locationId'),
      status: location['statut'],
      reference: 'Location #$locationId',
      title: equipment,
      requester: client,
      meta: 'Réservation d’équipement',
      amount: amount.isEmpty ? null : amount,
      leading: _buildEquipmentLeading(location),
      details: _buildLocationDetails(location),
      footer: footer,
      onTap: () => _showLocationDetails(location),
    );
    } catch (e, stack) {
      print('❌ Erreur build item index=$index locationId=${location['id']}: $e');
      print('📋 Stack: $stack');
      return const SizedBox.shrink();
    }
  }

  void _showLocationDetails(Map<String, dynamic> location) {
    final locationId = location['id']?.toString() ?? '';
    final equipment = _display(location['appareilNom'], fallback: 'Appareil non renseigné');
    final client = _display(location['clientNom'], fallback: 'Client non renseigné');
    final status = location['statut'];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(
          AdminSpacing.xxl,
          AdminSpacing.md,
          AdminSpacing.xxl,
          AdminSpacing.xxl,
        ),
        decoration: const BoxDecoration(
          color: AdminPalette.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AdminRadii.sheet)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AdminPalette.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: AdminSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Location #$locationId',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AdminPalette.primaryText,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  AdminStatusChip(status: status),
                ],
              ),
              const SizedBox(height: AdminSpacing.lg),
              _buildDetailRow('Équipement', equipment),
              _buildDetailRow('Client', client),
              _buildDetailRow(
                'Période',
                'Du ${_formatDateLong(location['dateDebut'])} au ${_formatDateLong(location['dateFin'])}',
              ),
              _buildDetailRow('Montant', formatAdminAmount(location['montantTotal'])),
              const SizedBox(height: AdminSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AdminSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: AdminPalette.secondaryText)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AdminPalette.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('🏗️ build() appelé - filter=$_filter isLoading=$_isLoading locations=${_locations.length}');
    try {
      final visibleLocations = _visibleLocations;
      Widget content;
      if (_isLoading && _locations.isEmpty) {
        content = SliverFillRemaining(
          hasScrollBody: false,
          child: AdminLoadingState(label: 'Chargement des locations…'),
        );
      } else if (_errorMessage != null && _locations.isEmpty) {
        content = SliverFillRemaining(
          hasScrollBody: false,
          child: AdminErrorState(
            message: _errorMessage!,
            onRetry: _loadLocations,
          ),
        );
      } else if (visibleLocations.isEmpty) {
        content = SliverFillRemaining(
          hasScrollBody: false,
          child: AdminEmptyState(
            icon: _filter == 'corbeille'
                ? Icons.delete_outline
                : Icons.inbox_outlined,
            title: _filter == 'en_attente'
                ? 'Aucune location en attente'
                : _filter == 'en_cours'
                    ? 'Aucune location active'
                    : _filter == 'corbeille'
                        ? 'La corbeille est vide'
                        : 'Aucune location enregistrée',
            message: _filter == 'en_attente'
                ? 'Les nouvelles réservations apparaîtront ici.'
                : 'Changez de filtre ou actualisez la file.',
          ),
        );
      } else {
        content = SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AdminSpacing.lg,
            AdminSpacing.sm,
            AdminSpacing.lg,
            AdminSpacing.section,
          ),
          sliver: SliverList.builder(
            itemCount: visibleLocations.length,
            itemBuilder: (context, index) => RepaintBoundary(
              child: Semantics(
                excludeSemantics: true,
                child: _buildLocationItem(visibleLocations[index], index),
              ),
            ),
          ),
        );
      }

      return CustomScrollView(
        key: const PageStorageKey<String>('locations_scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: AdminPageHeader(
              title: 'Locations',
              subtitle: 'Traitez les réservations d’équipement et suivez leur cycle.',
              icon: Icons.assignment_outlined,
              actions: [
                IconButton(
                  onPressed: _isLoading ? null : _loadLocations,
                  tooltip: 'Actualiser',
                  icon: const Icon(Icons.refresh),
                  color: AdminPalette.blueprintBlue,
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: AdminMetricCluster(
              primary: AdminMetric(
                label: 'Réservations à traiter',
                value: _countFor('en_attente'),
                icon: Icons.pending_actions_outlined,
              ),
              secondary: [
                AdminMetric(
                  label: 'Locations actives',
                  value: _countFor('en_cours'),
                  icon: Icons.play_circle_outline,
                ),
                AdminMetric(
                  label: 'Historique / rejetées',
                  value: _countFor('corbeille'),
                  icon: Icons.history_outlined,
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: AdminSegmentedFilter(
              selectedValue: _filter,
              onChanged: (value) => setState(() => _filter = value),
              options: [
                AdminFilterOption(
                  value: 'en_attente',
                  label: 'En attente',
                  count: _countFor('en_attente'),
                ),
                AdminFilterOption(
                  value: 'en_cours',
                  label: 'Actives',
                  count: _countFor('en_cours'),
                ),
                AdminFilterOption(
                  value: 'corbeille',
                  label: 'Historique',
                  count: _countFor('corbeille'),
                ),
                AdminFilterOption(
                  value: 'tous',
                  label: 'Toutes',
                  count: _countFor('tous'),
                ),
              ],
            ),
          ),
          content,
        ],
      );
    } catch (e, stack) {
      print('❌❌❌ CRASH dans build(): $e');
      print('📋 Stack: $stack');
      return CustomScrollView(
        key: const PageStorageKey<String>('locations_scroll_error'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: AdminPageHeader(
              title: 'Locations',
              subtitle: 'Traitez les réservations d’équipement et suivez leur cycle.',
              icon: Icons.assignment_outlined,
              actions: [
                IconButton(
                  onPressed: _loadLocations,
                  tooltip: 'Actualiser',
                  icon: const Icon(Icons.refresh),
                  color: AdminPalette.blueprintBlue,
                ),
              ],
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Erreur de rendu',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$e',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadLocations,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
  }
}
