import 'dart:typed_data';

import 'package:echelle_eg_39/profile_avatar_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;

void main() {
  test('convertit les formats courants en JPEG affichable', () async {
    final source = image_lib.Image(width: 48, height: 32, numChannels: 4);
    for (final pixel in source) {
      pixel
        ..r = (pixel.x * 5) % 256
        ..g = (pixel.y * 7) % 256
        ..b = (pixel.x + pixel.y) % 256
        ..a = 255;
    }

    final inputs = <Uint8List>[
      image_lib.encodeJpg(source),
      image_lib.encodePng(source),
      image_lib.encodeWebP(source, lossless: false, quality: 75),
      image_lib.encodeGif(source),
      image_lib.encodeBmp(source),
      image_lib.encodeTiff(source),
    ];

    for (final input in inputs) {
      final normalized = await normalizeProfileAvatar(input);
      expect(normalized.mimeType, 'image/jpeg');
      expect(normalized.bytes.take(3), [0xff, 0xd8, 0xff]);
      expect(normalized.bytes.length, lessThanOrEqualTo(1024 * 1024));
      expect(image_lib.decodeJpg(normalized.bytes), isNotNull);
    }
  });

  test('réduit une image lourde sous la limite de 1 Mo', () async {
    final source = image_lib.Image(width: 1024, height: 1024);
    var value = 0x12345678;
    for (final pixel in source) {
      value = (value * 1664525 + 1013904223) & 0x7fffffff;
      pixel
        ..r = value & 0xff
        ..g = (value >> 8) & 0xff
        ..b = (value >> 16) & 0xff;
    }
    final original = image_lib.encodePng(source);
    expect(original.length, greaterThan(1024 * 1024));

    final normalized = await normalizeProfileAvatar(original);
    final decoded = image_lib.decodeJpg(normalized.bytes)!;

    expect(normalized.bytes.length, lessThanOrEqualTo(1024 * 1024));
    expect(decoded.width, lessThanOrEqualTo(600));
    expect(decoded.height, lessThanOrEqualTo(600));
  });

  test('refuse proprement un fichier qui ne contient pas une image', () async {
    await expectLater(
      normalizeProfileAvatar(Uint8List.fromList([1, 2, 3, 4])),
      throwsA(isA<ProfileAvatarImageException>()),
    );
  });
}
