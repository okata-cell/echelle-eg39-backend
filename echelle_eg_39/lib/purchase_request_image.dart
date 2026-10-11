import 'equipment_request_image.dart';

/// Backwards-compatible resolver for purchase requests.
String? resolvePurchaseRequestImageUrl(Map<String, dynamic> demande) =>
    resolveEquipmentRequestImageUrl(demande);
