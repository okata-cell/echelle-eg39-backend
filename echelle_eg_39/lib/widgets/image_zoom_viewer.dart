import 'package:flutter/material.dart';

/// Opens a full-screen pinch-to-zoom image viewer.
void openImageZoom(
  BuildContext context, {
  required String imageUrl,
  String? fallbackUrl,
  String? title,
}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      pageBuilder: (ctx, animation, _) => _ImageZoomPage(
        imageUrl: imageUrl,
        fallbackUrl: fallbackUrl,
        title: title,
        animation: animation,
      ),
      transitionsBuilder: (ctx, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal: full-screen zoom page
// ─────────────────────────────────────────────────────────────────────────────

class _ImageZoomPage extends StatefulWidget {
  final String imageUrl;
  final String? fallbackUrl;
  final String? title;
  final Animation<double> animation;

  const _ImageZoomPage({
    required this.imageUrl,
    this.fallbackUrl,
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
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(color: Colors.black87),
          ),
          Center(
            child: GestureDetector(
              onDoubleTap: () {
                if (_transformController.value != Matrix4.identity()) {
                  _resetZoom();
                } else {
                  _transformController.value = Matrix4.identity()..scale(3.0);
                }
              },
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 0.5,
                maxScale: 6.0,
                panEnabled: true,
                child: _ReliableNetworkImage(
                  imageUrl: widget.imageUrl,
                  fallbackUrl: widget.fallbackUrl,
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
                  errorWidget: const SizedBox(
                    width: 200,
                    height: 200,
                    child: Center(
                      child: Icon(Icons.broken_image,
                          size: 64, color: Colors.white54),
                    ),
                  ),
                ),
              ),
            ),
          ),
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
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 28),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ReliableNetworkImage
//
// Tries [imageUrl] first. If it fails to load (HTTP error, network error, etc.)
// automatically switches to [fallbackUrl] if provided. If that also fails,
// shows [errorWidget].
// ─────────────────────────────────────────────────────────────────────────────

class _ReliableNetworkImage extends StatefulWidget {
  final String imageUrl;
  final String? fallbackUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget errorWidget;
  final ImageLoadingBuilder? loadingBuilder;

  const _ReliableNetworkImage({
    required this.imageUrl,
    this.fallbackUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    required this.errorWidget,
    this.loadingBuilder,
  });

  @override
  State<_ReliableNetworkImage> createState() => _ReliableNetworkImageState();
}

class _ReliableNetworkImageState extends State<_ReliableNetworkImage> {
  bool _primaryFailed = false;

  String get _activeUrl =>
      (_primaryFailed && widget.fallbackUrl != null)
          ? widget.fallbackUrl!
          : widget.imageUrl;

  @override
  void didUpdateWidget(_ReliableNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset if imageUrl changes
    if (oldWidget.imageUrl != widget.imageUrl) {
      _primaryFailed = false;
    }
  }

  void _onPrimaryError() {
    if (!_primaryFailed && widget.fallbackUrl != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _primaryFailed = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Image.network(
      _activeUrl,
      key: ValueKey(_activeUrl),
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      loadingBuilder: widget.loadingBuilder,
      errorBuilder: (context, error, stackTrace) {
        if (!_primaryFailed && widget.fallbackUrl != null) {
          // Trigger switch to fallback on next frame
          _onPrimaryError();
          // Show a subtle loading indicator while switching
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: Container(
              color: Colors.grey[200],
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          );
        }
        // Both primary and fallback failed (or no fallback)
        return widget.errorWidget;
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ZoomableImage (public widget)
//
// Displays a network image that:
//   • Falls back to [fallbackUrl] if [imageUrl] fails to load
//   • Opens a full-screen pinch-to-zoom viewer on tap
// ─────────────────────────────────────────────────────────────────────────────

class ZoomableImage extends StatelessWidget {
  final String imageUrl;

  /// Shown automatically if [imageUrl] fails (e.g. 404, network error).
  /// Usually the category-based image from [AppareilImages.getImageUrlForType].
  final String? fallbackUrl;

  final String? title;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const ZoomableImage({
    super.key,
    required this.imageUrl,
    this.fallbackUrl,
    this.title,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget img = _ReliableNetworkImage(
      imageUrl: imageUrl,
      fallbackUrl: fallbackUrl,
      fit: fit,
      width: width,
      height: height,
      errorWidget: Container(
        color: Colors.grey[300],
        child: const Icon(Icons.image, size: 40, color: Colors.grey),
      ),
    );

    if (borderRadius != null) {
      img = ClipRRect(borderRadius: borderRadius!, child: img);
    }

    return GestureDetector(
      onTap: () => openImageZoom(
        context,
        imageUrl: imageUrl,
        fallbackUrl: fallbackUrl,
        title: title,
      ),
      child: Stack(
        children: [
          img,
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.zoom_in, color: Colors.white, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}
