import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_service.dart';
import 'client_mes_demandes.dart';
import 'client_mes_devis.dart';
import 'equipment_request_image.dart';
import 'history_purchase_status.dart';
import 'location.dart';
import 'location_status.dart';
import 'service.dart';
import 'service_image_thumbnail.dart';

/// A row in the user's rental or purchase history.
///
/// [status] is normalized per record type. Purchase values deliberately remain
/// separate from rental statuses (for example, `livree` is not `termine`).
class Transaction {
  const Transaction({
    required this.id,
    required this.type,
    required this.title,
    required this.date,
    required this.status,
    this.dateRetour,
    this.amount,
    this.quantity,
    this.unitPrice,
    this.invoiceNumber,
    this.adminComment,
    this.imageUrl,
  });

  final int id;
  final String type;
  final String title;
  final String date;
  final String? dateRetour;
  final String status;
  final int? amount;
  final int? quantity;
  final int? unitPrice;
  final String? invoiceNumber;
  final String? adminComment;
  final String? imageUrl;

  bool get isLocation => type == 'location';
}

typedef HistoriqueDataLoader = Future<List<Map<String, dynamic>>> Function();

enum _HistorySection { locations, achats }

class _HistoryFilter {
  const _HistoryFilter(this.key, this.label);

  final String key;
  final String label;
}

class _HistoryColors {
  static const canvas = Color(0xFFF5F5F7);
  static const surface = Colors.white;
  static const primary = Color(0xFF0066CC);
  static const ink = Color(0xFF1D1D1F);
  static const body = Color(0xFF333333);
  static const muted = Color(0xFF4A4A4F);
  static const border = Color(0xFFE0E0E0);
  static const softDivider = Color(0xFFF0F0F0);
  static const alert = Color(0xFFB42318);
  static const alertSurface = Color(0xFFFDF1EF);
  static const activeSurface = Color(0xFFEAF2FC);
}

class HistoriqueScreen extends StatefulWidget {
  const HistoriqueScreen({
    super.key,
    this.loadLocations,
    this.loadPurchases,
    this.refreshInterval = const Duration(seconds: 30),
  });

  final HistoriqueDataLoader? loadLocations;
  final HistoriqueDataLoader? loadPurchases;
  final Duration? refreshInterval;

  @override
  State<HistoriqueScreen> createState() => _HistoriqueScreenState();
}

class _HistoriqueScreenState extends State<HistoriqueScreen>
    with WidgetsBindingObserver {
  static const _locationFilters = <_HistoryFilter>[
    _HistoryFilter('all', 'Toutes'),
    _HistoryFilter('en-attente', 'En attente'),
    _HistoryFilter('approuvee', 'Approuvées'),
    _HistoryFilter('en-cours', 'En cours'),
    _HistoryFilter('a-verifier', 'À vérifier'),
    _HistoryFilter('termine', 'Terminées'),
    _HistoryFilter('refusee', 'Refusées / annulées'),
  ];

  static const _purchaseFilters = <_HistoryFilter>[
    _HistoryFilter('all', 'Toutes'),
    _HistoryFilter('en_attente', 'En attente'),
    _HistoryFilter('approuvee', 'Approuvées'),
    _HistoryFilter('livree', 'Livrées'),
    _HistoryFilter('termine', 'Terminées'),
    _HistoryFilter('rejetee', 'Refusées'),
  ];

  _HistorySection _section = _HistorySection.locations;
  String _locationFilter = 'all';
  String _purchaseFilter = 'all';
  bool _isLoadingLocations = true;
  bool _isLoadingPurchases = true;
  bool _isFetchingLocations = false;
  bool _isFetchingPurchases = false;
  String? _locationsErrorMessage;
  String? _purchasesErrorMessage;
  Timer? _statusRefreshTimer;
  List<Transaction> _locationTransactions = [];
  List<Transaction> _purchaseTransactions = [];

  bool get _isFetching => _isFetchingLocations || _isFetchingPurchases;
  bool get _activeIsLoading => _section == _HistorySection.locations
      ? _isLoadingLocations
      : _isLoadingPurchases;
  bool get _activeIsFetching => _section == _HistorySection.locations
      ? _isFetchingLocations
      : _isFetchingPurchases;
  String? get _activeErrorMessage => _section == _HistorySection.locations
      ? _locationsErrorMessage
      : _purchasesErrorMessage;

  List<Transaction> get _allTransactions => [
    ..._locationTransactions,
    ..._purchaseTransactions,
  ];

  String get _activeFilter =>
      _section == _HistorySection.locations ? _locationFilter : _purchaseFilter;

  List<_HistoryFilter> get _activeFilters =>
      _section == _HistorySection.locations
      ? _locationFilters
      : _purchaseFilters;

  List<Transaction> get _sectionTransactions =>
      _section == _HistorySection.locations
      ? _locationTransactions
      : _purchaseTransactions;

  List<Transaction> get _visibleTransactions => _sectionTransactions
      .where((transaction) => _matchesFilter(transaction, _activeFilter))
      .toList(growable: false);

  List<Transaction> get _locationsToVerify => _locationTransactions
      .where(_needsReturnVerification)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshAllTransactions());
    _startStatusRefreshTimer();
  }

  void _startStatusRefreshTimer() {
    final interval = widget.refreshInterval;
    if (interval == null || interval.inMicroseconds <= 0) return;

    _statusRefreshTimer?.cancel();
    _statusRefreshTimer = Timer.periodic(interval, (_) {
      unawaited(_refreshAllTransactions(silent: true));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshAllTransactions(silent: true));
      _startStatusRefreshTimer();
    } else {
      _statusRefreshTimer?.cancel();
      _statusRefreshTimer = null;
    }
  }

  Future<void> _refreshAllTransactions({bool silent = false}) async {
    await Future.wait<void>([
      _loadLocations(silent: silent),
      _loadPurchases(silent: silent),
    ]);
  }

  Future<void> _loadLocations({bool silent = false}) async {
    if (_isFetchingLocations || !mounted) return;
    _isFetchingLocations = true;

    if (!silent) {
      setState(() {
        _isLoadingLocations = _locationTransactions.isEmpty;
        _locationsErrorMessage = null;
      });
    }

    try {
      final loadLocations = widget.loadLocations ?? ApiService.getLocations;
      final locations = await loadLocations();
      final transactions = locations
          .map(
            (location) => Transaction(
              id: _asInt(location['id']) ?? 0,
              type: 'location',
              title: _stringValue(
                location['appareilNom'],
                fallback: 'Appareil',
              ),
              date: _stringValue(location['dateDebut']),
              dateRetour: _nullableString(location['dateFin']),
              amount: _asInt(location['montantTotal']),
              status: normalizeLocationStatus(location['statut']),
              invoiceNumber: _nullableString(location['code']),
              adminComment: _nullableString(location['commentaireAdmin']),
              imageUrl: resolveEquipmentRequestImageUrl(location),
            ),
          )
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _locationTransactions = transactions;
        _isLoadingLocations = false;
        _locationsErrorMessage = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoadingLocations = false;
          // Keep stale data visible while reporting this section's error.
          _locationsErrorMessage = _messageForHistoryError(error);
        });
      }
      debugPrint('Erreur chargement locations historique: $error');
    } finally {
      _isFetchingLocations = false;
      if (mounted && !silent) setState(() {});
    }
  }

  Future<void> _loadPurchases({bool silent = false}) async {
    if (_isFetchingPurchases || !mounted) return;
    _isFetchingPurchases = true;

    if (!silent) {
      setState(() {
        _isLoadingPurchases = _purchaseTransactions.isEmpty;
        _purchasesErrorMessage = null;
      });
    }

    try {
      final loadPurchases = widget.loadPurchases ?? ApiService.getDemandesAchat;
      final purchases = await loadPurchases();
      final transactions = purchases
          .map(
            (demande) => Transaction(
              id: _asInt(demande['id']) ?? 0,
              type: 'achat',
              title: _stringValue(demande['appareilNom'], fallback: 'Appareil'),
              date: _stringValue(demande['createdAt']),
              amount: _asInt(demande['total']),
              quantity: _asInt(demande['quantite']),
              unitPrice: _asInt(demande['appareilPrix']),
              status: normalizePurchaseStatus(demande['statut']),
              invoiceNumber: _nullableString(demande['code']),
              adminComment: _nullableString(demande['commentaireAdmin']),
              imageUrl: resolveEquipmentRequestImageUrl(demande),
            ),
          )
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _purchaseTransactions = transactions;
        _isLoadingPurchases = false;
        _purchasesErrorMessage = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoadingPurchases = false;
          // Keep stale data visible while reporting this section's error.
          _purchasesErrorMessage = _messageForHistoryError(error);
        });
      }
      debugPrint('Erreur chargement achats historique: $error');
    } finally {
      _isFetchingPurchases = false;
      if (mounted && !silent) setState(() {});
    }
  }

  String _messageForHistoryError(Object error) {
    final errorText = error.toString().toLowerCase();
    if (errorText.contains('not authenticated') ||
        errorText.contains('session') ||
        errorText.contains('token')) {
      return 'Session expirée ou invalide. Veuillez vous reconnecter.';
    }
    if (errorText.contains('socketexception') ||
        errorText.contains('connection') ||
        errorText.contains('network')) {
      return 'Connexion internet impossible. Vérifiez votre connexion.';
    }
    if (errorText.contains('500') || errorText.contains('serveur')) {
      return 'Serveur temporairement indisponible. Réessayez plus tard.';
    }
    return 'Une erreur est survenue. Veuillez réessayer.';
  }

  bool _matchesFilter(Transaction transaction, String filter) {
    if (filter == 'all') return true;

    if (transaction.isLocation) {
      switch (filter) {
        case 'en-attente':
        case 'approuvee':
        case 'termine':
          return transaction.status == filter;
        case 'en-cours':
          return transaction.status == 'en-cours' &&
              !_needsReturnVerification(transaction);
        case 'a-verifier':
          return _needsReturnVerification(transaction);
        case 'refusee':
          return transaction.status == 'rejetee' ||
              transaction.status == 'annulee';
      }
    } else {
      return transaction.status == filter;
    }

    return false;
  }

  bool _needsReturnVerification(Transaction transaction) {
    if (!transaction.isLocation) return false;
    if (transaction.status == 'en-retard') return true;
    if (transaction.status != 'en-cours' || transaction.dateRetour == null) {
      return false;
    }

    final returnDate = _parseCalendarDate(transaction.dateRetour!);
    if (returnDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return returnDate.isBefore(today);
  }

  String _statusLabel(Transaction transaction) {
    if (_needsReturnVerification(transaction)) return 'À vérifier';

    if (transaction.isLocation) {
      switch (transaction.status) {
        case 'en-attente':
          return 'En attente';
        case 'approuvee':
          return 'Approuvée';
        case 'en-cours':
          return 'En cours';
        case 'termine':
          return 'Terminée';
        case 'rejetee':
          return 'Refusée';
        case 'annulee':
          return 'Annulée';
        default:
          return 'Statut inconnu';
      }
    }

    switch (transaction.status) {
      case 'en_attente':
        return 'En attente';
      case 'approuvee':
        return 'Approuvée';
      case 'rejetee':
        return 'Refusée';
      case 'livree':
        return 'Livrée';
      case 'termine':
        return 'Terminée';
      default:
        return 'Statut inconnu';
    }
  }

  _StatusAppearance _statusAppearance(Transaction transaction) {
    if (_needsReturnVerification(transaction)) {
      return const _StatusAppearance(
        foreground: _HistoryColors.alert,
        background: _HistoryColors.alertSurface,
        icon: Icons.info_outline,
      );
    }
    if (transaction.status == 'en-cours') {
      return const _StatusAppearance(
        foreground: _HistoryColors.primary,
        background: _HistoryColors.activeSurface,
        icon: Icons.circle,
      );
    }
    if (transaction.status == 'approuvee') {
      return const _StatusAppearance(
        foreground: _HistoryColors.primary,
        background: _HistoryColors.activeSurface,
        icon: Icons.check_circle_outline,
      );
    }
    if (transaction.status == 'en-attente' ||
        transaction.status == 'en_attente') {
      return const _StatusAppearance(
        foreground: _HistoryColors.body,
        background: _HistoryColors.canvas,
        icon: Icons.schedule,
      );
    }
    if (transaction.status == 'rejetee') {
      return const _StatusAppearance(
        foreground: _HistoryColors.body,
        background: _HistoryColors.canvas,
        icon: Icons.info_outline,
      );
    }
    if (transaction.status == 'livree' || transaction.status == 'termine') {
      return const _StatusAppearance(
        foreground: _HistoryColors.body,
        background: _HistoryColors.canvas,
        icon: Icons.check_circle_outline,
      );
    }
    return const _StatusAppearance(
      foreground: _HistoryColors.muted,
      background: _HistoryColors.canvas,
      icon: Icons.help_outline,
    );
  }

  void _selectSection(_HistorySection section) {
    if (_section == section) return;
    setState(() => _section = section);
  }

  void _selectFilter(String filter) {
    setState(() {
      if (_section == _HistorySection.locations) {
        _locationFilter = filter;
      } else {
        _purchaseFilter = filter;
      }
    });
  }

  Future<void> _retryActiveSection() => _section == _HistorySection.locations
      ? _loadLocations()
      : _loadPurchases();

  @override
  void dispose() {
    _statusRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLocations = _section == _HistorySection.locations;
    final sectionRecords = _sectionTransactions;
    final visibleRecords = _visibleTransactions;
    final locationsToVerify = _locationsToVerify;

    return Scaffold(
      backgroundColor: _HistoryColors.canvas,
      appBar: AppBar(
        backgroundColor: _HistoryColors.surface,
        surfaceTintColor: _HistoryColors.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Historique',
              style: TextStyle(
                color: _HistoryColors.ink,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Suivi de vos locations et achats',
              style: TextStyle(
                color: _HistoryColors.body,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _isFetching ? null : _refreshAllTransactions,
            icon: _isFetching
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _HistoryColors.primary,
                    ),
                  )
                : const Icon(Icons.refresh, color: _HistoryColors.primary),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: _HistoryColors.primary,
        onRefresh: _refreshAllTransactions,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 20),
          children: [
            _buildQuickLinks(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isLocations && locationsToVerify.isNotEmpty) ...[
                    _buildReturnAlert(locationsToVerify),
                    const SizedBox(height: 12),
                  ],
                  _buildSectionControl(),
                  const SizedBox(height: 14),
                  _buildSectionSummary(sectionRecords.length, isLocations),
                  const SizedBox(height: 8),
                  _buildFilterRail(),
                  const SizedBox(height: 8),
                  if (sectionRecords.isNotEmpty &&
                      _activeErrorMessage != null) ...[
                    _buildRefreshErrorBanner(),
                    const SizedBox(height: 8),
                  ],
                  if (_activeIsLoading)
                    _buildLoadingState()
                  else if (_activeErrorMessage != null &&
                      sectionRecords.isEmpty)
                    _buildErrorState()
                  else if (visibleRecords.isEmpty)
                    _buildEmptyState(sectionRecords.isEmpty)
                  else
                    ...visibleRecords.map(_buildTransactionRow),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickLinks(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: _HistoryColors.surface,
        border: Border(bottom: BorderSide(color: _HistoryColors.softDivider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ClientMesDemandesPage(),
                  ),
                );
              },
              icon: const Icon(Icons.shopping_bag_outlined, size: 18),
              label: const Text('Mes demandes'),
              style: TextButton.styleFrom(
                foregroundColor: _HistoryColors.primary,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ),
          const SizedBox(
            height: 24,
            child: VerticalDivider(width: 1, color: _HistoryColors.border),
          ),
          Expanded(
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ClientMesDevisPage(
                      serviceImageResolver: ServiceScreen.imageUrlForId,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.description_outlined, size: 18),
              label: const Text('Mes devis'),
              style: TextButton.styleFrom(
                foregroundColor: _HistoryColors.primary,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnAlert(List<Transaction> locations) {
    final firstLocation = locations.first;
    final returnDate = _formatDate(firstLocation.dateRetour);
    final countLabel = locations.length == 1
        ? '1 location à vérifier'
        : '${locations.length} locations à vérifier';
    final detail = returnDate.isEmpty
        ? firstLocation.title
        : '${firstLocation.title} · retour prévu le $returnDate';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      decoration: BoxDecoration(
        color: _HistoryColors.alertSurface,
        borderRadius: BorderRadius.circular(11),
        border: const Border(
          left: BorderSide(color: _HistoryColors.alert, width: 4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, size: 22, color: _HistoryColors.alert),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locations.length == 1 ? 'Retour à vérifier' : countLabel,
                  style: const TextStyle(
                    color: _HistoryColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _HistoryColors.body,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Date dépassée · à confirmer avec EG39',
                  style: TextStyle(
                    color: _HistoryColors.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: () => _showTransactionDetails(firstLocation),
            style: TextButton.styleFrom(
              foregroundColor: _HistoryColors.primary,
              minimumSize: const Size(48, 44),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text(
              'Vérifier\nle retour',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionControl() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<_HistorySection>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment<_HistorySection>(
            value: _HistorySection.locations,
            label: Text('Locations'),
          ),
          ButtonSegment<_HistorySection>(
            value: _HistorySection.achats,
            label: Text('Achats'),
          ),
        ],
        selected: {_section},
        onSelectionChanged: (selection) => _selectSection(selection.first),
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(46)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 8),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.white
                : _HistoryColors.body,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? _HistoryColors.primary
                : _HistoryColors.surface,
          ),
          textStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 14,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w600,
            ),
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: _HistoryColors.border),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionSummary(int count, bool isLocations) {
    final noun = isLocations
        ? (count == 1 ? 'location' : 'locations')
        : (count == 1 ? 'demande d’achat' : 'demandes d’achat');
    return Row(
      children: [
        Expanded(
          child: Text(
            '$count $noun',
            style: const TextStyle(
              color: _HistoryColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          isLocations ? 'Échéances de retour' : 'Suivi par quantité',
          style: const TextStyle(
            color: _HistoryColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterRail() {
    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final filter in _activeFilters)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: ValueKey(
                    'history-filter-${_section.name}-${filter.key}',
                  ),
                  label: Text(filter.label),
                  selected: _activeFilter == filter.key,
                  onSelected: (_) => _selectFilter(filter.key),
                  showCheckmark: false,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  backgroundColor: _HistoryColors.surface,
                  selectedColor: _HistoryColors.primary,
                  side: BorderSide(
                    color: _activeFilter == filter.key
                        ? _HistoryColors.primary
                        : _HistoryColors.border,
                  ),
                  labelStyle: TextStyle(
                    color: _activeFilter == filter.key
                        ? Colors.white
                        : _HistoryColors.body,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionRow(Transaction transaction) {
    final status = _statusAppearance(transaction);
    final dateLine = transaction.isLocation
        ? _formatRentalPeriod(transaction.date, transaction.dateRetour)
        : 'Demande créée le ${_formatDate(transaction.date)}';
    final code = _stringValue(transaction.invoiceNumber);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey(
          'history-transaction-row-${transaction.type}-${transaction.id}',
        ),
        onTap: () => _showTransactionDetails(transaction),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _HistoryColors.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ServiceImageThumbnail(
                key: ValueKey(
                  'history-transaction-image-${transaction.type}-${transaction.id}',
                ),
                imageUrl: transaction.imageUrl,
                semanticLabel: 'Photo de référence pour ${transaction.title}',
                width: 64,
                height: 64,
                borderRadius: 8,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            transaction.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _HistoryColors.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildStatusBadge(transaction, status),
                      ],
                    ),
                    const SizedBox(height: 5),
                    if (transaction.isLocation)
                      _MetadataLine(
                        icon: Icons.calendar_today_outlined,
                        text: dateLine,
                      )
                    else ...[
                      _MetadataLine(
                        icon: Icons.inventory_2_outlined,
                        text:
                            'Quantité demandée : '
                            '${transaction.quantity?.toString() ?? 'Non transmise'}',
                      ),
                      const SizedBox(height: 3),
                      _MetadataLine(
                        icon: Icons.calendar_today_outlined,
                        text: dateLine,
                      ),
                    ],
                    if (transaction.amount != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${transaction.isLocation ? 'Montant du dossier' : 'Total de la demande'} · '
                        '${_formatAmount(transaction.amount!)} FCFA',
                        style: const TextStyle(
                          color: _HistoryColors.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (code.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Dossier $code',
                        style: const TextStyle(
                          color: _HistoryColors.muted,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(
    Transaction transaction,
    _StatusAppearance appearance,
  ) {
    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: appearance.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(appearance.icon, size: 14, color: appearance.foreground),
          const SizedBox(width: 4),
          Text(
            _statusLabel(transaction),
            style: TextStyle(
              color: appearance.foreground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Semantics(
      label: 'Chargement de l’historique',
      liveRegion: true,
      child: Column(
        children: [
          for (var index = 0; index < 2; index++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: _HistoryColors.border),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E5E8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonLine(widthFactor: 0.72),
                        SizedBox(height: 10),
                        _SkeletonLine(widthFactor: 0.48),
                        SizedBox(height: 8),
                        _SkeletonLine(widthFactor: 0.6),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRefreshErrorBanner() {
    final isLocations = _section == _HistorySection.locations;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _HistoryColors.surface,
          border: Border.all(color: _HistoryColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 18,
              color: _HistoryColors.muted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLocations
                        ? 'Actualisation des locations impossible'
                        : 'Actualisation des achats impossible',
                    style: const TextStyle(
                      color: _HistoryColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _activeErrorMessage ?? '',
                    style: const TextStyle(
                      color: _HistoryColors.muted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _activeIsFetching ? null : _retryActiveSection,
              style: TextButton.styleFrom(
                foregroundColor: _HistoryColors.primary,
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final isLocations = _section == _HistorySection.locations;
    return _StateMessage(
      icon: Icons.cloud_off_outlined,
      title: isLocations ? 'Locations indisponibles' : 'Achats indisponibles',
      message: _activeErrorMessage ?? 'Une erreur est survenue. Réessayez.',
      actionLabel: 'Réessayer',
      onAction: _activeIsFetching ? null : _retryActiveSection,
    );
  }

  Widget _buildEmptyState(bool sectionIsEmpty) {
    final hasNoHistory = _allTransactions.isEmpty;
    if (!sectionIsEmpty) {
      return _StateMessage(
        icon: Icons.filter_alt_off_outlined,
        title: 'Aucun dossier dans ce filtre',
        message: 'Aucun dossier ne correspond à « ${_activeFilterLabel()} ».',
        actionLabel: 'Effacer le filtre',
        onAction: () => _selectFilter('all'),
      );
    }

    final isLocations = _section == _HistorySection.locations;
    if (!hasNoHistory) {
      return _StateMessage(
        icon: isLocations
            ? Icons.location_on_outlined
            : Icons.shopping_bag_outlined,
        title: isLocations
            ? 'Aucune location pour le moment'
            : 'Aucun achat pour le moment',
        message: isLocations
            ? 'Vos périodes de location apparaîtront ici après leur enregistrement.'
            : 'Vos demandes d’achat et leurs quantités apparaîtront ici.',
        actionLabel: isLocations ? 'Voir les achats' : 'Voir les locations',
        onAction: () => _selectSection(
          isLocations ? _HistorySection.achats : _HistorySection.locations,
        ),
      );
    }

    return _StateMessage(
      icon: Icons.history,
      title: 'Aucun dossier pour le moment',
      message:
          'Vos locations et demandes d’achat apparaîtront ici après leur création.',
      actionLabel: 'Parcourir les équipements',
      onAction: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => LocationScreen()));
      },
    );
  }

  String _activeFilterLabel() {
    for (final filter in _activeFilters) {
      if (filter.key == _activeFilter) return filter.label;
    }
    return 'ce statut';
  }

  void _showTransactionDetails(Transaction transaction) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierLabel: 'Fermer le détail du dossier',
      builder: (sheetContext) {
        final status = _statusAppearance(transaction);
        final isReviewRequired = _needsReturnVerification(transaction);
        final isRejected = transaction.status == 'rejetee';
        final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;

        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.86,
            ),
            decoration: const BoxDecoration(
              color: _HistoryColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD2D2D7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              transaction.isLocation
                                  ? 'Dossier de location'
                                  : 'Dossier d’achat',
                              style: const TextStyle(
                                color: _HistoryColors.body,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              transaction.title,
                              style: const TextStyle(
                                color: _HistoryColors.ink,
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildStatusBadge(transaction, status),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fermer le détail',
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close),
                        color: _HistoryColors.body,
                        constraints: const BoxConstraints.tightFor(
                          width: 44,
                          height: 44,
                        ),
                      ),
                    ],
                  ),
                  if (isReviewRequired) ...[
                    const SizedBox(height: 14),
                    _DetailNotice(
                      icon: Icons.info_outline,
                      color: _HistoryColors.alert,
                      background: _HistoryColors.alertSurface,
                      text: transaction.status == 'en-retard'
                          ? 'Le dossier est marqué comme nécessitant une vérification. Confirmez la situation avec EG39.'
                          : 'La date de retour indiquée est dépassée. Confirmez la situation avec EG39.',
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: _HistoryColors.softDivider),
                  if (transaction.isLocation) ...[
                    _buildDetailRow(
                      'Période de location',
                      _formatRentalPeriod(
                        transaction.date,
                        transaction.dateRetour,
                      ),
                    ),
                  ] else ...[
                    _buildDetailRow(
                      'Quantité demandée',
                      transaction.quantity?.toString() ?? 'Non transmise',
                    ),
                    _buildDetailRow(
                      'Date de la demande',
                      _formatDate(transaction.date),
                    ),
                    if (transaction.unitPrice != null)
                      _buildDetailRow(
                        'Prix unitaire indiqué',
                        '${_formatAmount(transaction.unitPrice!)} FCFA',
                      ),
                  ],
                  if (transaction.amount != null)
                    _buildDetailRow(
                      transaction.isLocation
                          ? 'Montant du dossier'
                          : 'Total de la demande',
                      '${_formatAmount(transaction.amount!)} FCFA',
                      isEmphasized: true,
                    ),
                  if (_stringValue(transaction.invoiceNumber).isNotEmpty)
                    _buildDetailRow(
                      'Référence du dossier',
                      _stringValue(transaction.invoiceNumber),
                    ),
                  _buildDetailRow(
                    'Statut du paiement',
                    'Non transmis par le service',
                  ),
                  if (isRejected ||
                      _stringValue(transaction.adminComment).isNotEmpty)
                    _buildDetailRow(
                      isRejected ? 'Motif du rejet:' : 'Commentaire d’EG39',
                      _stringValue(
                        transaction.adminComment,
                        fallback: isRejected ? 'Aucun motif transmis' : '',
                      ),
                    ),
                  if (isReviewRequired) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _callEg39,
                        icon: const Icon(Icons.phone_outlined, size: 18),
                        label: const Text('Appeler EG39 · 99001166'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _HistoryColors.primary,
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: _HistoryColors.primary),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Coordonnée déjà enregistrée dans l’application, à confirmer.',
                      style: TextStyle(
                        color: _HistoryColors.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isEmphasized = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _HistoryColors.softDivider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _HistoryColors.body,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: _HistoryColors.ink,
                fontSize: 14,
                fontWeight: isEmphasized ? FontWeight.w700 : FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _callEg39() async {
    final uri = Uri.parse('tel:+22899001166');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de lancer l’appel vers EG39.'),
        ),
      );
    }
  }
}

class _StatusAppearance {
  const _StatusAppearance({
    required this.foreground,
    required this.background,
    required this.icon,
  });

  final Color foreground;
  final Color background;
  final IconData icon;
}

class _MetadataLine extends StatelessWidget {
  const _MetadataLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 14, color: _HistoryColors.muted),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: _HistoryColors.body,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 11,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E5E8),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: _HistoryColors.surface,
        border: Border.all(color: _HistoryColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, color: _HistoryColors.primary, size: 30),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _HistoryColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _HistoryColors.body,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          if (onAction != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _HistoryColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(actionLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailNotice extends StatelessWidget {
  const _DetailNotice({
    required this.icon,
    required this.color,
    required this.background,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

int? _asInt(Object? value) {
  if (value is num) return value.toInt();
  if (value == null) return null;
  return int.tryParse(value.toString());
}

String _stringValue(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _nullableString(Object? value) {
  final text = _stringValue(value);
  return text.isEmpty ? null : text;
}

DateTime? _parseCalendarDate(String rawValue) {
  final value = rawValue.trim();
  if (value.isEmpty) return null;

  // PostgreSQL date fields arrive as yyyy-MM-dd. Parse these as calendar dates
  // rather than UTC midnight so the due day cannot shift with local timezone.
  final dateOnlyMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (dateOnlyMatch != null) {
    final year = int.tryParse(dateOnlyMatch.group(1)!);
    final month = int.tryParse(dateOnlyMatch.group(2)!);
    final day = int.tryParse(dateOnlyMatch.group(3)!);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

String _formatDate(Object? value) {
  final raw = _stringValue(value);
  if (raw.isEmpty) return 'Date non transmise';
  final parsed = _parseCalendarDate(raw);
  if (parsed == null) return raw;

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
  return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
}

String _formatRentalPeriod(String start, String? end) {
  final startValue = _stringValue(start);
  final endValue = _stringValue(end);
  if (startValue.isEmpty && endValue.isEmpty) {
    return 'Dates de location non transmises';
  }
  if (startValue.isEmpty) return 'Retour prévu le ${_formatDate(endValue)}';
  if (endValue.isEmpty) return 'Début le ${_formatDate(startValue)}';
  return '${_formatDate(startValue)} – ${_formatDate(endValue)}';
}

String _formatAmount(int amount) =>
    NumberFormat.decimalPattern('fr_FR').format(amount);
