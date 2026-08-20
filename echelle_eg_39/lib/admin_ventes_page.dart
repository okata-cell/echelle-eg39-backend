import 'package:flutter/material.dart';

import 'admin/admin_components.dart';
import 'admin/admin_tokens.dart';
import 'api_service.dart';

/// File admin des demandes d’achat.
///
/// Le nom historique est conservé car le dashboard et d’autres écrans
/// l’utilisent déjà comme point d’entrée.
class AdminVentesPageFixed extends StatefulWidget {
  const AdminVentesPageFixed({super.key});

  @override
  State<AdminVentesPageFixed> createState() => _AdminVentesPageFixedState();
}

class _AdminVentesPageFixedState extends State<AdminVentesPageFixed> {
  List<Map<String, dynamic>> _demandes = [];
  final Set<int> _busyDemandeIds = <int>{};
  bool _isLoading = true;
  String? _errorMessage;
  String _filter = 'en_attente';

  @override
  void initState() {
    super.initState();
    _loadDemandes();
  }

  Future<void> _loadDemandes() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final demandes = await ApiService.getDemandesAchat();
      if (!mounted) return;
      setState(() {
        _demandes = demandes;
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

  String _status(Map<String, dynamic> demande) {
    return adminStatusKey(demande['statut']);
  }

  List<Map<String, dynamic>> _historyDemandes() {
    return _demandes.where((demande) {
      final status = _status(demande);
      return status == 'rejetee' || status == 'termine';
    }).toList();
  }

  List<Map<String, dynamic>> get _visibleDemandes {
    switch (_filter) {
      case 'en_attente':
        return _demandes.where((demande) => _status(demande) == 'en_attente').toList();
      case 'approuvee':
        return _demandes.where((demande) => _status(demande) == 'approuvee').toList();
      case 'corbeille':
        return _historyDemandes();
      case 'tous':
      default:
        return _demandes;
    }
  }

  int _countFor(String filter) {
    switch (filter) {
      case 'en_attente':
        return _demandes.where((demande) => _status(demande) == 'en_attente').length;
      case 'approuvee':
        return _demandes.where((demande) => _status(demande) == 'approuvee').length;
      case 'corbeille':
        return _historyDemandes().length;
      case 'tous':
      default:
        return _demandes.length;
    }
  }

  Future<void> _approveDemande(int demandeId) async {
    if (!_startMutation(demandeId)) return;

    try {
      await ApiService.updateDemandeAchatStatut(
        demandeId,
        'approuvee',
        commentaire: 'Demande approuvée par l’administration.',
      );
      if (mounted) {
        showAdminMessage(
          context,
          'Demande #$demandeId approuvée.',
          backgroundColor: AdminPalette.approvalGreen,
        );
        await _loadDemandes();
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
      _finishMutation(demandeId);
    }
  }

  Future<void> _rejectDemande(int demandeId) async {
    if (_busyDemandeIds.contains(demandeId)) return;

    final reason = await showAdminRejectionSheet(
      context,
      entityLabel: 'la demande #$demandeId',
    );
    if (!mounted || reason == null || reason.trim().isEmpty) return;
    if (!_startMutation(demandeId)) return;

    try {
      await ApiService.updateDemandeAchatStatut(
        demandeId,
        'rejetee',
        commentaire: reason,
      );
      if (mounted) {
        showAdminMessage(
          context,
          'Demande #$demandeId rejetée.',
          backgroundColor: AdminPalette.destructiveRed,
        );
        await _loadDemandes();
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
      _finishMutation(demandeId);
    }
  }

  Future<void> _deleteDemande(int demandeId) async {
    if (_busyDemandeIds.contains(demandeId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer la demande ?'),
        content: Text('La demande #$demandeId sera supprimée définitivement.'),
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

    if (!mounted || confirmed != true || !_startMutation(demandeId)) return;

    try {
      await ApiService.deleteDemande(demandeId);
      if (mounted) {
        showAdminMessage(
          context,
          'Demande #$demandeId supprimée.',
          backgroundColor: AdminPalette.destructiveRed,
        );
        await _loadDemandes();
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
      _finishMutation(demandeId);
    }
  }

  bool _startMutation(int demandeId) {
    if (!mounted || _busyDemandeIds.contains(demandeId)) return false;
    setState(() => _busyDemandeIds.add(demandeId));
    return true;
  }

  void _finishMutation(int demandeId) {
    if (!mounted) return;
    setState(() => _busyDemandeIds.remove(demandeId));
  }

  String _display(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  Widget _buildDetails(Map<String, dynamic> demande) {
    final email = _display(demande['clientEmail']);
    final phone = _display(demande['clientPhone']);
    final date = formatAdminDate(demande['createdAt']);
    final note = _display(demande['commentaireAdmin'] ?? demande['commentaire_admin']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AdminSpacing.lg,
          runSpacing: AdminSpacing.xs,
          children: [
            if (email.isNotEmpty) _buildMeta('✉ $email'),
            if (phone.isNotEmpty) _buildMeta('☎ $phone'),
            if (date.isNotEmpty) _buildMeta('Reçu le $date'),
          ],
        ),
        if (note.isNotEmpty) ...[
          const SizedBox(height: AdminSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AdminSpacing.md),
            decoration: BoxDecoration(
              color: AdminPalette.mutedSurface,
              borderRadius: BorderRadius.circular(AdminRadii.field),
            ),
            child: Text(
              'Note admin : $note',
              style: const TextStyle(color: AdminPalette.secondaryText, height: 1.35),
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

  Widget _buildFooter(Map<String, dynamic> demande, int id) {
    final status = _status(demande);
    final busy = _busyDemandeIds.contains(id);

    if (status == 'en_attente') {
      return AdminDecisionBar(
        isBusy: busy,
        onApprove: () => _approveDemande(id),
        onReject: () => _rejectDemande(id),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (status == 'rejetee' || status == 'termine')
          IconButton(
            onPressed: busy ? null : () => _deleteDemande(id),
            tooltip: 'Supprimer',
            icon: const Icon(Icons.delete_outline),
            color: AdminPalette.destructiveRed,
          ),
      ],
    );
  }

  Widget _buildDemandeItem(Map<String, dynamic> demande) {
    final id = int.tryParse(demande['id'].toString());
    if (id == null) return const SizedBox.shrink();

    final product = _display(demande['appareilNom'], fallback: 'Appareil non renseigné');
    final client = _display(demande['clientNom'], fallback: 'Client non renseigné');
    final quantity = demande['quantite'] ?? 1;
    final code = _display(demande['code'], fallback: 'DA-$id');

    return AdminWorkItemCard(
      status: demande['statut'],
      reference: code,
      title: '$product  ×$quantity',
      requester: client,
      meta: 'Demande d’achat · ${adminStatusLabel(demande['statut'])}',
      amount: formatAdminAmount(demande['total']),
      details: _buildDetails(demande),
      footer: _buildFooter(demande, id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleDemandes = _visibleDemandes;
    final content = _isLoading && _demandes.isEmpty
        ? const SliverFillRemaining(
            hasScrollBody: false,
            child: AdminLoadingState(label: 'Chargement des demandes d’achat…'),
          )
        : _errorMessage != null && _demandes.isEmpty
            ? SliverFillRemaining(
                hasScrollBody: false,
                child: AdminErrorState(message: _errorMessage!, onRetry: _loadDemandes),
              )
            : visibleDemandes.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: AdminEmptyState(
                      icon: Icons.shopping_cart_outlined,
                      title: _filter == 'en_attente'
                          ? 'Aucune demande en attente'
                          : 'Aucune demande pour ce filtre',
                      message: _filter == 'en_attente'
                          ? 'Les nouvelles demandes d’achat apparaîtront ici.'
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
                      itemCount: visibleDemandes.length,
                      itemBuilder: (context, index) => _buildDemandeItem(visibleDemandes[index]),
                    ),
                  );

    return RefreshIndicator(
      onRefresh: _loadDemandes,
      color: AdminPalette.blueprintBlue,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: AdminPageHeader(
              title: 'Demandes d’achat',
              subtitle: 'Priorisez les commandes d’équipement et suivez leur traitement.',
              icon: Icons.shopping_cart_outlined,
              actions: [
                IconButton(
                  onPressed: _isLoading ? null : _loadDemandes,
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
                  value: 'approuvee',
                  label: 'Approuvées',
                  count: _countFor('approuvee'),
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
      ),
    );
  }
}
