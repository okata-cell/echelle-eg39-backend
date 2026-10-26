import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// Adresse et coordonnées officielles de l'agence ÉCHELLE EG39.
class CompanyLocation {
  const CompanyLocation._();

  static const String name = 'ÉCHELLE EG39';
  static const String address =
      'Lomé, Rue des frères franciscains, après les rails';
  static const String landmark =
      'Après les rails, prenez la rue des frères franciscains : l’agence est sur votre droite.';
  static const String plusCode = '55PH+CR6 Lomé, Togo';

  /// Position résolue depuis le lien de localisation fourni par l'entreprise.
  static const LatLng coordinates = LatLng(6.186033, 1.179523);

  static const String mapsUrl =
      'https://maps.app.goo.gl/BtGKf2gwjaLpKFQN7?g_st=iw';

  static Uri get mapsUri => Uri.parse(mapsUrl);

  static String get formattedCoordinates =>
      '${coordinates.latitude.toStringAsFixed(5)}, '
      '${coordinates.longitude.toStringAsFixed(5)}';
}

typedef CompanyMapLauncher = Future<bool> Function(Uri uri);
typedef CompanyAddressCopier = Future<void> Function(String address);

/// Écran dédié : carte, marqueur et adresse de l'agence.
class CompanyLocationScreen extends StatelessWidget {
  const CompanyLocationScreen({
    super.key,
    this.mapBuilder,
    this.openMaps,
    this.copyAddress,
  });

  /// Remplaçable pour les tests et le mode hors ligne.
  final WidgetBuilder? mapBuilder;
  final CompanyMapLauncher? openMaps;
  final CompanyAddressCopier? copyAddress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAFB),
        foregroundColor: const Color(0xFF1D1D1F),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Nous localiser',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 19),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CompanyLocationCard(
              mapBuilder: mapBuilder,
              openMaps: openMaps,
              copyAddress: copyAddress,
            ),
            const SizedBox(height: 18),
            const _AccessNote(),
          ],
        ),
      ),
    );
  }
}

/// Fiche blanche arrondie : carte, étiquette du nom, adresse et itinéraire.
class CompanyLocationCard extends StatefulWidget {
  const CompanyLocationCard({
    super.key,
    this.mapBuilder,
    this.openMaps,
    this.copyAddress,
  });

  final WidgetBuilder? mapBuilder;
  final CompanyMapLauncher? openMaps;
  final CompanyAddressCopier? copyAddress;

  @override
  State<CompanyLocationCard> createState() => _CompanyLocationCardState();
}

class _CompanyLocationCardState extends State<CompanyLocationCard> {
  final MapController _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _openItinerary() async {
    var launched = false;
    try {
      final launcher = widget.openMaps;
      launched = launcher != null
          ? await launcher(CompanyLocation.mapsUri)
          : await launchUrl(
              CompanyLocation.mapsUri,
              mode: LaunchMode.externalApplication,
            );
    } catch (_) {
      launched = false;
    }
    if (mounted && !launched) {
      _showMessage('Impossible d’ouvrir l’itinéraire pour le moment.');
    }
  }

  Future<void> _copyAddress() async {
    final copy = widget.copyAddress;
    try {
      if (copy != null) {
        await copy('${CompanyLocation.name} — ${CompanyLocation.address}');
      } else {
        await Clipboard.setData(
          ClipboardData(
            text: '${CompanyLocation.name} — ${CompanyLocation.address}',
          ),
        );
      }
      if (mounted) _showMessage('Adresse copiée.');
    } catch (_) {
      if (mounted) _showMessage('Impossible de copier l’adresse.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF1D1D1F),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _recenter() {
    _mapController.move(CompanyLocation.coordinates, 16.4);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('company-location-card'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMapAperture(context),
            const SizedBox(height: 16),
            Text(
              CompanyLocation.address,
              style: const TextStyle(
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1D1D1F),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${CompanyLocation.plusCode}  ·  ${CompanyLocation.formattedCoordinates}',
              style: const TextStyle(
                fontSize: 12,
                height: 1.3,
                color: Color(0xFF7A7A7A),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                IconButton(
                  key: const ValueKey('company-location-copy'),
                  onPressed: _copyAddress,
                  tooltip: 'Copier l’adresse',
                  icon: const Icon(
                    Icons.content_copy_outlined,
                    size: 20,
                    color: Color(0xFF7A7A7A),
                  ),
                ),
                FilledButton.icon(
                  key: const ValueKey('company-location-itinerary'),
                  onPressed: _openItinerary,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.directions, size: 18),
                  label: const Text('Itinéraire'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapAperture(BuildContext context) {
    final map = widget.mapBuilder?.call(context) ?? _buildMap();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 232,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(child: map),
            Positioned(
              top: 12,
              left: 12,
              child: _NameLabel(name: CompanyLocation.name),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: _RecenterButton(onPressed: _recenter),
            ),
            Positioned(
              left: 8,
              bottom: 6,
              child: RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () => launchUrl(
                      Uri.parse('https://www.openstreetmap.org/copyright'),
                      mode: LaunchMode.externalApplication,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF4B5563),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
                permanentHeight: 24,
                showFlutterMapAttribution: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: CompanyLocation.coordinates,
        initialZoom: 16.4,
        minZoom: 14,
        maxZoom: 18,
        backgroundColor: Color(0xFFE9EEF4),
        interactionOptions: InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.okata.echelleeg39',
          maxZoom: 19,
        ),
        const MarkerLayer(
          markers: [
            Marker(
              point: CompanyLocation.coordinates,
              width: 54,
              height: 54,
              child: CompanyLocationMarker(),
            ),
          ],
        ),
      ],
    );
  }
}

/// Cible de topographe : réticule cerclé qui marque le point exact.
class CompanyLocationMarker extends StatelessWidget {
  const CompanyLocationMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Emplacement de l’entreprise ${CompanyLocation.name}',
      child: CustomPaint(
        painter: _ReticlePainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  static const Color _ink = Color(0xFF1D1D1F);
  static const Color _brand = Color(0xFF2563EB);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const ringRadius = 13.0;
    const tickGap = 17.0;
    const tickLength = 8.0;

    final halo = Paint()
      ..color = const Color(0x33FFFFFF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, ringRadius + 4, halo);

    final ring = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, ringRadius, ring);

    final ringStroke = Paint()
      ..color = _brand
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawCircle(center, ringRadius, ringStroke);

    canvas.drawCircle(
      center,
      3.4,
      Paint()
        ..color = _brand
        ..style = PaintingStyle.fill,
    );

    final tick = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    canvas
      ..drawLine(
        Offset(center.dx, center.dy - tickGap),
        Offset(center.dx, center.dy - tickGap - tickLength),
        tick,
      )
      ..drawLine(
        Offset(center.dx, center.dy + tickGap),
        Offset(center.dx, center.dy + tickGap + tickLength),
        tick,
      )
      ..drawLine(
        Offset(center.dx - tickGap, center.dy),
        Offset(center.dx - tickGap - tickLength, center.dy),
        tick,
      )
      ..drawLine(
        Offset(center.dx + tickGap, center.dy),
        Offset(center.dx + tickGap + tickLength, center.dy),
        tick,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NameLabel extends StatelessWidget {
  const _NameLabel({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('company-location-label'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF2563EB),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Entreprise $name',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D1D1F),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.my_location, size: 15, color: Color(0xFF2563EB)),
              SizedBox(width: 6),
              Text(
                'Recentrer',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1D1D1F),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccessNote extends StatelessWidget {
  const _AccessNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.route_outlined, size: 20, color: Color(0xFF7A7A7A)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              CompanyLocation.landmark,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Color(0xFF333333),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
