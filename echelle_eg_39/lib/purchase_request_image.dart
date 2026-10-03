import 'appareil_images.dart';

/// Résout l’image d’un appareil depuis une demande d’achat retournée par l’API.
///
/// L’URL enregistrée sur l’appareil est prioritaire. Les anciens schémas de
/// réponse et les demandes sans URL utilisent ensuite le fallback par code/type.
String resolvePurchaseRequestImageUrl(Map<String, dynamic> demande) {
  final rawImageUrl =
      (demande['imageUrl'] ?? demande['appareilImage'] ?? demande['image_url'])
          ?.toString()
          .trim();
  final appareilCode = demande['appareilCode']?.toString() ?? '';
  final appareilId = demande['appareilId']?.toString() ?? '';
  final appareilType = demande['appareilType']?.toString() ?? '';

  return AppareilImages.getImageUrl(
    appareilCode.isNotEmpty ? appareilCode : appareilId,
    appareilType,
    customImageUrl: rawImageUrl == null || rawImageUrl.isEmpty
        ? null
        : rawImageUrl,
  );
}
