import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'promotion_frequency_policy.dart';

class PromotionPopup {
  static bool _isShowing = false;

  /// Checks the public campaign endpoint once the client home is ready.
  static Future<void> checkAndShowPromotion(
    BuildContext context, {
    Future<Map<String, dynamic>?> Function()? loadPromotion,
    DateTime Function()? now,
    Set<String>? sessionShownIds,
  }) async {
    if (_isShowing || !context.mounted) return;
    _isShowing = true;

    try {
      final loader = loadPromotion ?? ApiService.getActivePromotion;
      final promotion = await loader();
      if (promotion == null || !context.mounted) return;

      final promotionId = promotion['id']?.toString().trim() ?? '';
      final frequency =
          promotion['frequence']?.toString() ?? 'chaque_ouverture';
      if (promotionId.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final displayedAt = now?.call() ?? DateTime.now();
      final policy = PromotionFrequencyPolicy(
        preferences: prefs,
        sessionShownIds: sessionShownIds,
      );
      if (!await policy.shouldShow(
        promotionId: promotionId,
        frequency: frequency,
        now: displayedAt,
      )) {
        return;
      }
      if (!context.mounted) return;

      await _showPromotionDialog(context, promotion);
      await policy.recordShown(
        promotionId: promotionId,
        frequency: frequency,
        now: displayedAt,
      );
    } catch (error) {
      debugPrint('Erreur vérification promotion: $error');
    } finally {
      _isShowing = false;
    }
  }

  static Future<void> _showPromotionDialog(
    BuildContext context,
    Map<String, dynamic> promotion,
  ) async {
    final title = promotion['titre']?.toString().trim().isNotEmpty == true
        ? promotion['titre'].toString().trim()
        : 'Offre du moment';
    final description = promotion['description']?.toString().trim() ?? '';
    final imageUrl =
        (promotion['image_url'] ?? promotion['imageUrl'])?.toString().trim() ??
        '';
    final startDate = _formatDate(promotion['date_debut']?.toString());
    final endDate = _formatDate(promotion['date_fin']?.toString());
    final screenHeight = MediaQuery.sizeOf(context).height;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 440,
            maxHeight: screenHeight * 0.86,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Material(
              color: const Color(0xFFFFFFFF),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: (screenHeight * 0.28).clamp(150.0, 240.0),
                        child: imageUrl.isEmpty
                            ? const _PromotionImageFallback()
                            : Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const _PromotionImageFallback(
                                    isLoading: true,
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) =>
                                    const _PromotionImageFallback(),
                              ),
                      ),
                      Positioned(
                        left: 18,
                        top: 18,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xE62563EB),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            'PROMOTION',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Semantics(
                          button: true,
                          label: 'Fermer la promotion',
                          child: IconButton.filledTonal(
                            tooltip: 'Fermer',
                            onPressed: () => Navigator.pop(dialogContext),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.94,
                              ),
                              foregroundColor: const Color(0xFF111827),
                            ),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF111827),
                              fontSize: 22,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              description,
                              textAlign: TextAlign.left,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF4B5563),
                                fontSize: 14,
                                height: 1.6,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (startDate != null && endDate != null) ...[
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFDBEAFE),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.event_available_outlined,
                                    color: Color(0xFF2563EB),
                                    size: 17,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Du $startDate au $endDate',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF1D4ED8),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 52),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'J’ai compris',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String? _formatDate(String? value) {
    if (value == null || value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }
}

class _PromotionImageFallback extends StatelessWidget {
  const _PromotionImageFallback({this.isLoading = false});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFEFF6FF),
      child: Center(
        child: isLoading
            ? const CircularProgressIndicator(color: Color(0xFF2563EB))
            : const Icon(
                Icons.campaign_outlined,
                color: Color(0xFF2563EB),
                size: 42,
              ),
      ),
    );
  }
}
