import 'package:flutter_test/flutter_test.dart';
import 'package:echelle_eg_39/appareil_images.dart';
import 'package:echelle_eg_39/equipment_request_image.dart';
import 'package:echelle_eg_39/purchase_request_image.dart';

void main() {
  group('resolveEquipmentRequestImageUrl', () {
    test('prefers the stored device photo', () {
      expect(
        resolveEquipmentRequestImageUrl({
          'appareilCode': 'APP-001',
          'appareilId': 2039,
          'imageUrl': ' https://example.com/device.jpg ',
        }),
        'https://example.com/device.jpg',
      );
    });

    test('uses the stable device code before the database ID', () {
      expect(
        resolveEquipmentRequestImageUrl({
          'appareilCode': 'APP-001',
          'appareilId': 2039,
        }),
        AppareilImages.getImageUrlForAppareilId('APP-001'),
      );
    });

    test('supports legacy snake-case fields and falls back by type', () {
      expect(
        resolveEquipmentRequestImageUrl({
          'appareil_id': 'APP-001',
          'appareil_type': 'GPS',
        }),
        AppareilImages.getImageUrlForAppareilId('APP-001'),
      );
      expect(
        resolveEquipmentRequestImageUrl({'appareil_type': 'GPS'}),
        AppareilImages.getImageUrlForType('GPS'),
      );
      expect(resolveEquipmentRequestImageUrl({}), isNull);
    });
  });

  group('resolvePurchaseRequestImageUrl', () {
    test('uses the image URL returned by the purchase API', () {
      final imageUrl = resolvePurchaseRequestImageUrl({
        'appareilId': 2039,
        'appareilCode': 'APP-2039',
        'appareilType': 'GPS',
        'imageUrl': ' https://example.com/gps-2039.jpg ',
      });

      expect(imageUrl, 'https://example.com/gps-2039.jpg');
    });

    test('falls back to the known product image when API image is empty', () {
      final imageUrl = resolvePurchaseRequestImageUrl({
        'appareilCode': 'APP-001',
        'appareilType': 'GPS',
        'imageUrl': '  ',
      });

      expect(imageUrl, AppareilImages.getImageUrlForAppareilId('APP-001'));
    });

    test('supports the legacy image field names', () {
      expect(
        resolvePurchaseRequestImageUrl({
          'appareilImage': 'https://example.com/legacy.jpg',
        }),
        'https://example.com/legacy.jpg',
      );
      expect(
        resolvePurchaseRequestImageUrl({
          'image_url': 'https://example.com/legacy-snake.jpg',
        }),
        'https://example.com/legacy-snake.jpg',
      );
    });
  });
}
