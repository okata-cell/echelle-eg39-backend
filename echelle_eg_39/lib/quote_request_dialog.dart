import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _quoteBlue = Color(0xFF2563EB);
const _quoteInk = Color(0xFF111827);
const _quoteMuted = Color(0xFF6B7280);
const _quoteSurface = Color(0xFFF9FAFB);
const _quoteBorder = Color(0xFFE5E7EB);
const _quoteError = Color(0xFFB42318);
const _quoteErrorSurface = Color(0xFFFEF3F2);
const _quoteRadius = 12.0;
const _quoteFieldRadius = 10.0;

/// Builds the required backend name from the authenticated customer's profile.
///
/// Name and email are intentionally not requested again in the quote form.
String quoteRequestNameFromProfile(Map<String, dynamic> profile) {
  return [profile['firstName'], profile['lastName']]
      .map((part) => part?.toString().trim() ?? '')
      .where((part) => part.isNotEmpty)
      .join(' ');
}

class QuoteRequestData {
  const QuoteRequestData({
    required this.description,
    required this.telephone,
    required this.requesterName,
  });

  final String description;
  final String telephone;
  final String requesterName;
}

typedef QuoteRequestSubmit = Future<void> Function(QuoteRequestData request);

/// Responsive quote form for a topographic service.
class QuoteRequestDialog extends StatefulWidget {
  const QuoteRequestDialog({
    super.key,
    required this.serviceName,
    required this.requesterName,
    required this.categoryColor,
    required this.onSubmit,
    this.initialTelephone = '',
  });

  final String serviceName;
  final String requesterName;
  final Color categoryColor;
  final QuoteRequestSubmit onSubmit;
  final String initialTelephone;

  @override
  State<QuoteRequestDialog> createState() => _QuoteRequestDialogState();
}

class _QuoteRequestDialogState extends State<QuoteRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  late final TextEditingController _telephoneController = TextEditingController(
    text: widget.initialTelephone,
  );

  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _descriptionController.dispose();
    _telephoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await widget.onSubmit(
        QuoteRequestData(
          description: _descriptionController.text.trim(),
          telephone: _telephoneController.text.trim(),
          requesterName: widget.requesterName,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        final message = error.toString().replaceFirst('Exception: ', '').trim();
        setState(() => _error = 'Envoi impossible. $message');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    bool alignLabelWithHint = false,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(_quoteFieldRadius),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.poppins(
        color: _quoteMuted.withValues(alpha: 0.8),
        fontSize: 13,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(icon, color: _quoteMuted, size: 20),
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: _quoteSurface,
      border: border(_quoteBorder),
      enabledBorder: border(_quoteBorder),
      focusedBorder: border(_quoteBlue, 1.8),
      errorBorder: border(_quoteError),
      focusedErrorBorder: border(_quoteError, 1.8),
      contentPadding: const EdgeInsets.all(16),
    );
  }

  Widget _sectionHeading(String title, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              color: _quoteInk,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            detail,
            style: GoogleFonts.poppins(
              color: _quoteMuted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 12, 18),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: widget.categoryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(_quoteRadius),
                    ),
                    child: Icon(
                      Icons.map_outlined,
                      color: widget.categoryColor,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Demande de devis',
                          style: GoogleFonts.poppins(
                            color: _quoteInk,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.serviceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: _quoteMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                    color: _quoteMuted,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _quoteBorder),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeading(
                        'Description du projet *',
                        'Précisez le terrain, les mesures ou le résultat attendu.',
                      ),
                      TextFormField(
                        key: const ValueKey('quote-description'),
                        controller: _descriptionController,
                        enabled: !_isSubmitting,
                        minLines: 4,
                        maxLines: 5,
                        maxLength: 600,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'La description est requise';
                          }
                          if (value.trim().length < 10) {
                            return 'Décrivez votre projet en détail (min. 10 caractères)';
                          }
                          return null;
                        },
                        decoration: _inputDecoration(
                          hintText: 'Décrivez votre projet en détail…',
                          icon: Icons.notes_rounded,
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _sectionHeading(
                        'Téléphone *',
                        'Nous utiliserons ce numéro pour vous recontacter.',
                      ),
                      TextFormField(
                        key: const ValueKey('quote-telephone'),
                        controller: _telephoneController,
                        enabled: !_isSubmitting,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Le téléphone est requis';
                          }
                          return null;
                        },
                        decoration: _inputDecoration(
                          hintText: 'Ex. : +228 90 12 34 56',
                          icon: Icons.phone_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 15,
                            color: _quoteMuted,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              'Votre demande sera associée à votre compte client.',
                              style: GoogleFonts.poppins(
                                color: _quoteMuted,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _quoteErrorSurface,
                              borderRadius: BorderRadius.circular(
                                _quoteFieldRadius,
                              ),
                              border: Border.all(
                                color: _quoteError.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  size: 18,
                                  color: _quoteError,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: GoogleFonts.poppins(
                                      color: _quoteError,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: _quoteBorder),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('quote-cancel-button'),
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _quoteMuted,
                        side: const BorderSide(color: _quoteBorder),
                        minimumSize: const Size(0, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            _quoteFieldRadius,
                          ),
                        ),
                      ),
                      child: Text(
                        'Annuler',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      key: const ValueKey('quote-submit-button'),
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _quoteBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 50),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            _quoteFieldRadius,
                          ),
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
                          : const Icon(Icons.send_rounded, size: 17),
                      label: Text(
                        _isSubmitting ? 'Envoi…' : 'Envoyer',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
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
}
