import 'package:flutter/material.dart';

import 'admin/admin_components.dart';
import 'admin/admin_tokens.dart';
import 'admin/location_queue_filter.dart';
import 'api_service.dart';
import 'equipment_request_image.dart';
import 'service_image_thumbnail.dart';

typedef AdminLocationsLoader = Future<List<Map<String, dynamic>>> Function();
typedef LocationDecision = Future<Object?> Function(int locationId);
typedef LocationRejecter =
    Future<Object?> Function(int locationId, String reason);
typedef LocationDeleter = Future<void> Function(int locationId);
typedef AdminClock = DateTime Function();

class LocationPage extends StatefulWidget {
  const LocationPage({
    super.key,
    this.loadLocations = ApiService.getAdminLocations,
    this.approveLocation = ApiService.approveLocation,
    this.rejectLocation = ApiService.rejectLocation,
    this.terminateLocation = ApiService.terminateLocation,
    this.markLocationOverdue = ApiService.markLocationOverdue,
    this.deleteLocation = ApiService.deleteLocation,
    this.today = DateTime.now,
  });

  final AdminLocationsLoader loadLocations;
  final LocationDecision approveLocation;
  final LocationRejecter rejectLocation;
  final LocationDecision terminateLocation;
  final LocationDecision markLocationOverdue;
  final LocationDeleter deleteLocation;
  final AdminClock today;

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  List<Map<String, dynamic>> _locations = [];
  final Set<int> _busyLocationIds = <int>{};
  final ScrollController _locationsScrollController = ScrollController();
  bool _isLoading = true;
  bool _hasLoadedLocations = false;
  String? _errorMessage;
  LocationQueueFilter _filter = LocationQueueFilter.pending;
  bool _isLoadingLocations = false;

  @override
  void initState() {
    super.initState();
    print('📱 LocationPage ADMIN - initState()');
    _loadLocations();
  }

  @override
  void dispose() {
    _locationsScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    if (_isLoadingLocations) {
      print('⏳ _loadLocations ignoré (déjà en cours)');
      return;
    }
    _isLoadingLocations = true;
    print('🔄 _loadLocations démarré');

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final locations = await widget.loadLocations().timeout(
        const Duration(seconds: 15),
      );
      final previousPendingKeys = _locations
          .where(
            (location) =>
                locationQueueBucketKey(location['statut']) ==
                LocationQueueFilter.pending.key,
          )
          .map(_locationIdentityKey)
          .whereType<String>()
          .toSet();
      final newPendingLocations = _hasLoadedLocations
          ? locations
                .where((location) {
                  final identityKey = _locationIdentityKey(location);
                  return identityKey != null &&
                      locationQueueBucketKey(location['statut']) ==
                          LocationQueueFilter.pending.key &&
                      !previousPendingKeys.contains(identityKey);
                })
                .toList(growable: false)
          : const <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _locations = locations;
        _isLoading = false;
        _errorMessage = null;
        if (newPendingLocations.isNotEmpty) {
          _filter = LocationQueueFilter.pending;
        }
      });
      _hasLoadedLocations = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_locationsScrollController.hasClients) {
          _locationsScrollController.jumpTo(0);
        }
        if (newPendingLocations.isEmpty) return;

        final count = newPendingLocations.length;
        showAdminMessage(
          context,
          count == 1
              ? 'Nouvelle réservation reçue : elle est en haut de la file « En attente ». '
              : '$count nouvelles réservations reçues : elles sont en haut de la file « En attente ».',
          backgroundColor: AdminPalette.approvalGreen,
        );
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

  List<Map<String, dynamic>> get _visibleLocations =>
      filterLocationsForQueue(_locations, _filter);

  int _countFor(LocationQueueFilter filter) =>
      countLocationsForQueue(_locations, filter);

  Future<void> _approveLocation(int locationId) async {
    if (!_startMutation(locationId)) return;

    try {
      await widget.approveLocation(locationId);
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
      await widget.rejectLocation(locationId, reason);
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

  Future<void> _markLocationOverdue(int locationId) async {
    if (!_startMutation(locationId)) return;

    try {
      await widget.markLocationOverdue(locationId);
      if (!mounted) return;
      showAdminMessage(
        context,
        'Location #$locationId marquée en retard. L’appareil reste bloqué jusqu’à confirmation du retour.',
        backgroundColor: AdminPalette.safetyAmber,
      );
      await _loadLocations();
    } catch (error) {
      if (mounted) {
        showAdminMessage(
          context,
          'Impossible de marquer la location en retard : $error',
          backgroundColor: AdminPalette.destructiveRed,
        );
      }
    } finally {
      _finishMutation(locationId);
    }
  }

  bool _isPastDue(Object? rawDate) {
    final raw = rawDate?.toString();
    if (raw == null || raw.isEmpty) return false;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return false;
    final dueDay = DateUtils.dateOnly(parsed.toLocal());
    final today = DateUtils.dateOnly(widget.today());
    return dueDay.isBefore(today);
  }

  Future<void> _completeLocation(int locationId) async {
    if (_busyLocationIds.contains(locationId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmer le retour physique ?'),
        content: Text(
          'Confirme que l’appareil de la location #$locationId a bien été rendu. Cette action terminera la location et libérera son créneau.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Pas encore'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AdminPalette.approvalGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmer le retour'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true || !_startMutation(locationId)) return;

    try {
      await widget.terminateLocation(locationId);
      if (mounted) {
        showAdminMessage(
          context,
          'Location #$locationId terminée.',
          backgroundColor: AdminPalette.approvalGreen,
        );
        await _loadLocations();
      }
    } catch (error) {
      if (mounted) {
        showAdminMessage(
          context,
          'Impossible de terminer la location : $error',
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
        title: const Text('Supprimer cette location ?'),
        content: Text(
          'La location #$locationId sera supprimée définitivement de l’historique.',
        ),
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
      await widget.deleteLocation(locationId);
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
    final equipmentName = _display(
      location['appareilNom'],
      fallback: 'appareil',
    );
    return ServiceImageThumbnail(
      key: ValueKey('admin-location-image-${_locationIdentityKey(location)}'),
      imageUrl: resolveEquipmentRequestImageUrl(location),
      semanticLabel: 'Image de $equipmentName',
      width: 50,
      height: 50,
      borderRadius: AdminRadii.field,
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

  int? _parseLocationId(Map<String, dynamic> location) {
    final rawId =
        location['id'] ?? location['locationId'] ?? location['location_id'];
    if (rawId is num) return rawId.toInt();
    return int.tryParse(rawId?.toString().trim() ?? '');
  }

  String? _locationIdentityKey(Map<String, dynamic> location) {
    final locationId = _parseLocationId(location);
    if (locationId != null) return 'id:$locationId';

    final code = _display(location['code']);
    if (code.isNotEmpty) return 'code:$code';

    return null;
  }

  Key _locationItemKey(Map<String, dynamic> location, int index) {
    final locationId = _parseLocationId(location);
    return ValueKey<String>(
      locationId == null
          ? 'loc_${_display(location['code'], fallback: 'unknown_$index')}'
          : 'loc_$locationId',
    );
  }

  Widget _buildLocationItem(Map<String, dynamic> location, int index) {
    try {
      final locationId = _parseLocationId(location);
      final locationCode = _display(
        location['code'],
        fallback: 'Demande sans référence',
      );

      // Debug: afficher le type et la valeur de l'ID
      print(
        '🔍 location[id] type: ${location['id'].runtimeType}, value: ${location['id']}, parsed: $locationId',
      );

      if (locationId == null) {
        print('⚠️ Location ID invalide à l\'index $index: ${location['id']}');
      }

      final amount = formatAdminAmount(location['montantTotal']);
      final equipment = _display(
        location['appareilNom'],
        fallback: 'Appareil non renseigné',
      );
      final client = _display(
        location['clientNom'],
        fallback: 'Client non renseigné',
      );
      final isTerminal = isLocationStatusDeletable(location['statut']);
      final isBusy = _busyLocationIds.contains(locationId);

      Widget footer;
      if (locationId == null) {
        footer = const Text(
          'Actions indisponibles : identifiant de réservation manquant.',
          style: TextStyle(
            color: AdminPalette.destructiveRed,
            fontWeight: FontWeight.w600,
          ),
        );
      } else if (isAdminPending(location['statut'])) {
        footer = AdminDecisionBar(
          isBusy: isBusy,
          onApprove: () => _approveLocation(locationId),
          onReject: () => _rejectLocation(locationId),
        );
      } else if (isTerminal) {
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
      } else if (locationQueueBucketKey(location['statut']) ==
          LocationQueueFilter.inProgress.key) {
        final statusKey = adminStatusKey(location['statut']);
        footer = Wrap(
          alignment: WrapAlignment.end,
          spacing: AdminSpacing.sm,
          runSpacing: AdminSpacing.xs,
          children: [
            TextButton.icon(
              onPressed: () => _showLocationDetails(location),
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('Détail'),
              style: TextButton.styleFrom(
                foregroundColor: AdminPalette.blueprintBlue,
              ),
            ),
            if (statusKey == 'en_cours' && _isPastDue(location['dateFin']))
              OutlinedButton.icon(
                onPressed: isBusy
                    ? null
                    : () => _markLocationOverdue(locationId),
                icon: const Icon(Icons.schedule, size: 18),
                label: const Text('Marquer en retard'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminPalette.safetyAmber,
                  side: const BorderSide(color: AdminPalette.safetyAmber),
                  minimumSize: const Size(0, 44),
                ),
              ),
            OutlinedButton.icon(
              onPressed: isBusy ? null : () => _completeLocation(locationId),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Confirmer le retour'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AdminPalette.approvalGreen,
                side: const BorderSide(color: AdminPalette.approvalGreen),
                minimumSize: const Size(0, 44),
              ),
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
            style: TextButton.styleFrom(
              foregroundColor: AdminPalette.blueprintBlue,
            ),
          ),
        );
      }

      final locationReference = locationId == null
          ? locationCode
          : 'Location #$locationId';

      print('🏗️ Construction AdminWorkItemCard pour $locationReference');
      return AdminWorkItemCard(
        key: _locationItemKey(location, index),
        status: location['statut'],
        reference: locationReference,
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
      print(
        '❌ Erreur build item index=$index locationId=${location['id']}: $e',
      );
      print('📋 Stack: $stack');
      // Widget d'erreur visible pour debug
      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Erreur item #${location['id']}: $e',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
  }

  void _showLocationDetails(Map<String, dynamic> location) {
    final locationId = _display(
      location['id'] ?? location['locationId'] ?? location['location_id'],
      fallback: _display(location['code'], fallback: 'inconnue'),
    );
    final equipment = _display(
      location['appareilNom'],
      fallback: 'Appareil non renseigné',
    );
    final client = _display(
      location['clientNom'],
      fallback: 'Client non renseigné',
    );
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
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AdminRadii.sheet),
          ),
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
              _buildDetailRow(
                'Montant',
                formatAdminAmount(location['montantTotal']),
              ),
              const SizedBox(height: AdminSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
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
            child: Text(
              label,
              style: const TextStyle(color: AdminPalette.secondaryText),
            ),
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
    print(
      '🏗️ build() appelé - filter=$_filter isLoading=$_isLoading locations=${_locations.length}',
    );
    print('🏗️ build() errorMessage=$_errorMessage mounted=$mounted');
    try {
      final visibleLocations = _visibleLocations;
      print('🏗️ visibleLocations.length=${visibleLocations.length}');

      // ---- Header widgets (commun à tous les états) ----
      final header = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AdminPageHeader(
            title: 'Locations',
            subtitle:
                'Traitez les réservations d’équipement et suivez leur cycle.',
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
          AdminMetricCluster(
            primary: AdminMetric(
              label: 'Réservations à traiter',
              value: _countFor(LocationQueueFilter.pending),
              icon: Icons.pending_actions_outlined,
            ),
            secondary: [
              AdminMetric(
                label: 'Locations en cours',
                value: _countFor(LocationQueueFilter.inProgress),
                icon: Icons.play_circle_outline,
              ),
              AdminMetric(
                label: 'Locations terminées',
                value: _countFor(LocationQueueFilter.completed),
                icon: Icons.check_circle_outline,
              ),
              AdminMetric(
                label: 'Historique rejeté',
                value: _countFor(LocationQueueFilter.history),
                icon: Icons.history_outlined,
              ),
            ],
          ),
          AdminSegmentedFilter(
            selectedValue: _filter.key,
            onChanged: (key) {
              final selected = LocationQueueFilter.values.firstWhere(
                (filter) => filter.key == key,
              );
              setState(() => _filter = selected);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_locationsScrollController.hasClients) {
                  _locationsScrollController.jumpTo(0);
                }
              });
            },
            options: [
              for (final filter in LocationQueueFilter.values)
                AdminFilterOption(
                  value: filter.key,
                  label: filter.label,
                  count: _countFor(filter),
                ),
            ],
          ),
        ],
      );

      // ---- États sans données ----
      print(
        '🏗️ Branche: isLoading=$_isLoading locationsEmpty=${_locations.isEmpty}',
      );
      if (_isLoading && _locations.isEmpty) {
        return Column(
          children: [
            header,
            const Expanded(
              child: AdminLoadingState(label: 'Chargement des locations…'),
            ),
          ],
        );
      }
      if (_errorMessage != null && _locations.isEmpty) {
        return Column(
          children: [
            header,
            Expanded(
              child: AdminErrorState(
                message: _errorMessage!,
                onRetry: _loadLocations,
              ),
            ),
          ],
        );
      }
      if (visibleLocations.isEmpty) {
        return Column(
          children: [
            header,
            Expanded(
              child: AdminEmptyState(
                icon: _filter == LocationQueueFilter.history
                    ? Icons.history_outlined
                    : Icons.inbox_outlined,
                title: switch (_filter) {
                  LocationQueueFilter.pending => 'Aucune location en attente',
                  LocationQueueFilter.inProgress => 'Aucune location en cours',
                  LocationQueueFilter.completed => 'Aucune location terminée',
                  LocationQueueFilter.history =>
                    'Aucun historique de demandes rejetées ou annulées',
                  LocationQueueFilter.all => 'Aucune location enregistrée',
                },
                message: _filter == LocationQueueFilter.pending
                    ? 'Les nouvelles réservations apparaîtront ici.'
                    : 'Changez d’onglet ou actualisez la file.',
              ),
            ),
          ],
        );
      }

      // ---- Cas normal : données présentes → ListView classique (0 sliver) ----
      print(
        '🏗️ Branche: NORMALE - rendu de ${visibleLocations.length} locations',
      );
      return Column(
        children: [
          header,
          Expanded(
            child: ListView.builder(
              controller: _locationsScrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              findChildIndexCallback: (key) {
                for (var index = 0; index < visibleLocations.length; index++) {
                  if (_locationItemKey(visibleLocations[index], index) == key) {
                    return index;
                  }
                }
                return null;
              },
              padding: const EdgeInsets.fromLTRB(
                AdminSpacing.lg,
                AdminSpacing.sm,
                AdminSpacing.lg,
                AdminSpacing.section,
              ),
              itemCount: visibleLocations.length,
              itemBuilder: (context, index) =>
                  _buildLocationItem(visibleLocations[index], index),
            ),
          ),
        ],
      );
    } catch (e, stack) {
      print('❌❌❌ CRASH dans build(): $e');
      print('📋 Stack: $stack');
      return Center(
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
      );
    }
  }
}
