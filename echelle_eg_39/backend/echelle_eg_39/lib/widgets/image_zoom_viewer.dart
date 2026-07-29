import 'package:flutter/material.dart';

/// Opens a full-screen pinch-to-zoom image viewer.
///
/// Usage:
/// ```dart
/// openImageZoom(context, imageUrl: '...', title: 'GPS Leica');
/// ```
void openImageZoom(
  BuildContext context, {
  required String imageUrl,
  String? title,
}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      pageBuilder: (ctx, animation, _) => _ImageZoomPage(
        imageUrl: imageUrl,
        title: title,
        animation: animation,
      ),
      transitionsBuilder: (ctx, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class _ImageZoomPage extends StatefulWidget {
  final String imageUrl;
  final String? title;
  final Animation<double> animation;

  const _ImageZoomPage({
    required this.imageUrl,
    this.title,
    required this.animation,
  });

  @override
  State<_ImageZoomPage> createState() => _ImageZoomPageState();
}

class _ImageZoomPageState extends State<_ImageZoomPage> {
  final TransformationController _transformController =
      TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Tap background to close ──────────────────────────────────────
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(color: Colors.black87),
          ),

          // ── Image with pinch-to-zoom ─────────────────────────────────────
          Center(
            child: GestureDetector(
              onDoubleTap: () {
                // Double-tap: toggle between 1x and 3x zoom
                if (_transformController.value != Matrix4.identity()) {
                  _resetZoom();
                } else {
                  _transformController.value = Matrix4.identity()
                    ..scale(3.0);
                }
              },
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 0.5,
                maxScale: 6.0,
                panEnabled: true,
                child: Image.network(
                  widget.imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return SizedBox(
                      width: 200,
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    width: 200,
                    height: 200,
                    child: Center(
                      child: Icon(Icons.broken_image, size: 64, color: Colors.white54),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Top bar: title + close button ────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  if (widget.title != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    const Spacer(),
                  // Close button
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom hint ──────────────────────────────────────────────────
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: widget.animation,
                curve: const Interval(0.6, 1.0),
              ),
              child: const Center(
                child: Text(
                  'Pincez pour zoomer • Double-tap pour agrandir',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps any image widget with a tap-to-zoom gesture and a zoom hint overlay.
class ZoomableImage extends StatelessWidget {
  final String imageUrl;
  final String? title;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const ZoomableImage({
    super.key,
    required this.imageUrl,
    this.title,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget img = Image.network(
      imageUrl,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey[300],
        child: const Icon(Icons.image, size: 40, color: Colors.grey),
      ),
    );

    if (borderRadius != null) {
      img = ClipRRect(borderRadius: borderRadius!, child: img);
    }

    return GestureDetector(
      onTap: () => openImageZoom(context, imageUrl: imageUrl, title: title),
      child: Stack(
        children: [
          img,
          // Zoom hint icon (bottom-right)
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.zoom_in,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
