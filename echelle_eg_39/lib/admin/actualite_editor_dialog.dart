// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../actualite.dart';
import 'admin_tokens.dart';

const int maxActualiteImageBytes = 5 * 1024 * 1024;
const int maxActualiteTitre = 80;
const int maxActualiteDescription = 240;

typedef ActualiteImagePicker = Future<XFile?> Function(ImageSource source);

/// Ce que le formulaire renvoie à l'écran admin, avant tout appel réseau.
class ActualiteDraft {
  const ActualiteDraft({
    required this.titre,
    required this.description,
    required this.datePublication,
    required this.dateFin,
    required this.publiee,
    required this.epingle,
    this.image,
    this.removeImage = false,
    this.imageStoragePath,
  });

  final String titre;
  final String description;
  final DateTime datePublication;

  /// Dernier jour de diffusion de l'actualité sur l'accueil.
  final DateTime dateFin;
  final bool publiee;
  final bool epingle;

  /// Nouvelle photo choisie dans le formulaire, à téléverser.
  final XFile? image;

  /// La photo en place doit être retirée.
  final bool removeImage;

  /// Chemin Cloudinary de la photo en place, conservé si rien ne change.
  final String? imageStoragePath;
}

enum ActualiteEditorStatus { saved, deleted }

class ActualiteEditorResult {
  const ActualiteEditorResult.saved(this.draft)
    : status = ActualiteEditorStatus.saved;

  const ActualiteEditorResult.deleted()
    : draft = null,
      status = ActualiteEditorStatus.deleted;

  final ActualiteEditorStatus status;
  final ActualiteDraft? draft;

  bool get deleted => status == ActualiteEditorStatus.deleted;
}

/// Formulaire de création ou d'édition d'une actualité.
///
/// Le haut de la feuille montre la carte telle qu'elle apparaîtra sur
/// l'accueil : l'administrateur règle l'annonce en la regardant, et les
/// compteurs de caractères garantissent qu'aucun texte ne sera tronqué.
class ActualiteEditorSheet extends StatefulWidget {
  const ActualiteEditorSheet({
    super.key,
    this.initial,
    this.initialImageStoragePath,
    required this.onSubmit,
    this.onDelete,
    this.pickImage,
  });

  final Actualite? initial;
  final String? initialImageStoragePath;
  final Future<void> Function(ActualiteDraft draft) onSubmit;
  final Future<void> Function()? onDelete;
  final ActualiteImagePicker? pickImage;

  static Future<ActualiteEditorResult?> show(
    BuildContext context, {
    Actualite? initial,
    String? initialImageStoragePath,
    required Future<void> Function(ActualiteDraft draft) onSubmit,
    Future<void> Function()? onDelete,
    ActualiteImagePicker? pickImage,
  }) {
    return showModalBottomSheet<ActualiteEditorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.94,
        child: ActualiteEditorSheet(
          initial: initial,
          initialImageStoragePath: initialImageStoragePath,
          onSubmit: onSubmit,
          onDelete: onDelete,
          pickImage: pickImage,
        ),
      ),
    );
  }

  @override
  State<ActualiteEditorSheet> createState() => _ActualiteEditorSheetState();
}

class _ActualiteEditorSheetState extends State<ActualiteEditorSheet> {
  late final TextEditingController _titreController = TextEditingController(
    text: widget.initial?.titre ?? '',
  )..addListener(_onTextChanged);
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.initial?.description ?? '')
        ..addListener(_onTextChanged);

  late DateTime _datePublication = widget.initial?.datePublication ?? _today;
  // Trente jours par défaut : une annonce a une échéance, quitte à l'allonger.
  late DateTime _dateFin =
      widget.initial?.dateFin ?? _datePublication.add(const Duration(days: 30));
  // Une actualité rédigée par l'administrateur est destinée à être vue : elle
  // part publiée, et le brouillon reste un choix explicite.
  late bool _publiee = widget.initial?.publiee ?? true;
  late bool _epingle = widget.initial?.epingle ?? false;

  final ImagePicker _picker = ImagePicker();
  XFile? _image;
  Uint8List? _imageBytes;
  bool _removeImage = false;
  bool _isPickingImage = false;
  bool _isSubmitting = false;
  bool _isDeleting = false;
  String? _error;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get _hasImage =>
      _imageBytes != null ||
      (!_removeImage && (widget.initial?.hasImage ?? false));

  bool get _isBusy => _isSubmitting || _isDeleting;

  @override
  void dispose() {
    _titreController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() => _error = null);
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isBusy || _isPickingImage) return;
    setState(() {
      _isPickingImage = true;
      _error = null;
    });

    try {
      final picked = widget.pickImage != null
          ? await widget.pickImage!(source)
          : await _picker.pickImage(
              source: source,
              maxWidth: 1600,
              maxHeight: 1600,
              imageQuality: 82,
            );
      if (!mounted || picked == null) return;

      final bytes = await picked.readAsBytes();
      if (bytes.length > maxActualiteImageBytes) {
        setState(() => _error = 'L’image doit faire 5 Mo maximum.');
        return;
      }

      final extension = picked.name.split('.').last.toLowerCase();
      final mimeType = picked.mimeType?.toLowerCase();
      final supportedExtension = [
        'jpg',
        'jpeg',
        'png',
        'webp',
      ].contains(extension);
      final supportedMimeType = [
        'image/jpeg',
        'image/png',
        'image/webp',
      ].contains(mimeType);
      if (!supportedExtension && !supportedMimeType) {
        setState(() => _error = 'Choisissez une image JPEG, PNG ou WebP.');
        return;
      }

      setState(() {
        _image = picked;
        _imageBytes = bytes;
        _removeImage = false;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Impossible d’ouvrir la source photo. Réessayez.',
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<void> _chooseImageSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AdminPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AdminRadii.sheet),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AdminSpacing.lg,
            AdminSpacing.md,
            AdminSpacing.lg,
            AdminSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ajouter une photo',
                style: TextStyle(
                  color: AdminPalette.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AdminSpacing.sm),
              Text(
                'Une photo d’agence, de chantier ou de matériel.',
                style: const TextStyle(color: AdminPalette.secondaryText),
              ),
              const SizedBox(height: AdminSpacing.md),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Prendre une photo'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choisir dans la galerie'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source != null) await _pickImage(source);
  }

  void _removePhoto() {
    setState(() {
      _image = null;
      _imageBytes = null;
      _removeImage = true;
      _error = null;
    });
  }

  Future<void> _selectDatePublication() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _datePublication,
      firstDate: DateTime(2020),
      lastDate: _today.add(const Duration(days: 730)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _datePublication = DateTime(picked.year, picked.month, picked.day);
      if (_dateFin.isBefore(_datePublication)) {
        _dateFin = _datePublication.add(const Duration(days: 30));
      }
      _error = null;
    });
  }

  Future<void> _selectDateFin() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFin,
      firstDate: _datePublication,
      lastDate: _datePublication.add(const Duration(days: 730)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateFin = DateTime(picked.year, picked.month, picked.day);
      _error = null;
    });
  }

  Future<void> _submit() async {
    final titre = _titreController.text.trim();
    final description = _descriptionController.text.trim();

    if (titre.isEmpty || description.isEmpty) {
      setState(() => _error = 'Le titre et la description sont requis.');
      return;
    }
    if (titre.length > maxActualiteTitre) {
      setState(() => _error = 'Le titre est trop long.');
      return;
    }
    if (description.length > maxActualiteDescription) {
      setState(() => _error = 'La description est trop longue.');
      return;
    }
    if (_dateFin.isBefore(_datePublication)) {
      setState(
        () =>
            _error = 'La date de fin doit être postérieure à la date de début.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final draft = ActualiteDraft(
      titre: titre,
      description: description,
      datePublication: _datePublication,
      dateFin: _dateFin,
      publiee: _publiee,
      epingle: _epingle,
      image: _image,
      removeImage: _removeImage,
      imageStoragePath: widget.initialImageStoragePath,
    );

    try {
      await widget.onSubmit(draft);
      if (mounted) {
        Navigator.of(context).pop(ActualiteEditorResult.saved(draft));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Enregistrement impossible : $error');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirmDelete() async {
    final onDelete = widget.onDelete;
    if (onDelete == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer l’actualité ?'),
        content: const Text(
          'La suppression est définitive : la carte disparaît de l’accueil.',
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
    if (confirmed != true || !mounted) return;

    setState(() {
      _isDeleting = true;
      _error = null;
    });
    try {
      await onDelete();
      if (mounted) {
        Navigator.of(context).pop(const ActualiteEditorResult.deleted());
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Suppression impossible : $error');
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.initial != null;

    return Container(
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                decoration: BoxDecoration(
                  color: AdminPalette.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            _buildHeader(isEditing),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AdminSpacing.lg,
                  AdminSpacing.md,
                  AdminSpacing.lg,
                  MediaQuery.viewInsetsOf(context).bottom + AdminSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPreview(),
                    const SizedBox(height: AdminSpacing.lg),
                    _buildTitreField(),
                    const SizedBox(height: AdminSpacing.md),
                    _buildDescriptionField(),
                    const SizedBox(height: AdminSpacing.md),
                    _buildPhotoRow(),
                    const SizedBox(height: AdminSpacing.md),
                    _buildDateField(
                      label: 'Début de publication',
                      value: _datePublication,
                      fieldKey: const ValueKey('actualite-editor-date-debut'),
                      onTap: _selectDatePublication,
                    ),
                    const SizedBox(height: AdminSpacing.md),
                    _buildDateField(
                      label: 'Fin de publication',
                      value: _dateFin,
                      fieldKey: const ValueKey('actualite-editor-date-fin'),
                      onTap: _selectDateFin,
                    ),
                    const SizedBox(height: AdminSpacing.sm),
                    _buildSwitchRow(
                      key: const ValueKey('actualite-editor-pin-row'),
                      switchKey: const ValueKey('actualite-editor-pin'),
                      label: 'Épingler sur l’accueil',
                      value: _epingle,
                      onChanged: (value) => setState(() => _epingle = value),
                    ),
                    _buildSwitchRow(
                      key: const ValueKey('actualite-editor-publish-row'),
                      switchKey: const ValueKey('actualite-editor-publish'),
                      label: 'Publiée',
                      value: _publiee,
                      onChanged: (value) => setState(() => _publiee = value),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) _buildError(),
            _buildFooter(isEditing),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isEditing) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AdminSpacing.lg,
        0,
        AdminSpacing.sm,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Modifier l’actualité' : 'Nouvelle actualité',
                  style: const TextStyle(
                    color: AdminPalette.primaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                if (isEditing) ...[
                  const SizedBox(height: 4),
                  Text(
                    'ACT-${widget.initial!.id}',
                    style: adminMonoStyle(context, size: 11),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('actualite-editor-close'),
            onPressed: _isBusy ? null : () => Navigator.of(context).maybePop(),
            tooltip: 'Fermer',
            icon: const Icon(Icons.close),
            color: AdminPalette.secondaryText,
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final titre = _titreController.text.trim();
    final description = _descriptionController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sur l’accueil', style: adminMonoStyle(context, size: 11)),
        const SizedBox(height: AdminSpacing.sm),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F7),
            borderRadius: BorderRadius.circular(AdminRadii.card),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AdminRadii.field),
            child: ColoredBox(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 7,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildPreviewImage(),
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              formatActualitePeriode(
                                _datePublication,
                                _dateFin,
                              ),
                              style: const TextStyle(
                                color: Color(0xFF1D1D1F),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titre.isEmpty ? 'Titre de l’actualité' : titre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: titre.isEmpty
                                ? AdminPalette.tertiaryText
                                : const Color(0xFF1D1D1F),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF333333),
                              fontSize: 11,
                              height: 1.4,
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
        ),
      ],
    );
  }

  Widget _buildPreviewImage() {
    if (_imageBytes != null) {
      return Image.memory(
        _imageBytes!,
        fit: BoxFit.cover,
        semanticLabel: 'Photo choisie pour l’actualité',
      );
    }

    final url = _removeImage ? null : widget.initial?.imageUrl;
    if (url != null && url.trim().isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        semanticLabel: 'Photo actuelle de l’actualité',
        errorBuilder: (context, error, stackTrace) =>
            const ColoredBox(color: Color(0xFF1D1D1F)),
      );
    }

    return const ColoredBox(color: Color(0xFF1D1D1F));
  }

  Widget _buildTitreField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Titre',
          style: TextStyle(
            color: AdminPalette.primaryText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          key: const ValueKey('actualite-editor-titre'),
          controller: _titreController,
          maxLength: maxActualiteTitre,
          textInputAction: TextInputAction.next,
          decoration: _fieldDecoration('Nouvelle gamme de stations totales'),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(
            color: AdminPalette.primaryText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          key: const ValueKey('actualite-editor-description'),
          controller: _descriptionController,
          maxLength: maxActualiteDescription,
          maxLines: 4,
          decoration: _fieldDecoration(
            'Ce que le client doit retenir, en deux phrases.',
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoRow() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AdminPalette.surface,
        borderRadius: BorderRadius.circular(AdminRadii.field),
        border: Border.all(color: AdminPalette.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildPreviewImage(),
            ),
          ),
          const SizedBox(width: AdminSpacing.md),
          Expanded(
            child: Text(
              _image?.name ?? (_hasImage ? 'Photo en place' : 'Aucune photo'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AdminPalette.secondaryText,
                fontSize: 12,
              ),
            ),
          ),
          TextButton(
            key: const ValueKey('actualite-editor-image'),
            onPressed: _isBusy || _isPickingImage ? null : _chooseImageSource,
            style: TextButton.styleFrom(
              foregroundColor: AdminPalette.blueprintBlue,
            ),
            child: Text(_hasImage ? 'Remplacer' : 'Ajouter'),
          ),
          if (_hasImage)
            IconButton(
              key: const ValueKey('actualite-editor-remove-image'),
              onPressed: _isBusy ? null : _removePhoto,
              tooltip: 'Retirer la photo',
              icon: const Icon(Icons.close),
              iconSize: 18,
              color: AdminPalette.secondaryText,
            ),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime value,
    required Key fieldKey,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AdminPalette.primaryText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        InkWell(
          key: fieldKey,
          onTap: _isBusy ? null : onTap,
          borderRadius: BorderRadius.circular(AdminRadii.field),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AdminRadii.field),
              border: Border.all(color: AdminPalette.border),
            ),
            child: Row(
              children: [
                Text(
                  formatActualiteDate(value),
                  style: const TextStyle(
                    color: AdminPalette.primaryText,
                    fontSize: 14,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 17,
                  color: AdminPalette.secondaryText,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchRow({
    required Key key,
    required Key switchKey,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      key: key,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AdminPalette.primaryText,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Switch(
          key: switchKey,
          value: value,
          onChanged: _isBusy ? null : onChanged,
        ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AdminSpacing.lg,
        0,
        AdminSpacing.lg,
        AdminSpacing.sm,
      ),
      padding: const EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: AdminPalette.destructiveRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AdminRadii.field),
        border: Border.all(
          color: AdminPalette.destructiveRed.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        _error!,
        style: const TextStyle(
          color: AdminPalette.destructiveRed,
          fontSize: 12,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildFooter(bool isEditing) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AdminSpacing.lg,
        AdminSpacing.md,
        AdminSpacing.lg,
        AdminSpacing.md,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AdminPalette.border)),
      ),
      child: Row(
        children: [
          if (isEditing && widget.onDelete != null)
            TextButton.icon(
              key: const ValueKey('actualite-editor-delete'),
              onPressed: _isBusy ? null : _confirmDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Supprimer'),
              style: TextButton.styleFrom(
                foregroundColor: AdminPalette.destructiveRed,
              ),
            ),
          const Spacer(),
          TextButton(
            onPressed: _isBusy ? null : () => Navigator.of(context).maybePop(),
            style: TextButton.styleFrom(
              foregroundColor: AdminPalette.secondaryText,
            ),
            child: const Text('Annuler'),
          ),
          const SizedBox(width: AdminSpacing.sm),
          FilledButton(
            key: const ValueKey('actualite-editor-submit'),
            onPressed: _isBusy ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AdminPalette.blueprintBlue,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AdminRadii.field),
      borderSide: const BorderSide(color: AdminPalette.border),
    );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: AdminPalette.tertiaryText,
        fontSize: 13,
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      counterStyle: const TextStyle(
        color: AdminPalette.secondaryText,
        fontSize: 11,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: AdminPalette.blueprintBlue),
      ),
    );
  }
}
