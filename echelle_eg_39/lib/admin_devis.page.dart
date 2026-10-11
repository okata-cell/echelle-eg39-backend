import 'package:flutter/material.dart';

import 'admin/admin_components.dart';
import 'admin/admin_devis_approval_dialog.dart';
import 'admin/admin_tokens.dart';
import 'api_service.dart';
import 'service.dart';
import 'service_image_thumbnail.dart';

typedef AdminDevisLoader = Future<List<Map<String, dynamic>>> Function();
typedef AdminDevisStatusUpdater =
    Future<Map<String, dynamic>> Function(int devisId, String statut);
typedef AdminServiceImageResolver = String? Function(Object? serviceId);

class AdminDevisPage extends StatefulWidget {
  const AdminDevisPage({
    super.key,
    this.loadDevis,
    this.updateDevisStatut,
    this.serviceImageResolver,
  });

  final AdminDevisLoader? loadDevis;
  final AdminDevisStatusUpdater? updateDevisStatut;
  final AdminServiceImageResolver? serviceImageResolver;

  @override
  State<AdminDevisPage> createState() => _AdminDevisPageState();
}

class _AdminDevisPageState extends State<AdminDevisPage> {
  List<Map<String, dynamic>> _devis = [];
  final Set<int> _busyDevisIds = <int>{};
  bool _isLoading = true;
  String? _errorMessage;
  String _filterStatut = 'a_examiner';

  @override
  void initState() {
    super.initState();
    _loadDevis();
  }

  Future<void> _loadDevis() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final loader = widget.loadDevis ?? ApiService.getDevis;
      final devis = await loader();
      if (!mounted) return;
      setState(() {
        _devis = devis;
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

  List<Map<String, dynamic>> get _visibleDevis {
    if (_filterStatut == 'tous') return _devis;

    return _devis.where((devis) {
      final status = adminStatusKey(devis['statut']);
      switch (_filterStatut) {
        case 'a_examiner':
          return status == 'en_attente' || status == 'en_traitement';
        case 'suivi':
          return status == 'approuvee' ||
              status == 'envoye' ||
              status == 'acceptee' ||
              status == 'en_cours' ||
              status == 'termine';
        default:
          return status == _filterStatut;
      }
    }).toList();
  }

  int _countFor(String filter) {
    if (filter == 'tous') return _devis.length;
    if (filter == 'a_examiner') {
      return _devis.where((devis) {
        final status = adminStatusKey(devis['statut']);
        return status == 'en_attente' || status == 'en_traitement';
      }).length;
    }
    if (filter == 'suivi') {
      return _devis.where((devis) {
        final status = adminStatusKey(devis['statut']);
        return status == 'approuvee' ||
            status == 'envoye' ||
            status == 'acceptee' ||
            status == 'en_cours' ||
            status == 'termine';
      }).length;
    }
    return _devis
        .where((devis) => adminStatusKey(devis['statut']) == filter)
        .length;
  }

  Future<void> _approveDevis(int devisId) async {
    if (!_startMutation(devisId)) return;

    try {
      final amount = await showAdminDevisApprovalDialog(
        context,
        devisId: devisId,
      );
      if (!mounted || amount == null) return;

      await ApiService.approveDevis(devisId, amount);
      if (!mounted) return;
      showAdminMessage(
        context,
        'Devis #$devisId approuvé : ${formatAdminAmount(amount)} communiqué au client.',
        backgroundColor: AdminPalette.approvalGreen,
      );
      await _loadDevis();
    } catch (error) {
      if (mounted) {
        showAdminMessage(
          context,
          'Approbation impossible : $error',
          backgroundColor: AdminPalette.destructiveRed,
        );
      }
    } finally {
      _finishMutation(devisId);
    }
  }

  Future<void> _rejectDevis(int devisId) async {
    if (!_startMutation(devisId)) return;

    try {
      final reason = await showAdminRejectionSheet(
        context,
        entityLabel: 'le devis #$devisId',
        helperText: 'Motif obligatoire : il sera visible par le client.',
      );
      if (!mounted || reason == null || reason.trim().isEmpty) return;

      await ApiService.rejectDevis(devisId, reason);
      if (mounted) {
        showAdminMessage(
          context,
          'Devis #$devisId rejeté.',
          backgroundColor: AdminPalette.destructiveRed,
        );
        await _loadDevis();
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
      _finishMutation(devisId);
    }
  }

  Future<void> _updateStatut(int devisId, String newStatus) async {
    if (!_startMutation(devisId)) return;

    try {
      final updater = widget.updateDevisStatut ?? ApiService.updateDevisStatut;
      await updater(devisId, newStatus);
      if (mounted) {
        showAdminMessage(
          context,
          'Devis #$devisId : ${adminStatusLabel(newStatus)}.',
          backgroundColor: AdminPalette.blueprintBlue,
        );
        await _loadDevis();
      }
    } catch (error) {
      if (mounted) {
        showAdminMessage(
          context,
          'Mise à jour impossible : $error',
          backgroundColor: AdminPalette.destructiveRed,
        );
      }
    } finally {
      _finishMutation(devisId);
    }
  }

  Future<void> _deleteDevis(int devisId) async {
    if (_busyDevisIds.contains(devisId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer le devis ?'),
        content: Text('Le devis #$devisId sera supprimé définitivement.'),
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

    if (!mounted || confirmed != true || !_startMutation(devisId)) return;

    try {
      await ApiService.deleteDevis(devisId);
      if (mounted) {
        showAdminMessage(
          context,
          'Devis #$devisId supprimé.',
          backgroundColor: AdminPalette.destructiveRed,
        );
        await _loadDevis();
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
      _finishMutation(devisId);
    }
  }

  bool _startMutation(int devisId) {
    if (!mounted || _busyDevisIds.contains(devisId)) return false;
    setState(() => _busyDevisIds.add(devisId));
    return true;
  }

  void _finishMutation(int devisId) {
    if (!mounted) return;
    setState(() => _busyDevisIds.remove(devisId));
  }

  String _displayValue(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  Widget _buildContactDetails(Map<String, dynamic> devis) {
    final email = _displayValue(devis['email']);
    final phone = _displayValue(devis['telephone']);
    final createdAt = formatAdminDate(devis['createdAt']);
    final adminNote = _displayValue(devis['commentaireAdmin']);
    final isRejected = adminStatusKey(devis['statut']) == 'rejetee';
    final description = _displayValue(devis['description']);
    final amount = devis['montant'];
    final linkedAccount = _buildLinkedAccount(devis);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AdminSpacing.lg,
          runSpacing: AdminSpacing.xs,
          children: [
            if (email.isNotEmpty) _buildMeta('✉ $email'),
            if (phone.isNotEmpty) _buildMeta('☎ $phone'),
            if (createdAt.isNotEmpty) _buildMeta('Reçu le $createdAt'),
            if (linkedAccount != null) _buildMeta(linkedAccount),
          ],
        ),
        if (amount != null) ...[
          const SizedBox(height: AdminSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AdminSpacing.md),
            decoration: BoxDecoration(
              color: AdminPalette.mutedSurface,
              borderRadius: BorderRadius.circular(AdminRadii.field),
            ),
            child: Text(
              'Montant approuvé : ${formatAdminAmount(amount)}',
              style: const TextStyle(
                color: AdminPalette.primaryText,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
        if (description.isNotEmpty) ...[
          const SizedBox(height: AdminSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AdminSpacing.md),
            decoration: BoxDecoration(
              color: AdminPalette.mutedSurface,
              borderRadius: BorderRadius.circular(AdminRadii.field),
            ),
            child: Text(
              description,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AdminPalette.primaryText,
                height: 1.4,
              ),
            ),
          ),
        ],
        if (adminNote.isNotEmpty) ...[
          const SizedBox(height: AdminSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AdminSpacing.md),
            decoration: BoxDecoration(
              color: adminStatusColor('rejetee').withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AdminRadii.field),
              border: Border.all(
                color: adminStatusColor('rejetee').withValues(alpha: 0.22),
              ),
            ),
            child: Text(
              isRejected
                  ? 'Motif du rejet : $adminNote'
                  : 'Note admin : $adminNote',
              style: TextStyle(
                color: isRejected
                    ? AdminPalette.destructiveRed
                    : AdminPalette.secondaryText,
                fontWeight: FontWeight.w700,
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

  // Décrit l'origine de la demande : compte connecté ou visiteur anonyme.
  String? _buildLinkedAccount(Map<String, dynamic> devis) {
    final userId = devis['userId'];
    if (userId == null) return 'Visiteur non connecté';

    final clientEmail = _displayValue(devis['clientEmail']);
    if (clientEmail.isEmpty) return 'Compte lié #$userId';

    return 'Compte lié #$userId · $clientEmail';
  }

  Widget _buildFooter(Map<String, dynamic> devis, int devisId) {
    final status = adminStatusKey(devis['statut']);
    final isPending = status == 'en_attente';
    final isBusy = _busyDevisIds.contains(devisId);

    if (isPending) {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: OutlinedButton.icon(
          onPressed: isBusy
              ? null
              : () => _updateStatut(devisId, 'en_traitement'),
          icon: const Icon(Icons.manage_search_outlined, size: 18),
          label: const Text('Commencer l’examen'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AdminPalette.blueprintBlue,
            side: const BorderSide(color: AdminPalette.blueprintBlue),
            minimumSize: const Size(0, 44),
          ),
        ),
      );
    }

    if (status == 'en_traitement') {
      return AdminDecisionBar(
        isBusy: isBusy,
        approveLabel: 'Approuver le devis',
        onApprove: () => _approveDevis(devisId),
        onReject: () => _rejectDevis(devisId),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (status == 'approuvee' ||
            status == 'envoye' ||
            status == 'acceptee' ||
            status == 'en_cours')
          PopupMenuButton<String>(
            tooltip: 'Modifier le suivi',
            onSelected: (value) => _updateStatut(devisId, value),
            itemBuilder: (context) => [
              if (status != 'en_cours')
                const PopupMenuItem(
                  value: 'en_cours',
                  child: Text('Service en cours'),
                ),
              if (status == 'en_cours')
                const PopupMenuItem(value: 'termine', child: Text('Terminé')),
            ],
            child: const Icon(
              Icons.more_horiz,
              color: AdminPalette.secondaryText,
            ),
          ),
        IconButton(
          onPressed: isBusy ? null : () => _deleteDevis(devisId),
          tooltip: 'Supprimer',
          icon: const Icon(Icons.delete_outline),
          color: AdminPalette.destructiveRed,
        ),
      ],
    );
  }

  Widget _buildDevisItem(Map<String, dynamic> devis) {
    final id = int.tryParse(devis['id'].toString());
    if (id == null) return const SizedBox.shrink();

    final serviceName = _displayValue(
      devis['serviceName'],
      fallback: 'Service non renseigné',
    );
    final imageResolver =
        widget.serviceImageResolver ?? ServiceScreen.imageUrlForId;
    final serviceImageUrl = imageResolver(devis['serviceId']);
    final requester = _displayValue(
      devis['nom'],
      fallback: 'Client non renseigné',
    );
    final phone = _displayValue(devis['telephone']);
    final requesterLine = phone.isEmpty ? requester : '$requester  ·  $phone';

    return AdminWorkItemCard(
      status: devis['statut'],
      reference: 'Devis #$id',
      title: serviceName,
      leading: ServiceImageThumbnail(
        key: ValueKey('admin-devis-service-image-$id'),
        imageUrl: serviceImageUrl,
        semanticLabel: 'Image du service $serviceName',
        width: 64,
        height: 64,
      ),
      requester: requesterLine,
      meta: 'Demande de service · ${adminStatusLabel(devis['statut'])}',
      details: _buildContactDetails(devis),
      footer: _buildFooter(devis, id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleDevis = _visibleDevis;
    final content = _isLoading && _devis.isEmpty
        ? const SliverFillRemaining(
            hasScrollBody: false,
            child: AdminLoadingState(
              label: 'Chargement des demandes de devis…',
            ),
          )
        : _errorMessage != null
        ? SliverFillRemaining(
            hasScrollBody: false,
            child: AdminErrorState(
              message: _errorMessage!,
              onRetry: _loadDevis,
            ),
          )
        : visibleDevis.isEmpty
        ? SliverFillRemaining(
            hasScrollBody: false,
            child: AdminEmptyState(
              icon: Icons.request_quote_outlined,
              title: _filterStatut == 'a_examiner'
                  ? 'Aucune demande à examiner'
                  : 'Aucun devis pour ce filtre',
              message: _filterStatut == 'a_examiner'
                  ? 'Les nouvelles demandes apparaîtront ici.'
                  : 'Changez de filtre ou actualisez la file.',
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
              itemCount: visibleDevis.length,
              itemBuilder: (context, index) =>
                  _buildDevisItem(visibleDevis[index]),
            ),
          );

    return RefreshIndicator(
      onRefresh: _loadDevis,
      color: AdminPalette.blueprintBlue,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: AdminPageHeader(
              title: 'Demandes de devis',
              subtitle:
                  'Examinez les besoins clients et pilotez les réponses commerciales.',
              icon: Icons.request_quote_outlined,
              actions: [
                IconButton(
                  onPressed: _isLoading ? null : _loadDevis,
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
                label: 'Demandes à examiner',
                value: _countFor('a_examiner'),
                icon: Icons.pending_actions_outlined,
              ),
              secondary: [
                AdminMetric(
                  label: 'Approuvées',
                  value: _countFor('approuvee'),
                  icon: Icons.check_circle_outline,
                ),
                AdminMetric(
                  label: 'Rejetées',
                  value: _countFor('rejetee'),
                  icon: Icons.cancel_outlined,
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
                  value: 'a_examiner',
                  label: 'À examiner',
                  count: _countFor('a_examiner'),
                ),
                AdminFilterOption(
                  value: 'en_attente',
                  label: 'En attente',
                  count: _countFor('en_attente'),
                ),
                AdminFilterOption(
                  value: 'en_traitement',
                  label: 'En traitement',
                  count: _countFor('en_traitement'),
                ),
                AdminFilterOption(
                  value: 'approuvee',
                  label: 'Approuvées',
                  count: _countFor('approuvee'),
                ),
                AdminFilterOption(
                  value: 'rejetee',
                  label: 'Rejetées',
                  count: _countFor('rejetee'),
                ),
                AdminFilterOption(
                  value: 'suivi',
                  label: 'Suivi',
                  count: _countFor('suivi'),
                ),
                AdminFilterOption(
                  value: 'tous',
                  label: 'Tous',
                  count: _countFor('tous'),
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
