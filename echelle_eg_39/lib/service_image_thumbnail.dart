import 'package:flutter/material.dart';

/// Compact, accessible request thumbnail with a stable fallback for broken URLs.
class ServiceImageThumbnail extends StatelessWidget {
  const ServiceImageThumbnail({
    super.key,
    required this.imageUrl,
    required this.semanticLabel,
    this.width = 64,
    this.height = 64,
    this.borderRadius = 10,
  });

  final String? imageUrl;
  final String semanticLabel;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: SizedBox(
          width: width,
          height: height,
          child: url.isEmpty
              ? _fallback()
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  frameBuilder:
                      (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded || frame != null) {
                          return child;
                        }
                        return _fallback();
                      },
                  errorBuilder: (context, error, stackTrace) => _fallback(),
                ),
        ),
      ),
    );
  }

  Widget _fallback() {
    return const ColoredBox(
      color: Color(0xFFF1F5F9),
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }
}
