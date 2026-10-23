import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image_lib;

import 'profile_api.dart';

const _avatarMaxDimension = 600;
const _targetDimensions = [600, 512, 448, 384, 320, 256, 192, 128];
const _jpegQualities = [90, 82, 74, 66, 58, 50, 42, 34];

class ProfileAvatarImageException implements Exception {
  const ProfileAvatarImageException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NormalizedProfileAvatar {
  const NormalizedProfileAvatar({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

/// Converts gallery output to the JPEG format accepted by the profile API.
/// Decoding and encoding run off the UI isolate; large originals are resized
/// and retried at lower dimensions/quality until they fit the API byte limit.
Future<NormalizedProfileAvatar> normalizeProfileAvatar(
  Uint8List sourceBytes,
) async {
  if (sourceBytes.isEmpty) {
    throw const ProfileAvatarImageException(
      'Le fichier sélectionné ne contient aucune image.',
    );
  }

  late final Uint8List normalizedBytes;
  try {
    normalizedBytes = await compute(_normalizeAvatarBytes, sourceBytes);
  } on ProfileAvatarImageException {
    rethrow;
  } catch (_) {
    throw const ProfileAvatarImageException(
      'Cette image ne peut pas être convertie. Essayez une autre photo.',
    );
  }

  return NormalizedProfileAvatar(
    bytes: normalizedBytes,
    mimeType: 'image/jpeg',
  );
}

Uint8List _normalizeAvatarBytes(Uint8List sourceBytes) {
  late final image_lib.Image source;
  try {
    final decoded = image_lib.decodeImage(sourceBytes, frame: 0);
    if (decoded == null) {
      throw const FormatException('Unsupported image format');
    }
    source = image_lib.bakeOrientation(decoded);
  } catch (_) {
    throw const ProfileAvatarImageException(
      'Cette image ne peut pas être convertie. Essayez une autre photo.',
    );
  }

  for (final maxDimension in _targetDimensions) {
    final sourceLongestSide = source.width > source.height
        ? source.width
        : source.height;
    final scale = sourceLongestSide > maxDimension
        ? maxDimension / sourceLongestSide
        : 1.0;
    final width = (source.width * scale)
        .round()
        .clamp(1, _avatarMaxDimension)
        .toInt();
    final height = (source.height * scale)
        .round()
        .clamp(1, _avatarMaxDimension)
        .toInt();

    final resized =
        image_lib.copyResize(
            source,
            width: width,
            height: height,
            interpolation: image_lib.Interpolation.linear,
          )
          // Avatars do not need source metadata; in particular, avoid retaining
          // EXIF location/device details in the uploaded image.
          ..exif = image_lib.ExifData()
          ..iccProfile = null;

    for (final quality in _jpegQualities) {
      final bytes = image_lib.encodeJpg(
        resized,
        quality: quality,
        chroma: image_lib.JpegChroma.yuv420,
      );
      if (bytes.lengthInBytes <= ProfileApi.maxAvatarBytes) {
        return bytes;
      }
    }
  }

  throw const ProfileAvatarImageException(
    'Cette image est trop grande pour être convertie en photo de profil.',
  );
}
