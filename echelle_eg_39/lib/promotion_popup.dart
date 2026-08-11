import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class PromotionPopup {
  static const String _lastShownDateKey = 'last_promotion_shown_date';
  static const String _promotionIdKey = 'last_promotion_id';

  /// Vérifier et afficher la promotion si nécessaire
  static Future<void> checkAndShowPromotion(BuildContext context) async {
    try {
      final promotion = await ApiService.getActivePromotion();
      if (promotion == null) return;

      final prefs = await SharedPreferences.getInstance();
      final lastShownId = prefs.getInt(_promotionIdKey);
      final lastShownDate = prefs.getString(_lastShownDateKey);
      final today = DateTime.now().toIso8601String().split('T')[0];

      // Vérifier si c'est la même promotion déjà affichée aujourd'hui
      if (lastShownId == promotion['id'] && lastShownDate == today) {
        return;
      }

      // Vérifier la fréquence
      final frequence = promotion['frequence']?.toString() ?? 'chaque_ouverture';
      
      if (frequence == 'une_seule_fois' && lastShownId == promotion['id']) {
        return; // Déjà affichée une fois
      }

      if (frequence == 'une_fois_par_jour' && lastShownDate == today) {
        return; // Déjà affichée aujourd'hui
      }

      // Afficher le popup
      if (context.mounted) {
        await _showPromotionDialog(context, promotion);
        
        // Marquer comme affichée
        await prefs.setInt(_promotionIdKey, promotion['id']);
        await prefs.setString(_lastShownDateKey, today);
      }
    } catch (e) {
      print('❌ Erreur vérification promotion: $e');
    }
  }

  static Future<void> _showPromotionDialog(BuildContext context, Map<String, dynamic> promotion) async {
    final titre = promotion['titre']?.toString() ?? 'Promotion';
    final description = promotion['description']?.toString() ?? '';
    final imageUrl = promotion['image_url']?.toString() ?? '';
    final dateDebut = promotion['date_debut']?.toString() ?? '';
    final dateFin = promotion['date_fin']?.toString() ?? '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image de la promotion
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      height: 200,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(
                        Icons.campaign,
                        size: 64,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            // Contenu
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    titre,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (dateDebut.isNotEmpty && dateFin.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Du $dateDebut au $dateFin',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'J\'ai compris',
                        style: TextStyle(
                          fontSize: 16,
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
