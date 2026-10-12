import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'admin_tokens.dart';

const int maxPromotionImageBytes = 5 * 1024 * 1024;

typedef PromotionImagePicker = Future<XFile?> Function(ImageSource source);
typedef PromotionSubmitHandler = Future<void> Function(PromotionDraft draft);

class PromotionDraft {
  const PromotionDraft({
    required this.description,
    required this.image,
    required this.startDate,
    required this.endDate,
    required this.active,
    required this.frequency,
  });

  final String description;
  final XFile? image;
  final DateTime startDate;
  final DateTime endDate;
  final bool active;
  final String frequency;
}

class PromotionEditorDialog extends StatefulWidget {
  const PromotionEditorDialog({
    super.key,
    required this.onSubmit,
    this.pickImage,
    this.now,
  });

  final PromotionSubmitHandler onSubmit;
  final PromotionImagePicker? pickImage;
  final DateTime Function()? now;

  @override
  State<PromotionEditorDialog> createState() => _PromotionEditorDialogState();
}

class _PromotionEditorDialogState extends State<PromotionEditorDialog> {
  final _descriptionController = TextEditingController();
  final _imagePicker = ImagePicker();

  DateTime? _startDate;
  DateTime? _endDate;
  XFile? _image;
  Uint8List? _imageBytes;
  String _frequency = 'chaque_ouverture';
  bool _active = true;
  bool _isSubmitting = false;
  bool _isPickingImage = false;
  String? _error;

  DateTime get _today {
    final date = widget.now?.call() ?? DateTime.now();
    return DateTime(date.year, date.month, date.day);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isSubmitting || _isPickingImage) return;
    setState(() {
      _isPickingImage = true;
      _error = null;
    });

    try {
      final picked = widget.pickImage != null
          ? await widget.pickImage!(source)
          : await _imagePicker.pickImage(
              source: source,
              maxWidth: 1600,
              maxHeight: 1600,
              imageQuality: 82,
            );
      if (!mounted || picked == null) return;

      final imageBytes = await picked.readAsBytes();
      if (imageBytes.length > maxPromotionImageBytes) {
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
        _imageBytes = imageBytes;
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
                'Ajouter un visuel',
                style: TextStyle(
                  color: AdminPalette.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AdminSpacing.sm),
              Text(
                'Choisissez une photo claire qui présente votre offre.',
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

  Future<DateTime?> _showDatePicker({
    required DateTime initialDate,
    required DateTime firstDate,
  }) {
    return showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
      firstDate: firstDate,
      lastDate: _today.add(const Duration(days: 730)),
    );
  }

  Future<void> _selectStartDate() async {
    final picked = await _showDatePicker(
      initialDate: _startDate ?? _today,
      firstDate: _today,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startDate = DateTime(picked.year, picked.month, picked.day);
      if (_endDate != null && _endDate!.isBefore(_startDate!)) {
        _endDate = _startDate;
      }
      _error = null;
    });
  }

  Future<void> _selectEndDate() async {
    final picked = await _showDatePicker(
      initialDate: _endDate ?? _startDate ?? _today,
      firstDate: _startDate ?? _today,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _endDate = DateTime(picked.year, picked.month, picked.day);
      _error = null;
    });
  }

  Future<void> _submit() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty || _startDate == null || _endDate == null) {
      setState(
        () => _error =
            'Ajoutez une description et choisissez les dates de l’offre.',
      );
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      setState(
        () => _error = 'La date de fin doit être après la date de début.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        PromotionDraft(
          description: description,
          image: _image,
          startDate: _startDate!,
          endDate: _endDate!,
          active: _active,
          frequency: _frequency,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Création impossible : $error');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Choisir une date';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _sectionHeading(String title, {String? detail}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AdminSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AdminPalette.primaryText,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: AdminSpacing.xs),
            Text(
              detail,
              style: const TextStyle(
                color: AdminPalette.secondaryText,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      backgroundColor: AdminPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminRadii.sheet),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AdminSpacing.xl,
                AdminSpacing.lg,
                AdminSpacing.md,
                AdminSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Créer une promotion',
                          style: TextStyle(
                            color: AdminPalette.primaryText,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AdminSpacing.xs),
                        Text(
                          'Préparez le visuel et la période de diffusion.',
                          style: const TextStyle(
                            color: AdminPalette.secondaryText,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close),
                    color: AdminPalette.secondaryText,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AdminPalette.border),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AdminSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeading(
                      'Visuel de la promotion',
                      detail:
                          'Image JPEG, PNG ou WebP · 5 Mo maximum · facultative',
                    ),
                    _buildImagePicker(),
                    const SizedBox(height: AdminSpacing.xl),
                    _sectionHeading('Message'),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AdminSpacing.md,
                        vertical: AdminSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AdminPalette.blueprintBlue.withValues(
                          alpha: 0.08,
                        ),
                        borderRadius: BorderRadius.circular(AdminRadii.field),
                        border: Border.all(
                          color: AdminPalette.blueprintBlue.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.campaign_outlined,
                            color: AdminPalette.blueprintBlue,
                            size: 18,
                          ),
                          SizedBox(width: AdminSpacing.sm),
                          Text(
                            'OFFRE DU MOMENT',
                            style: TextStyle(
                              color: AdminPalette.blueprintBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AdminSpacing.md),
                    TextField(
                      controller: _descriptionController,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: 600,
                      enabled: !_isSubmitting,
                      onChanged: (_) => setState(() => _error = null),
                      decoration: _inputDecoration(
                        label: 'Description de la promotion',
                        hint:
                            'Ex. : remise spéciale sur les équipements de topographie…',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: AdminSpacing.xl),
                    _sectionHeading('Période de diffusion'),
                    Row(
                      children: [
                        Expanded(
                          child: _dateButton(
                            'Début de l’offre',
                            _startDate,
                            _selectStartDate,
                          ),
                        ),
                        const SizedBox(width: AdminSpacing.sm),
                        Expanded(
                          child: _dateButton(
                            'Fin de l’offre',
                            _endDate,
                            _selectEndDate,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AdminSpacing.lg),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Afficher automatiquement',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'La promotion apparaîtra dans l’application pendant sa période de validité.',
                      ),
                      value: _active,
                      onChanged: _isSubmitting
                          ? null
                          : (value) => setState(() => _active = value),
                    ),
                    const SizedBox(height: AdminSpacing.sm),
                    _sectionHeading('Fréquence d’affichage'),
                    RadioGroup<String>(
                      groupValue: _frequency,
                      onChanged: (value) {
                        if (_isSubmitting || value == null) return;
                        setState(() => _frequency = value);
                      },
                      child: const Column(
                        children: [
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text('À chaque ouverture'),
                            value: 'chaque_ouverture',
                          ),
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text('Une fois par jour'),
                            value: 'une_fois_par_jour',
                          ),
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text('Une seule fois'),
                            value: 'une_seule_fois',
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AdminSpacing.md),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AdminSpacing.md),
                        decoration: BoxDecoration(
                          color: AdminPalette.destructiveRed.withValues(
                            alpha: 0.08,
                          ),
                          borderRadius: BorderRadius.circular(AdminRadii.field),
                          border: Border.all(
                            color: AdminPalette.destructiveRed.withValues(
                              alpha: 0.25,
                            ),
                          ),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: AdminPalette.destructiveRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AdminPalette.border),
            Padding(
              padding: const EdgeInsets.all(AdminSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AdminPalette.secondaryText,
                        side: const BorderSide(color: AdminPalette.border),
                        minimumSize: const Size(0, 48),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: AdminSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting || _isPickingImage
                          ? null
                          : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminPalette.blueprintBlue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AdminRadii.field),
                        ),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.campaign_outlined, size: 18),
                      label: Text(
                        _isSubmitting ? 'Création…' : 'Créer la promotion',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AdminPalette.mutedSurface,
        borderRadius: BorderRadius.circular(AdminRadii.card),
        border: Border.all(color: AdminPalette.border),
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 8,
            child: _imageBytes == null
                ? const Center(
                    child: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: AdminPalette.tertiaryText,
                      size: 42,
                    ),
                  )
                : Image.memory(_imageBytes!, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(AdminSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting || _isPickingImage
                        ? null
                        : _chooseImageSource,
                    icon: _isPickingImage
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_camera_outlined, size: 18),
                    label: Text(
                      _image == null ? 'Ajouter une photo' : 'Remplacer',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AdminPalette.blueprintBlue,
                      side: const BorderSide(color: AdminPalette.blueprintBlue),
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ),
                if (_image != null) ...[
                  const SizedBox(width: AdminSpacing.xs),
                  IconButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => setState(() {
                            _image = null;
                            _imageBytes = null;
                          }),
                    tooltip: 'Retirer la photo',
                    icon: const Icon(Icons.delete_outline),
                    color: AdminPalette.destructiveRed,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateButton(String label, DateTime? date, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: _isSubmitting ? null : onTap,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(
          horizontal: AdminSpacing.md,
          vertical: AdminSpacing.md,
        ),
        side: const BorderSide(color: AdminPalette.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminRadii.field),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AdminPalette.secondaryText,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AdminSpacing.xs),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 15),
              const SizedBox(width: AdminSpacing.xs),
              Expanded(
                child: Text(
                  _formatDate(date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AdminPalette.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    bool alignLabelWithHint = false,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdminRadii.field),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: AdminPalette.surface,
      border: border(AdminPalette.border),
      enabledBorder: border(AdminPalette.border),
      focusedBorder: border(AdminPalette.blueprintBlue, 2),
      contentPadding: const EdgeInsets.all(AdminSpacing.md),
    );
  }
}
