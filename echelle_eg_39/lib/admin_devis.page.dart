import 'package:flutter/material.dart';

import 'admin/admin_components.dart';
import 'admin/admin_tokens.dart';
import 'api_service.dart';

class AdminDevisPage extends StatefulWidget {
  const AdminDevisPage({super.key});

  @override
  State<AdminDevisPage> createState() => _AdminDevisPageState();
}

class _AdminDevisPageState extends State<AdminDevisPage> {
  List<Map<String, dynamic>> _devis = [];
  final Set<int> _busyDevisIds = <int>{};
  bool _isLoading = true;
  String? _errorMessage;
  String _filterStatut = 'en_attente';

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
      final devis = await ApiService.getDevis();
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
        case 'suivi':
          return status == 'en_cours' || status == 'envoye' || status == 'termine';
        default:
          return status == _filterStatut;
      }
    }).toList();
  }

  int _countFor(String filter) {
    if (filter == 'tous') return _devis.length;
    if (filter == 'suivi') {
      return _devis.where((devis) {
        final status = adminStatusKey(devis['statut']);
        return status == 'en_cours' || status == 'envoye' || status == 'termine';
      }).length;
    }
    return _devis.where((devis) => adminStatusKey(devis['statut']) == filter).length;
  }

  Future<void> _approveDevis(int devisId) async {
    if (!_startMutation(devisId)) return;

    try {
      await ApiService.approveDevis(devisId);
      if (mounted) {
        showAdminMessage(
          context,
          'Devis #$devisId approuvé.',
          backgroundColor: AdminPalette.approvalGreen,
        );
        await _loadDevis();
      }
    } catch (error) {
      if (mounted) {
        showAdminMessage(context, 'Approbation impossible : $error', backgroundColor: AdminPalette.destructiveRed);
      }
    } finally {
      _finishMutation(devisId);
    }
  }

  Future<void> _rejectDevis(int devisId) async {
    if (_busyDevisIds.contains(devisId)) return;

    final reason = await showAdminRejectionSheet(
      context,
      entityLabel: 'le devis #$devisId',
    );
    if (!mounted || reason == null || reason.trim().isEmpty) return;
    if (!_startMutation(devisId)) return;

    try {
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
        showAdminMessage(context, 'Rejet impossible : $error', backgroundColor: AdminPalette.destructiveRed);
      }
    } finally {
      _finishMutation(devisId);
    }
  }

  Future<void> _updateStatut(int devisId, String newStatus) async {
    if (!_startMutation(devisId)) return;

    try {
      await ApiService.updateDevisStatut(devisId, newStatus);
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
        showAdminMessage(context, 'Mise à jour impossible : $error', backgroundColor: AdminPalette.destructiveRed);
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
        showAdminMessage(context, 'Suppression impossible : $error', backgroundColor: AdminPalette.destructiveRed);
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
    final description = _displayValue(devis['description']);

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
          ],
        ),
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
              'Note admin : $adminNote',
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
      style: const TextStyle(
        color: AdminPalette.secondaryText,
        fontSize: 12,
      ),
    );
  }

  Widget _buildFooter(Map<String, dynamic> devis, int devisId) {
    final status = adminStatusKey(devis['statut']);
    final isPending = status == 'en_attente';
    final isBusy = _busyDevisIds.contains(devisId);

    if (isPending) {
      return AdminDecisionBar(
        isBusy: isBusy,
        onApprove: () => _approveDevis(devisId),
        onReject: () => _rejectDevis(devisId),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (status != 'rejetee')
          PopupMenuButton<String>(
            tooltip: 'Modifier le suivi',
            onSelected: (value) => _updateStatut(devisId, value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'en_cours', child: Text('En cours')),
              PopupMenuItem(value: 'envoye', child: Text('Envoyé')),
              PopupMenuItem(value: 'termine', child: Text('Terminé')),
            ],
            child: const Icon(Icons.more_horiz, color: AdminPalette.secondaryText),
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

    final serviceName = _displayValue(devis['serviceName'], fallback: 'Service non renseigné');
    final requester = _displayValue(devis['nom'], fallback: 'Client non renseigné');
    final phone = _displayValue(devis['telephone']);
    final requesterLine = phone.isEmpty ? requester : '$requester  ·  $phone';

    return AdminWorkItemCard(
      status: devis['statut'],
      reference: 'Devis #$id',
      title: serviceName,
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
            child: AdminLoadingState(label: 'Chargement des demandes de devis…'),
          )
        : _errorMessage != null && _devis.isEmpty
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
                      title: _filterStatut == 'en_attente'
                          ? 'Aucun devis en attente'
                          : 'Aucun devis pour ce filtre',
                      message: _filterStatut == 'en_attente'
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
                      itemBuilder: (context, index) => _buildDevisItem(visibleDevis[index]),
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
              subtitle: 'Examinez les besoins clients et pilotez les réponses commerciales.',
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
                label: 'Demandes à traiter',
                value: _countFor('en_attente'),
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
                  value: 'en_attente',
                  label: 'En attente',
                  count: _countFor('en_attente'),
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
