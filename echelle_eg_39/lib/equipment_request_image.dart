import 'appareil_images.dart';

/// Resolves equipment imagery from a rental or purchase request payload.
///
/// A stored equipment photo always wins. For legacy rows, the stable catalogue
/// code and then database ID are preferred to a generic equipment type image.
String? resolveEquipmentRequestImageUrl(Map<String, dynamic> request) {
  final storedImageUrl = _firstNonEmpty(request, const [
    'imageUrl',
    'appareilImageUrl',
    'appareilImage',
    'image_url',
    'appareil_image_url',
  ]);
  if (storedImageUrl != null) return storedImageUrl;

  final equipmentCode = _firstNonEmpty(request, const [
    'appareilCode',
    'appareil_code',
    'codeAppareil',
  ]);
  final equipmentId = _firstNonEmpty(request, const [
    'appareilId',
    'appareil_id',
  ]);
  final equipmentType = _firstNonEmpty(request, const [
    'appareilType',
    'appareil_type',
  ]);

  final imageByCode = _catalogueImage(equipmentCode);
  if (imageByCode != null) return imageByCode;

  final imageById = _catalogueImage(equipmentId);
  if (imageById != null) return imageById;

  if (equipmentType != null) {
    return AppareilImages.getImageUrlForType(equipmentType);
  }
  return null;
}

String? _catalogueImage(String? appareilCodeOrId) {
  if (appareilCodeOrId == null) return null;
  final imageUrl = AppareilImages.getImageUrlForAppareilId(appareilCodeOrId);
  return imageUrl == AppareilImages.defaultImageUrl ? null : imageUrl;
}

String? _firstNonEmpty(Map<String, dynamic> values, List<String> keys) {
  for (final key in keys) {
    final value = values[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}
