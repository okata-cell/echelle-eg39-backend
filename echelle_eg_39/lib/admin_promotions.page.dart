import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'admin/admin_components.dart';
import 'admin/admin_tokens.dart';
import 'admin/promotion_editor_dialog.dart';
import 'api_service.dart';
import 'service_image_thumbnail.dart';

typedef PromotionLoader = Future<List<Map<String, dynamic>>> Function();
typedef PromotionImageUploader =
    Future<Map<String, dynamic>> Function(XFile image);
typedef PromotionCreator =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> promotion);
typedef PromotionToggler =
    Future<Map<String, dynamic>> Function(int promotionId, bool activate);
typedef PromotionDeleter = Future<void> Function(int promotionId);
typedef PromotionImageDeleter = Future<void> Function(String storagePath);

class AdminPromotionsPage extends StatefulWidget {
  const AdminPromotionsPage({
    super.key,
    this.loadPromotions,
    this.uploadImage,
    this.pickImage,
    this.createPromotion,
    this.togglePromotion,
    this.deletePromotion,
    this.deletePromotionImage,
  });

  final PromotionLoader? loadPromotions;
  final PromotionImageUploader? uploadImage;
  final PromotionImagePicker? pickImage;
  final PromotionCreator? createPromotion;
  final PromotionToggler? togglePromotion;
  final PromotionDeleter? deletePromotion;
  final PromotionImageDeleter? deletePromotionImage;

  @override
  State<AdminPromotionsPage> createState() => _AdminPromotionsPageState();
}

class _AdminPromotionsPageState extends State<AdminPromotionsPage> {
  List<Map<String, dynamic>> _promotions = [];
  final Set<int> _busyPromotionIds = <int>{};
  bool _isLoading = true;
  String? _errorMessage;
  String _filterStatut = 'tous';

  @override
  void initState() {
    super.initState();
    _loadPromotions();
  }

  Future<void> _loadPromotions() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final loader = widget.loadPromotions ?? ApiService.getPromotions;
      final promotions = await loader();
      if (!mounted) return;
      setState(() {
        _promotions = promotions;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  bool _isInActivePeriod(Map<String, dynamic> promotion, DateTime today) {
    final start = DateTime.tryParse(promotion['date_debut']?.toString() ?? '');
    final end = DateTime.tryParse(promotion['date_fin']?.toString() ?? '');
    if (start == null || end == null) return false;

    final todayOnly = DateTime(today.year, today.month, today.day);
    final startOnly = DateTime(start.year, start.month, start.day);
    final endOnly = DateTime(end.year, end.month, end.day);
    return !todayOnly.isBefore(startOnly) && !todayOnly.isAfter(endOnly);
  }

  bool _matchesFilter(Map<String, dynamic> promotion, String filter) {
    if (filter == 'tous') return true;
    final isActive = promotion['actif'] == true;
    final isInPeriod = _isInActivePeriod(promotion, DateTime.now());
    if (filter == 'actives') return isActive && isInPeriod;
    if (filter == 'inactives') return !isActive || !isInPeriod;
    return true;
  }

  List<Map<String, dynamic>> get _visiblePromotions => _promotions
      .where((promotion) => _matchesFilter(promotion, _filterStatut))
      .toList();

  int _countFor(String filter) => _promotions
      .where((promotion) => _matchesFilter(promotion, filter))
      .length;

  Future<void> _showCreatePromotionDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => PromotionEditorDialog(
        onSubmit: _createPromotion,
        pickImage: widget.pickImage,
      ),
    );

    if (created != true || !mounted) return;
    showAdminMessage(
      context,
      'Promotion créée avec succès.',
      backgroundColor: AdminPalette.approvalGreen,
    );
    await _loadPromotions();
  }

  Future<void> _createPromotion(PromotionDraft draft) async {
    String? imageUrl;
    String? storagePath;

    try {
      if (draft.image != null) {
        final uploader = widget.uploadImage ?? ApiService.uploadPromotionImage;
        final uploaded = await uploader(draft.image!);
        imageUrl = uploaded['imageUrl']?.toString();
        storagePath = uploaded['storagePath']?.toString();
        if (imageUrl == null || storagePath == null) {
          throw Exception('Le serveur n’a pas renvoyé le visuel téléversé.');
        }
      }

      final creator = widget.createPromotion ?? ApiService.createPromotion;
      await creator({
        'titre': 'Offre du moment',
        'description': draft.description,
        'image_url': imageUrl,
        'image_storage_path': storagePath,
        'date_debut': _dateOnly(draft.startDate),
        'date_fin': _dateOnly(draft.endDate),
        'actif': draft.active,
        'frequence': draft.frequency,
      });
    } catch (_) {
      if (storagePath != null) {
        try {
          final removeImage =
              widget.deletePromotionImage ?? ApiService.deletePromotionImage;
          await removeImage(storagePath);
        } catch (cleanupError) {
          debugPrint(
            'Image de promotion à nettoyer manuellement : $cleanupError',
          );
        }
      }
      rethrow;
    }
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> _togglePromotion(int promotionId, bool currentStatus) async {
    if (_busyPromotionIds.contains(promotionId)) return;

    setState(() => _busyPromotionIds.add(promotionId));

    try {
      final toggle = widget.togglePromotion ?? ApiService.togglePromotion;
      await toggle(promotionId, !currentStatus);
      if (mounted) {
        showAdminMessage(
          context,
          currentStatus ? 'Promotion désactivée' : 'Promotion activée',
          backgroundColor: AdminPalette.blueprintBlue,
        );
        await _loadPromotions();
      }
    } catch (error) {
      if (mounted) {
        showAdminMessage(
          context,
          'Erreur: $error',
          backgroundColor: AdminPalette.destructiveRed,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busyPromotionIds.remove(promotionId));
      }
    }
  }

  Future<void> _deletePromotion(int promotionId) async {
    if (_busyPromotionIds.contains(promotionId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer la promotion ?'),
        content: const Text('La promotion sera supprimée définitivement.'),
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

    if (!mounted || confirmed != true) return;

    setState(() => _busyPromotionIds.add(promotionId));

    try {
      final delete = widget.deletePromotion ?? ApiService.deletePromotion;
      await delete(promotionId);
      if (mounted) {
        showAdminMessage(
          context,
          'Promotion supprimée',
          backgroundColor: AdminPalette.destructiveRed,
        );
        await _loadPromotions();
      }
    } catch (error) {
      if (mounted) {
        showAdminMessage(
          context,
          'Erreur: $error',
          backgroundColor: AdminPalette.destructiveRed,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busyPromotionIds.remove(promotionId));
      }
    }
  }

  Widget _buildPromotionCard(Map<String, dynamic> promotion) {
    final id = int.tryParse(promotion['id'].toString());
    if (id == null) return const SizedBox.shrink();

    final titre = promotion['titre']?.toString() ?? 'Promotion';
    final description = promotion['description']?.toString() ?? '';
    final imageUrl = promotion['image_url']?.toString() ?? '';
    final dateDebut = promotion['date_debut']?.toString() ?? '';
    final dateFin = promotion['date_fin']?.toString() ?? '';
    final actif = promotion['actif'] == true;
    final frequence = promotion['frequence']?.toString() ?? '';
    final isBusy = _busyPromotionIds.contains(id);

    return AdminWorkItemCard(
      leading: ServiceImageThumbnail(
        imageUrl: imageUrl,
        semanticLabel: 'Visuel de la promotion $titre',
        width: 52,
        height: 52,
        borderRadius: AdminRadii.field,
      ),
      status: actif ? 'active' : 'inactive',
      reference: 'PROMO-$id',
      title: titre,
      requester: description,
      meta: 'Du $dateDebut au $dateFin · ${_getFrequenceLabel(frequence)}',
      amount: actif ? 'Active' : 'Inactive',
      footer: Row(
        children: [
          IconButton(
            onPressed: isBusy ? null : () => _togglePromotion(id, actif),
            tooltip: actif ? 'Désactiver' : 'Activer',
            icon: Icon(actif ? Icons.visibility_off : Icons.visibility),
            color: actif ? AdminPalette.safetyAmber : AdminPalette.approvalGreen,
          ),
          IconButton(
            onPressed: isBusy ? null : () => _deletePromotion(id),
            tooltip: 'Supprimer',
            icon: const Icon(Icons.delete_outline),
            color: AdminPalette.destructiveRed,
          ),
        ],
      ),
    );
  }

  String _getFrequenceLabel(String frequence) {
    switch (frequence) {
      case 'chaque_ouverture':
        return 'À chaque ouverture';
      case 'une_fois_par_jour':
        return 'Une fois par jour';
      case 'une_seule_fois':
        return 'Une seule fois';
      default:
        return frequence;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visiblePromotions = _visiblePromotions;
    final content = _isLoading && _promotions.isEmpty
        ? const SliverFillRemaining(
            hasScrollBody: false,
            child: AdminLoadingState(label: 'Chargement des promotions…'),
          )
        : _errorMessage != null
            ? SliverFillRemaining(
                hasScrollBody: false,
                child: AdminErrorState(
                  message: _errorMessage!,
                  onRetry: _loadPromotions,
                ),
              )
            : visiblePromotions.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: AdminEmptyState(
                      icon: Icons.campaign_outlined,
                      title: _filterStatut == 'actives'
                          ? 'Aucune promotion active'
                          : 'Aucune promotion',
                      message: 'Créez une nouvelle promotion pour la faire apparaître dans l\'application.',
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AdminSpacing.lg,
                      AdminSpacing.sm,
                      AdminSpacing.lg,
                      AdminSpacing.section,
                    ),
                    sliver: SliverList.builder(
                      itemCount: visiblePromotions.length,
                      itemBuilder: (context, index) => _buildPromotionCard(visiblePromotions[index]),
                    ),
                  );

    return RefreshIndicator(
      onRefresh: _loadPromotions,
      color: AdminPalette.blueprintBlue,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: AdminPageHeader(
              title: 'Promotions',
              subtitle: 'Gérez les promotions et publicités affichées dans l\'application.',
              icon: Icons.campaign_outlined,
              actions: [
                IconButton(
                  onPressed: _isLoading ? null : _loadPromotions,
                  tooltip: 'Actualiser',
                  icon: const Icon(Icons.refresh),
                  color: AdminPalette.blueprintBlue,
                ),
                IconButton(
                  onPressed: _showCreatePromotionDialog,
                  tooltip: 'Créer une promotion',
                  icon: const Icon(Icons.add),
                  color: AdminPalette.approvalGreen,
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: AdminMetricCluster(
              primary: AdminMetric(
                label: 'Promotions actives',
                value: _countFor('actives'),
                icon: Icons.campaign,
              ),
              secondary: [
                AdminMetric(
                  label: 'Total promotions',
                  value: _promotions.length,
                  icon: Icons.list,
                ),
                AdminMetric(
                  label: 'Inactives',
                  value: _countFor('inactives'),
                  icon: Icons.visibility_off,
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: AdminSegmentedFilter(
              selectedValue: _filterStatut,
              onChanged: (value) => setState(() => _filterStatut = value),
              options: [
                AdminFilterOption(
                  value: 'tous',
                  label: 'Tous',
                  count: _countFor('tous'),
                ),
                AdminFilterOption(
                  value: 'actives',
                  label: 'Actives',
                  count: _countFor('actives'),
                ),
                AdminFilterOption(
                  value: 'inactives',
                  label: 'Inactives',
                  count: _countFor('inactives'),
                ),
              ],
            ),
          ),
          content,
        ],
      ),
    );
  }
}
