// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api_service.dart';
import '../appareil_images.dart';
import '../data_manager.dart';
import 'admin_tokens.dart';

/// Bornes reprises à l'identique du formulaire précédent : mêmes contrôles,
/// donc mêmes messages côté administrateur.
const int maxAppareilPhotoBytes = 5 * 1024 * 1024;
const int maxAppareilPrix = 999999999;
const int minAppareilTexte = 2;

typedef AppareilImagePicker = Future<XFile?> Function(ImageSource source);

/// Téléverse la photo et renvoie l'URL publique à enregistrer.
typedef AppareilImageUploader = Future<String> Function(XFile image);

/// Règles de saisie des prix : chiffres uniquement, strictement positifs.
String? validateAppareilPrix(String? value, String champ) {
  final clean = value?.trim() ?? '';
  if (clean.isEmpty) return 'Le $champ est requis';
  if (!RegExp(r'^[0-9]+$').hasMatch(clean)) {
    return 'Le $champ doit contenir uniquement des chiffres';
  }
  final nombre = int.tryParse(clean);
  if (nombre == null) return 'Le $champ n\'est pas valide';
  if (nombre <= 0) return 'Le $champ doit être supérieur à 0';
  if (nombre > maxAppareilPrix) return 'Le $champ est trop élevé';
  return null;
}

/// Ce que la feuille renvoie à l'écran admin, avant tout appel réseau.
///
/// Les champs correspondent exactement à ceux acceptés par
/// `POST /api/appareils` et `PUT /api/appareils/:id` : nom, type, prix et
/// `imageUrl`. Aucun champ nouveau n'est introduit.
class AppareilDraft {
  const AppareilDraft({
    required this.nom,
    required this.type,
    required this.prixLocation,
    required this.prixVente,
    this.imageUrl,
  });

  final String nom;
  final String type;
  final int prixLocation;
  final int prixVente;

  /// URL de la photo, saisie ou issue du téléversement. `null` laisse le
  /// visuel par défaut du type s'afficher côté client.
  final String? imageUrl;
}

/// Formulaire de création ou de modification d'un appareil.
///
/// Même parti pris que la feuille « Nouvelle actualité » : la carte du
/// catalogue est montrée en haut, l'administrateur règle l'appareil en la
/// regardant, et la photo peut venir de l'appareil photo ou de la galerie.
class AppareilEditorSheet extends StatefulWidget {
  const AppareilEditorSheet({
    super.key,
    this.initial,
    required this.onSubmit,
    this.pickImage,
    this.uploadImage,
  });

  final Appareil? initial;
  final Future<void> Function(AppareilDraft draft) onSubmit;
  final AppareilImagePicker? pickImage;
  final AppareilImageUploader? uploadImage;

  static Future<bool?> show(
    BuildContext context, {
    Appareil? initial,
    required Future<void> Function(AppareilDraft draft) onSubmit,
    AppareilImagePicker? pickImage,
    AppareilImageUploader? uploadImage,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Même précaution que la feuille des actualités : la modale ne se
      // décale pas seule, donc on réserve la hauteur du clavier pour que le
      // bouton d'enregistrement reste atteignable.
      builder: (sheetContext) => AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: FractionallySizedBox(
          heightFactor: 0.94,
          child: AppareilEditorSheet(
            initial: initial,
            onSubmit: onSubmit,
            pickImage: pickImage,
            uploadImage: uploadImage,
          ),
        ),
      ),
    );
  }

  @override
  State<AppareilEditorSheet> createState() => _AppareilEditorSheetState();
}

class _AppareilEditorSheetState extends State<AppareilEditorSheet> {
  late final TextEditingController _nomController = TextEditingController(
    text: widget.initial?.nom ?? '',
  )..addListener(_onFieldChanged);
  late final TextEditingController _typeController = TextEditingController(
    text: widget.initial?.type ?? '',
  )..addListener(_onFieldChanged);
  late final TextEditingController _prixLocationController =
      TextEditingController(text: widget.initial?.prixLocation.toString() ?? '')
        ..addListener(_onFieldChanged);
  late final TextEditingController _prixVenteController = TextEditingController(
    text: widget.initial?.prixVente.toString() ?? '',
  )..addListener(_onFieldChanged);
  late final TextEditingController _imageUrlController = TextEditingController(
    text: widget.initial?.imageUrl ?? '',
  )..addListener(_onFieldChanged);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _photoBytes;
  String? _photoName;
  bool _isPicking = false;
  bool _isSubmitting = false;
  String? _error;

  bool get _isBusy => _isSubmitting || _isPicking;

  @override
  void dispose() {
    _nomController.dispose();
    _typeController.dispose();
    _prixLocationController.dispose();
    _prixVenteController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (_error == null) {
      setState(() {});
      return;
    }
    setState(() => _error = null);
  }

  /// Visuel montré dans l'aperçu : la photo choisie, l'URL saisie, sinon le
  /// visuel par défaut du type — exactement la règle appliquée côté client.
  String? get _previewUrl {
    final url = _imageUrlController.text.trim();
    if (url.isNotEmpty) return url;
    final type = _typeController.text.trim();
    if (type.isEmpty) return null;
    return AppareilImages.getImageUrlForType(type);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_isBusy) return;
    setState(() {
      _isPicking = true;
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
      if (bytes.length > maxAppareilPhotoBytes) {
        setState(() => _error = 'La photo doit faire 5 Mo maximum.');
        return;
      }

      final extension = picked.name.split('.').last.toLowerCase();
      final mimeType = picked.mimeType?.toLowerCase();
      final extensionAcceptee = [
        'jpg',
        'jpeg',
        'png',
        'webp',
      ].contains(extension);
      final mimeAccepte = [
        'image/jpeg',
        'image/png',
        'image/webp',
      ].contains(mimeType);
      if (!extensionAcceptee && !mimeAccepte) {
        setState(() => _error = 'Choisissez une image JPEG, PNG ou WebP.');
        return;
      }

      final imageUrl = await _upload(picked);
      if (!mounted) return;
      final nomFichier = picked.name.trim();
      setState(() {
        _photoBytes = bytes;
        // Certaines sources ne fournissent pas de nom : la légende retombe
        // alors sur l'état générique plutôt que sur une ligne vide.
        _photoName = nomFichier.isEmpty ? null : nomFichier;
        _imageUrlController.text = imageUrl;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Téléversement impossible : $error');
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  /// L'API appareils n'accepte qu'une URL d'image, pas un fichier : la photo
  /// passe par le téléversement Cloudinary déjà en place, puis son URL prend
  /// le chemin habituel du champ `imageUrl`.
  Future<String> _upload(XFile image) async {
    final uploader = widget.uploadImage;
    if (uploader != null) return uploader(image);

    final uploaded = await ApiService.uploadActualiteImage(image);
    final url = uploaded['imageUrl']?.toString().trim() ?? '';
    if (url.isEmpty) {
      throw Exception('Le serveur n’a pas renvoyé l’adresse de la photo.');
    }
    return url;
  }

  Future<void> _submit() async {
    if (_isBusy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final imageUrl = _imageUrlController.text.trim();
    final draft = AppareilDraft(
      nom: _nomController.text.trim(),
      type: _typeController.text.trim(),
      prixLocation: int.parse(_prixLocationController.text.trim()),
      prixVente: int.parse(_prixVenteController.text.trim()),
      imageUrl: imageUrl.isEmpty ? null : imageUrl,
    );

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await widget.onSubmit(draft);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Enregistrement impossible : $error');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
                padding: const EdgeInsets.fromLTRB(
                  AdminSpacing.lg,
                  AdminSpacing.md,
                  AdminSpacing.lg,
                  AdminSpacing.lg,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildPreview(),
                      const SizedBox(height: AdminSpacing.lg),
                      _buildTextField(
                        label: 'Nom de l’appareil',
                        controller: _nomController,
                        hint: 'Station totale Leica TS06',
                        fieldKey: const ValueKey('appareil-editor-nom'),
                        validator: (value) {
                          final clean = value?.trim() ?? '';
                          if (clean.isEmpty) {
                            return 'Le nom de l\'appareil est requis';
                          }
                          if (clean.length < minAppareilTexte) {
                            return 'Le nom doit contenir au moins 2 caractères';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AdminSpacing.md),
                      _buildTextField(
                        label: 'Type',
                        controller: _typeController,
                        hint: 'GPS, Niveau, Station totale, Trépied, Mire…',
                        fieldKey: const ValueKey('appareil-editor-type'),
                        textCapitalization: TextCapitalization.sentences,
                        validator: (value) {
                          final clean = value?.trim() ?? '';
                          if (clean.isEmpty) {
                            return 'Le type d\'appareil est requis';
                          }
                          if (clean.length < minAppareilTexte) {
                            return 'Le type doit contenir au moins 2 caractères';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AdminSpacing.sm),
                      _buildTypeSuggestions(),
                      const SizedBox(height: AdminSpacing.md),
                      _buildPhotoBlock(),
                      const SizedBox(height: AdminSpacing.md),
                      _buildTextField(
                        label: 'URL de l’image (optionnel)',
                        controller: _imageUrlController,
                        hint: 'https://…jpg',
                        fieldKey: const ValueKey('appareil-editor-url'),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Laissez vide pour garder le visuel du type d’appareil.',
                        style: TextStyle(
                          color: AdminPalette.tertiaryText,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: AdminSpacing.md),
                      _buildTextField(
                        label: 'Prix de location par jour (FCFA)',
                        controller: _prixLocationController,
                        hint: '25000',
                        fieldKey: const ValueKey(
                          'appareil-editor-prix-location',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) =>
                            validateAppareilPrix(value, 'prix de location'),
                      ),
                      const SizedBox(height: AdminSpacing.md),
                      _buildTextField(
                        label: 'Prix de vente (FCFA)',
                        controller: _prixVenteController,
                        hint: '2500000',
                        fieldKey: const ValueKey('appareil-editor-prix-vente'),
                        keyboardType: TextInputType.number,
                        validator: (value) =>
                            validateAppareilPrix(value, 'prix de vente'),
                      ),
                    ],
                  ),
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
                  isEditing ? 'Modifier l’appareil' : 'Nouvel appareil',
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
                    widget.initial!.id,
                    style: adminMonoStyle(context, size: 11),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('appareil-editor-close'),
            onPressed: _isBusy ? null : () => Navigator.of(context).maybePop(),
            tooltip: 'Fermer',
            icon: const Icon(Icons.close),
            color: AdminPalette.secondaryText,
          ),
        ],
      ),
    );
  }

  /// Aperçu de la carte du catalogue : photo, type, nom et tarifs.
  Widget _buildPreview() {
    final nom = _nomController.text.trim();
    final type = _typeController.text.trim();
    final location = int.tryParse(_prixLocationController.text.trim());
    final vente = int.tryParse(_prixVenteController.text.trim());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sur le catalogue', style: adminMonoStyle(context, size: 11)),
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
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildPreviewImage(),
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.initial?.id ??
                                  (type.isEmpty ? 'Nouveau' : type),
                              style: const TextStyle(
                                color: Color(0xFF1D1D1F),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
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
                          nom.isEmpty ? 'Nom de l’appareil' : nom,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: nom.isEmpty
                                ? AdminPalette.tertiaryText
                                : const Color(0xFF1D1D1F),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                        if (type.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            type,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF333333),
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _pricePill(
                              icon: Icons.schedule,
                              label: formatAppareilPrix(
                                location,
                                suffixe: '/ j',
                              ),
                            ),
                            _pricePill(
                              icon: Icons.sell_outlined,
                              label: formatAppareilPrix(vente),
                            ),
                          ],
                        ),
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

  Widget _pricePill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AdminPalette.secondaryText),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1D1D1F),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewImage() {
    if (_photoBytes != null) {
      return Image.memory(
        _photoBytes!,
        fit: BoxFit.cover,
        semanticLabel: 'Photo choisie pour l’appareil',
      );
    }

    final url = _previewUrl;
    if (url != null && url.trim().isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        semanticLabel: 'Visuel de l’appareil',
        errorBuilder: (context, error, stackTrace) =>
            const ColoredBox(color: Color(0xFF1D1D1F)),
      );
    }

    return const ColoredBox(color: Color(0xFF1D1D1F));
  }

  Widget _buildTypeSuggestions() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final type in _typesCourants)
          ActionChip(
            key: ValueKey('appareil-editor-type-$type'),
            label: Text(type),
            onPressed: _isBusy
                ? null
                : () => setState(() => _typeController.text = type),
            labelStyle: const TextStyle(
              color: AdminPalette.secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            backgroundColor: AdminPalette.mutedSurface,
            side: const BorderSide(color: AdminPalette.border),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
      ],
    );
  }

  /// Bloc photo : vignette, prise de vue et galerie, puis état du fichier.
  Widget _buildPhotoBlock() {
    final String legende;
    if (_photoName != null) {
      legende = _photoName!;
    } else if (widget.initial != null &&
        widget.initial!.imageUrl.trim().isNotEmpty) {
      legende = 'Photo en place';
    } else {
      legende = 'Aucune photo : visuel du type';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Photo de l’appareil',
          style: TextStyle(
            color: AdminPalette.primaryText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AdminPalette.surface,
            borderRadius: BorderRadius.circular(AdminRadii.field),
            border: Border.all(color: AdminPalette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildPreviewImage(),
                    ),
                  ),
                  const SizedBox(width: AdminSpacing.md),
                  Expanded(
                    child: Text(
                      legende,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AdminPalette.secondaryText,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                  if (_isPicking)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: AdminSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('appareil-editor-photo-camera'),
                      onPressed: _isBusy
                          ? null
                          : () => _pickPhoto(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Prendre une photo'),
                      style: _photoButtonStyle(),
                    ),
                  ),
                  const SizedBox(width: AdminSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('appareil-editor-photo-galerie'),
                      onPressed: _isBusy
                          ? null
                          : () => _pickPhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Galerie'),
                      style: _photoButtonStyle(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  ButtonStyle _photoButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: AdminPalette.blueprintBlue,
      side: const BorderSide(color: AdminPalette.border),
      minimumSize: const Size(0, 42),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required Key fieldKey,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
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
        TextFormField(
          key: fieldKey,
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          validator: validator,
          decoration: _fieldDecoration(hint),
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
          Expanded(
            child: Text(
              isEditing
                  ? 'Les tarifs et la photo sont mis à jour dans le catalogue.'
                  : 'L’appareil rejoint le catalogue dès l’enregistrement.',
              style: TextStyle(
                color: AdminPalette.tertiaryText,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: AdminSpacing.sm),
          TextButton(
            onPressed: _isBusy ? null : () => Navigator.of(context).maybePop(),
            style: TextButton.styleFrom(
              foregroundColor: AdminPalette.secondaryText,
            ),
            child: const Text('Annuler'),
          ),
          const SizedBox(width: AdminSpacing.xs),
          FilledButton(
            key: const ValueKey('appareil-editor-submit'),
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
                : Text(isEditing ? 'Enregistrer' : 'Ajouter'),
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
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: AdminPalette.blueprintBlue),
      ),
      errorStyle: const TextStyle(
        color: AdminPalette.destructiveRed,
        fontSize: 11,
        height: 1.3,
      ),
    );
  }

  static const List<String> _typesCourants = <String>[
    'GPS',
    'Niveau',
    'Station totale',
    'Trépied',
    'Mire',
  ];
}

/// « 25 000 FCFA » : espace fine insécable comme séparateur de milliers.
String formatAppareilPrix(int? valeur, {String suffixe = ''}) {
  if (valeur == null) return '— FCFA';
  final chiffres = valeur.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < chiffres.length; index++) {
    if (index > 0 && (chiffres.length - index) % 3 == 0) {
      buffer.write('\u202F');
    }
    buffer.write(chiffres[index]);
  }
  final montant = '${buffer.toString()} FCFA';
  return suffixe.isEmpty ? montant : '$montant $suffixe';
}
