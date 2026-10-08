import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
        case 'reponses':
          return status == 'acceptee' || status == 'refusee';
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
    if (filter == 'reponses') {
      return _devis.where((devis) {
        final status = adminStatusKey(devis['statut']);
        return status == 'acceptee' || status == 'refusee';
      }).length;
    }
    return _devis.where((devis) => adminStatusKey(devis['statut']) == filter).length;
  }

  Future<void> _issueDevis(int devisId) async {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final validUntilController = TextEditingController();
    final documentController = TextEditingController();
    final noteController = TextEditingController();
    DateTime? validUntil;
    var isSaving = false;
    final messenger = ScaffoldMessenger.of(context);

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text('Émettre le devis #$devisId'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Montant (FCFA)',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      validator: (value) {
                        final amount = int.tryParse(value?.trim() ?? '');
                        return amount == null || amount <= 0
                            ? 'Saisissez un montant entier supérieur à zéro.'
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: validUntilController,
                      readOnly: true,
                      onTap: () async {
                        final today = DateUtils.dateOnly(DateTime.now());
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: validUntil ?? today,
                          firstDate: today,
                          lastDate: DateTime(today.year + 5),
                        );
                        if (picked != null) {
                          validUntil = picked;
                          setDialogState(() {
                            validUntilController.text =
                                '${picked.year.toString().padLeft(4, '0')}-'
                                '${picked.month.toString().padLeft(2, '0')}-'
                                '${picked.day.toString().padLeft(2, '0')}';
                          });
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Valable jusqu’au',
                        prefixIcon: Icon(Icons.event_outlined),
                      ),
                      validator: (value) => value?.isNotEmpty == true
                          ? null
                          : 'Choisissez une date de validité.',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: documentController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Lien HTTPS du document PDF',
                        helperText: 'Collez un lien durable vers le PDF hébergé.',
                        prefixIcon: Icon(Icons.picture_as_pdf_outlined),
                      ),
                      validator: (value) {
                        final uri = Uri.tryParse(value?.trim() ?? '');
                        return uri != null &&
                                uri.scheme == 'https' &&
                                uri.host.isNotEmpty &&
                                uri.userInfo.isEmpty
                            ? null
                            : 'Saisissez une URL HTTPS valide.';
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: noteController,
                      maxLines: 2,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        labelText: 'Message au client (facultatif)',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Annuler'),
              ),
              ElevatedButton.icon(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        if (!_startMutation(devisId)) return;
                        setDialogState(() => isSaving = true);
                        try {
                          await ApiService.issueDevisOffer(
                            devisId: devisId,
                            montant: int.parse(amountController.text.trim()),
                            dateValidite: validUntilController.text,
                            documentUrl: documentController.text.trim(),
                            commentaireAdmin: noteController.text,
                          );
                          if (!mounted || !dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          messenger
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Offre envoyée au client pour le devis #$devisId.',
                                ),
                                backgroundColor: AdminPalette.approvalGreen,
                              ),
                            );
                          await _loadDevis();
                        } catch (error) {
                          if (mounted) {
                            messenger
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text('Émission impossible : $error'),
                                  backgroundColor: AdminPalette.destructiveRed,
                                ),
                              );
                          }
                        } finally {
                          _finishMutation(devisId);
                          if (dialogContext.mounted) {
                            setDialogState(() => isSaving = false);
                          }
                        }
                      },
                icon: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: const Text('Envoyer l’offre'),
              ),
            ],
          ),
        ),
      );
    } finally {
      amountController.dispose();
      validUntilController.dispose();
      documentController.dispose();
      noteController.dispose();
    }
  }

  Future<void> _openDocument(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      showAdminMessage(
        context,
        'Le lien du PDF est invalide.',
        backgroundColor: AdminPalette.destructiveRed,
      );
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      showAdminMessage(context, 'Impossible d’ouvrir le PDF.');
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
    final amount = devis['montant'];
    final validity = formatAdminDate(devis['dateValidite']);
    final documentUrl = _displayValue(devis['documentUrl']);
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
        if (amount != null || validity.isNotEmpty || documentUrl.isNotEmpty) ...[
          const SizedBox(height: AdminSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AdminSpacing.md),
            decoration: BoxDecoration(
              color: AdminPalette.mutedSurface,
              borderRadius: BorderRadius.circular(AdminRadii.field),
            ),
            child: Wrap(
              spacing: AdminSpacing.md,
              runSpacing: AdminSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (amount != null)
                  _buildMeta('Montant : ${formatAdminAmount(amount)}'),
                if (validity.isNotEmpty) _buildMeta('Valable jusqu’au $validity'),
                if (documentUrl.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => _openDocument(documentUrl),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('Ouvrir le PDF'),
                  ),
              ],
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
      return AdminDecisionBar(
        isBusy: isBusy,
        approveLabel: 'Émettre un devis',
        onApprove: () => _issueDevis(devisId),
        onReject: () => _rejectDevis(devisId),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (status == 'envoye' && devis['clientReponduAt'] == null)
          IconButton(
            onPressed: isBusy ? null : () => _issueDevis(devisId),
            tooltip: 'Modifier l’offre',
            icon: const Icon(Icons.edit_outlined),
            color: AdminPalette.blueprintBlue,
          ),
        if (status != 'rejetee' && status != 'refusee' && status != 'envoye')
          PopupMenuButton<String>(
            tooltip: 'Modifier le suivi',
            onSelected: (value) => _updateStatut(devisId, value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'en_cours', child: Text('En cours')),
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
                  value: 'reponses',
                  label: 'Réponses',
                  count: _countFor('reponses'),
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
