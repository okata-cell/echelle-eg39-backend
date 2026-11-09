// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'actualite.dart';
import 'admin/actualite_editor_dialog.dart';
import 'admin/admin_components.dart';
import 'admin/admin_tokens.dart';
import 'api_service.dart';
import 'service_image_thumbnail.dart';

typedef ActualiteLoader = Future<List<Map<String, dynamic>>> Function();
typedef ActualiteCreator =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> actualite);
typedef ActualiteUpdater =
    Future<Map<String, dynamic>> Function(
      int actualiteId,
      Map<String, dynamic> actualite,
    );
typedef ActualiteStatutSetter =
    Future<Map<String, dynamic>> Function(int actualiteId, String statut);
typedef ActualitePinSetter =
    Future<Map<String, dynamic>> Function(int actualiteId, bool epingle);
typedef ActualiteDeleter = Future<void> Function(int actualiteId);
typedef ActualiteImageUploader =
    Future<Map<String, dynamic>> Function(XFile image);
typedef ActualiteImageDeleter = Future<void> Function(String storagePath);
typedef ActualitePicker = Future<XFile?> Function(ImageSource source);

/// Écran d'administration des actualités de l'accueil : rédaction, édition,
/// publication, épinglage et suppression.
class AdminActualitesPage extends StatefulWidget {
  const AdminActualitesPage({
    super.key,
    this.loadActualites,
    this.createActualite,
    this.updateActualite,
    this.setStatut,
    this.setEpingle,
    this.deleteActualite,
    this.uploadImage,
    this.deleteImage,
    this.pickImage,
  });

  final ActualiteLoader? loadActualites;
  final ActualiteCreator? createActualite;
  final ActualiteUpdater? updateActualite;
  final ActualiteStatutSetter? setStatut;
  final ActualitePinSetter? setEpingle;
  final ActualiteDeleter? deleteActualite;
  final ActualiteImageUploader? uploadImage;
  final ActualiteImageDeleter? deleteImage;
  final ActualitePicker? pickImage;

  @override
  State<AdminActualitesPage> createState() => _AdminActualitesPageState();
}

class _AdminActualitesPageState extends State<AdminActualitesPage> {
  List<Map<String, dynamic>> _rows = const [];
  final Set<int> _busyIds = <int>{};
  bool _isLoading = true;
  String? _errorMessage;
  String _filter = 'tous';

  @override
  void initState() {
    super.initState();
    _loadActualites();
  }

  List<Actualite> get _items => _rows
      .map(Actualite.tryParse)
      .whereType<Actualite>()
      .toList(growable: false);

  Map<int, Map<String, dynamic>> get _rawById => {
    for (final row in _rows)
      if (int.tryParse(row['id']?.toString() ?? '') != null)
        int.parse(row['id'].toString()): row,
  };

  Future<void> _loadActualites() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final loader = widget.loadActualites ?? ApiService.getAdminActualites;
      final rows = await loader();
      if (!mounted) return;
      setState(() {
        _rows = rows;
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

  bool _matchesFilter(Actualite actualite, String filter) {
    switch (filter) {
      case 'publiees':
        return actualite.publiee;
      case 'brouillons':
        return !actualite.publiee;
      default:
        return true;
    }
  }

  List<Actualite> get _visibleItems => _items
      .where((actualite) => _matchesFilter(actualite, _filter))
      .toList(growable: false);

  int _countFor(String filter) =>
      _items.where((actualite) => _matchesFilter(actualite, filter)).length;

  int get _countPinned => _items.where((actualite) => actualite.epingle).length;

  bool _isBusy(int id) => _busyIds.contains(id);

  Future<void> _openEditor({Actualite? initial}) async {
    final raw = initial == null ? null : _rawById[initial.id];
    final result = await ActualiteEditorSheet.show(
      context,
      initial: initial,
      initialImageStoragePath: raw?['image_storage_path']?.toString(),
      pickImage: widget.pickImage,
      onSubmit: (draft) =>
          initial == null ? _create(draft) : _update(initial, draft),
      onDelete: initial == null ? null : () => _delete(initial.id),
    );

    if (!mounted || result == null) return;

    showAdminMessage(
      context,
      result.deleted
          ? 'Actualité supprimée'
          : (initial == null ? 'Actualité créée' : 'Actualité mise à jour'),
      backgroundColor: result.deleted
          ? AdminPalette.destructiveRed
          : AdminPalette.approvalGreen,
    );
    await _loadActualites();
  }

  Future<void> _create(ActualiteDraft draft) async {
    String? imageUrl;
    String? storagePath;

    try {
      if (draft.image != null) {
        final uploader = widget.uploadImage ?? ApiService.uploadActualiteImage;
        final uploaded = await uploader(draft.image!);
        imageUrl = uploaded['imageUrl']?.toString();
        storagePath = uploaded['storagePath']?.toString();
        if (imageUrl == null || storagePath == null) {
          throw Exception('Le serveur n’a pas renvoyé le visuel téléversé.');
        }
      }

      final creator = widget.createActualite ?? ApiService.createActualite;
      await creator(<String, dynamic>{
        'titre': draft.titre,
        'description': draft.description,
        'date_publication': formatIsoDate(draft.datePublication),
        'statut': draft.publiee ? 'publiee' : 'brouillon',
        'epingle': draft.epingle,
        'image_url': imageUrl,
        'image_storage_path': storagePath,
      });
    } catch (_) {
      if (storagePath != null) {
        try {
          final removeImage =
              widget.deleteImage ?? ApiService.deleteActualiteImage;
          await removeImage(storagePath);
        } catch (cleanupError) {
          debugPrint(
            'Visuel d’actualité à nettoyer manuellement : $cleanupError',
          );
        }
      }
      rethrow;
    }
  }

  Future<void> _update(Actualite initial, ActualiteDraft draft) async {
    String? imageUrl = draft.removeImage ? null : initial.imageUrl;
    String? storagePath = draft.removeImage
        ? null
        : (draft.imageStoragePath ?? initial.imageStoragePath);
    String? uploadedPath;

    try {
      if (draft.image != null) {
        final uploader = widget.uploadImage ?? ApiService.uploadActualiteImage;
        final uploaded = await uploader(draft.image!);
        imageUrl = uploaded['imageUrl']?.toString();
        uploadedPath = uploaded['storagePath']?.toString();
        if (imageUrl == null || uploadedPath == null) {
          throw Exception('Le serveur n’a pas renvoyé le visuel téléversé.');
        }
        storagePath = uploadedPath;
      }

      final updater = widget.updateActualite ?? ApiService.updateActualite;
      await updater(initial.id, <String, dynamic>{
        'titre': draft.titre,
        'description': draft.description,
        'date_publication': formatIsoDate(draft.datePublication),
        'statut': draft.publiee ? 'publiee' : 'brouillon',
        'epingle': draft.epingle,
        'image_url': imageUrl,
        'image_storage_path': storagePath,
      });
    } catch (_) {
      if (uploadedPath != null) {
        try {
          final removeImage =
              widget.deleteImage ?? ApiService.deleteActualiteImage;
          await removeImage(uploadedPath);
        } catch (cleanupError) {
          debugPrint(
            'Visuel d’actualité à nettoyer manuellement : $cleanupError',
          );
        }
      }
      rethrow;
    }
  }

  Future<void> _delete(int actualiteId) async {
    final deleter = widget.deleteActualite ?? ApiService.deleteActualite;
    await deleter(actualiteId);
  }

  Future<void> _setStatut(int actualiteId, bool publiee) async {
    if (_isBusy(actualiteId)) return;
    setState(() => _busyIds.add(actualiteId));

    try {
      final update = widget.setStatut ?? ApiService.setActualiteStatut;
      await update(actualiteId, publiee ? 'publiee' : 'brouillon');
      if (mounted) {
        showAdminMessage(
          context,
          publiee ? 'Actualité publiée' : 'Actualité repassée en brouillon',
          backgroundColor: publiee
              ? AdminPalette.approvalGreen
              : AdminPalette.safetyAmber,
        );
        await _loadActualites();
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
      if (mounted) setState(() => _busyIds.remove(actualiteId));
    }
  }

  Future<void> _setEpingle(int actualiteId, bool epingle) async {
    if (_isBusy(actualiteId)) return;
    setState(() => _busyIds.add(actualiteId));

    try {
      final update = widget.setEpingle ?? ApiService.setActualiteEpingle;
      await update(actualiteId, !epingle);
      if (mounted) {
        showAdminMessage(
          context,
          epingle ? 'Actualité désépinglée' : 'Actualité épinglée en tête',
          backgroundColor: AdminPalette.blueprintBlue,
        );
        await _loadActualites();
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
      if (mounted) setState(() => _busyIds.remove(actualiteId));
    }
  }

  String _dateLabel(DateTime date) {
    final jour = date.day.toString().padLeft(2, '0');
    final mois = date.month.toString().padLeft(2, '0');
    return '$jour/$mois/${date.year}';
  }

  Widget _buildActualiteCard(Actualite actualite) {
    final isBusy = _isBusy(actualite.id);
    final meta = actualite.epingle
        ? '${_dateLabel(actualite.datePublication)}  ·  Épinglée'
        : _dateLabel(actualite.datePublication);

    return AdminWorkItemCard(
      leading: ServiceImageThumbnail(
        imageUrl: actualite.imageUrl,
        semanticLabel: 'Photo de l’actualité ${actualite.titre}',
        width: 52,
        height: 52,
        borderRadius: AdminRadii.field,
      ),
      status: actualite.publiee ? 'publiee' : 'brouillon',
      reference: 'ACT-${actualite.id}',
      title: actualite.titre,
      requester: actualite.description,
      meta: meta,
      onTap: isBusy ? null : () => _openEditor(initial: actualite),
      footer: Row(
        children: [
          IconButton(
            key: ValueKey('actualite-pin-${actualite.id}'),
            onPressed: isBusy
                ? null
                : () => _setEpingle(actualite.id, actualite.epingle),
            tooltip: actualite.epingle
                ? 'Désépingler'
                : 'Épingler sur l’accueil',
            icon: Icon(
              actualite.epingle ? Icons.push_pin : Icons.push_pin_outlined,
            ),
            color: actualite.epingle
                ? AdminPalette.safetyAmber
                : AdminPalette.secondaryText,
          ),
          const Spacer(),
          Semantics(
            label: actualite.publiee
                ? 'Dépublier l’actualité'
                : 'Publier l’actualité',
            child: Switch(
              key: ValueKey('actualite-publish-${actualite.id}'),
              value: actualite.publiee,
              onChanged: isBusy
                  ? null
                  : (value) => _setStatut(actualite.id, value),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _visibleItems;
    final content = _isLoading && _rows.isEmpty
        ? const SliverFillRemaining(
            hasScrollBody: false,
            child: AdminLoadingState(label: 'Chargement des actualités…'),
          )
        : _errorMessage != null
        ? SliverFillRemaining(
            hasScrollBody: false,
            child: AdminErrorState(
              message: _errorMessage!,
              onRetry: _loadActualites,
            ),
          )
        : visibleItems.isEmpty
        ? SliverFillRemaining(
            hasScrollBody: false,
            child: AdminEmptyState(
              icon: Icons.newspaper_outlined,
              title: _filter == 'tous'
                  ? 'Aucune actualité'
                  : 'Aucune actualité dans ce filtre',
              message:
                  'Rédigez une actualité pour l’afficher sur l’accueil de l’application.',
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
              itemCount: visibleItems.length,
              itemBuilder: (context, index) =>
                  _buildActualiteCard(visibleItems[index]),
            ),
          );

    return RefreshIndicator(
      onRefresh: _loadActualites,
      color: AdminPalette.blueprintBlue,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: AdminPageHeader(
              title: 'Actualités',
              subtitle:
                  'Rédigez les actualités affichées sur l’accueil de l’application.',
              icon: Icons.newspaper_outlined,
              actions: [
                IconButton(
                  onPressed: _isLoading ? null : _loadActualites,
                  tooltip: 'Actualiser',
                  icon: const Icon(Icons.refresh),
                  color: AdminPalette.blueprintBlue,
                ),
                IconButton(
                  onPressed: () => _openEditor(),
                  tooltip: 'Créer une actualité',
                  icon: const Icon(Icons.add),
                  color: AdminPalette.approvalGreen,
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: AdminMetricCluster(
              primary: AdminMetric(
                label: 'Publiées',
                value: _countFor('publiees'),
                icon: Icons.public,
              ),
              secondary: [
                AdminMetric(
                  label: 'Brouillons',
                  value: _countFor('brouillons'),
                  icon: Icons.edit_note,
                ),
                AdminMetric(
                  label: 'Épinglées',
                  value: _countPinned,
                  icon: Icons.push_pin_outlined,
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
                  value: 'tous',
                  label: 'Tous',
                  count: _countFor('tous'),
                ),
                AdminFilterOption(
                  value: 'publiees',
                  label: 'Publiées',
                  count: _countFor('publiees'),
                ),
                AdminFilterOption(
                  value: 'brouillons',
                  label: 'Brouillons',
                  count: _countFor('brouillons'),
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
