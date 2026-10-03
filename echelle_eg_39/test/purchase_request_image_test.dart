import 'package:flutter_test/flutter_test.dart';
import 'package:echelle_eg_39/appareil_images.dart';
import 'package:echelle_eg_39/purchase_request_image.dart';

void main() {
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
