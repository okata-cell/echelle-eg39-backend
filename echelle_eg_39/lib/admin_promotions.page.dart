import 'package:flutter/material.dart';

import 'admin/admin_components.dart';
import 'admin/admin_tokens.dart';
import 'api_service.dart';

class AdminPromotionsPage extends StatefulWidget {
  const AdminPromotionsPage({super.key});

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
      final promotions = await ApiService.getPromotions();
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

  List<Map<String, dynamic>> get _visiblePromotions {
    if (_filterStatut == 'tous') return _promotions;
    return _promotions.where((promo) {
      final isActive = promo['actif'] == true;
      final now = DateTime.now();
      final dateDebut = DateTime.tryParse(promo['date_debut']?.toString() ?? '') ?? now;
      final dateFin = DateTime.tryParse(promo['date_fin']?.toString() ?? '') ?? now;
      final isInPeriod = now.isAfter(dateDebut) && now.isBefore(dateFin);
      
      switch (_filterStatut) {
        case 'actives':
          return isActive && isInPeriod;
        case 'inactives':
          return !isActive || !isInPeriod;
        default:
          return true;
      }
    }).toList();
  }

  int _countFor(String filter) {
    if (filter == 'tous') return _promotions.length;
    return _visiblePromotions.length;
  }

  Future<void> _showCreatePromotionDialog() async {
    final titreController = TextEditingController();
    final descriptionController = TextEditingController();
    final imageUrlController = TextEditingController();
    DateTime? dateDebut;
    DateTime? dateFin;
    bool actif = true;
    String frequence = 'chaque_ouverture';

    // ignore: unused_local_variable
    final _ = imageUrlController;

    // ignore: unused_local_variable
    final _ = imageUrlController;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text(
              'Créer une promotion',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titreController,
                    decoration: const InputDecoration(
                      labelText: 'Titre',
                      hintText: 'Promotion spéciale GPS',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Profitez de -20% sur...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: imageUrlController,
                    decoration: const InputDecoration(
                      labelText: 'URL de l\'image',
                      hintText: 'https://...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() => dateDebut = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            dateDebut == null
                                ? 'Date de début'
                                : '${dateDebut!.day}/${dateDebut!.month}/${dateDebut!.year}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now().add(const Duration(days: 30)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() => dateFin = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            dateFin == null
                                ? 'Date de fin'
                                : '${dateFin!.day}/${dateFin!.month}/${dateFin!.year}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Afficher automatiquement'),
                    subtitle: const Text('La promotion apparaîtra dans l\'app'),
                    value: actif,
                    onChanged: (value) => setState(() => actif = value),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Fréquence d\'affichage',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text('À chaque ouverture'),
                        value: 'chaque_ouverture',
                        groupValue: frequence,
                        onChanged: (value) => setState(() => frequence = value!),
                      ),
                      RadioListTile<String>(
                        title: const Text('Une fois par jour'),
                        value: 'une_fois_par_jour',
                        groupValue: frequence,
                        onChanged: (value) => setState(() => frequence = value!),
                      ),
                      RadioListTile<String>(
                        title: const Text('Une seule fois'),
                        value: 'une_seule_fois',
                        groupValue: frequence,
                        onChanged: (value) => setState(() => frequence = value!),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (titreController.text.trim().isEmpty ||
                      descriptionController.text.trim().isEmpty ||
                      dateDebut == null ||
                      dateFin == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Veuillez remplir tous les champs obligatoires'),
                        backgroundColor: AdminPalette.destructiveRed,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, {
                    'titre': titreController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'image_url': imageUrlController.text.trim(),
                    'date_debut': dateDebut!.toIso8601String().split('T')[0],
                    'date_fin': dateFin!.toIso8601String().split('T')[0],
                    'actif': actif,
                    'frequence': frequence,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminPalette.blueprintBlue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Publier'),
              ),
            ],
          );
        },
      ),
    );

    if (result == null) return;

    try {
      await ApiService.createPromotion(result);
      if (mounted) {
        showAdminMessage(
          context,
          'Promotion créée avec succès',
          backgroundColor: AdminPalette.approvalGreen,
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
    }
  }

  Future<void> _togglePromotion(int promotionId, bool currentStatus) async {
    if (_busyPromotionIds.contains(promotionId)) return;

    setState(() => _busyPromotionIds.add(promotionId));

    try {
      await ApiService.togglePromotion(promotionId, !currentStatus);
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
      await ApiService.deletePromotion(promotionId);
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
        : _errorMessage != null && _promotions.isEmpty
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
