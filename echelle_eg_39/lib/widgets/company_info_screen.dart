import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../company_location.dart';
import '../profile_theme.dart';
import 'profile_sheet.dart';

/// Présentation de l’entreprise : histoire, mission, localisation, zone.
///
/// Barre d’actions basse : copie de l’adresse et ouverture de l’itinéraire.
class CompanyInfoScreen extends StatefulWidget {
  const CompanyInfoScreen({super.key, this.launchMaps});

  /// Remplaçable pour les tests et le mode hors ligne.
  final Future<bool> Function(Uri uri)? launchMaps;

  @override
  State<CompanyInfoScreen> createState() => _CompanyInfoScreenState();
}

class _CompanyInfoScreenState extends State<CompanyInfoScreen> {
  void _announce(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: ProfileTokens.ink,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _copyAddress() async {
    const fullAddress = '${CompanyLocation.name} — ${CompanyLocation.address}';
    try {
      await Clipboard.setData(const ClipboardData(text: fullAddress));
      if (mounted) _announce('Adresse copiée.');
    } catch (_) {
      if (mounted) _announce('Impossible de copier l’adresse.');
    }
  }

  Future<void> _openItinerary() async {
    var launched = false;
    try {
      final launcher = widget.launchMaps;
      launched = launcher != null
          ? await launcher(CompanyLocation.mapsUri)
          : await launchUrl(
              CompanyLocation.mapsUri,
              mode: LaunchMode.externalApplication,
            );
    } catch (_) {
      launched = false;
    }
    if (!mounted || launched) return;
    _announce('Impossible d’ouvrir l’itinéraire pour le moment.');
  }

  @override
  Widget build(BuildContext context) {
    return ProfileSheetScaffold(
      title: 'Entreprise',
      bottomBar: ProfileActionBar(
        children: [
          ProfileQuietIconButton(
            key: const ValueKey('company-copy-address'),
            icon: Icons.content_copy_outlined,
            tooltip: 'Copier l’adresse',
            onPressed: _copyAddress,
          ),
          const Spacer(),
          ProfilePillButton(
            key: const ValueKey('company-itinerary'),
            label: 'Itinéraire',
            icon: Icons.directions,
            onPressed: _openItinerary,
          ),
        ],
      ),
      child: ProfileCard(
        dividerInset: 20,
        children: [
          const ProfileDocumentBlock(
            heading: 'Histoire',
            paragraphs: [
              'Créée en 2019, ÉCHELLE EG39 est spécialisée dans la vente et '
                  'location d’équipements de topographie de haute précision. '
                  'Nous accompagnons les professionnels du secteur dans leurs '
                  'projets d’infrastructure et de construction.',
            ],
          ),
          const ProfileDocumentBlock(
            heading: 'Mission',
            paragraphs: [
              'Fournir des équipements de topographie de qualité supérieure et '
                  'un service après-vente exceptionnel pour accompagner nos '
                  'clients dans la réussite de leurs projets.',
            ],
          ),
          ProfileDocumentBlock(
            heading: 'Localisation',
            paragraphs: const [CompanyLocation.address],
            footNotes: [
              CompanyLocation.plusCode,
              CompanyLocation.formattedCoordinates,
            ],
          ),
          const ProfileDocumentBlock(
            heading: 'Zone d’intervention',
            paragraphs: [
              'Sous-région ouest-africaine (Togo, Ghana, Bénin, Burkina Faso, '
                  'Mali, etc.)',
            ],
          ),
        ],
      ),
    );
  }
}
