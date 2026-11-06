// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'package:flutter/material.dart';

import '../profile_theme.dart';
import 'profile_sheet.dart';

/// Politique de confidentialité : trois sections de trois entrées.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String _intro =
      'En conformité avec le RGPD, nous nous engageons à protéger vos données '
      'personnelles.';

  static const Map<String, List<String>> _sections = {
    'Données collectées': [
      'Nom et coordonnées',
      'Historique des commandes',
      'Données de localisation',
    ],
    'Utilisation': [
      'Traitement des commandes',
      'Amélioration de nos services',
      'Communication commerciale (avec consentement)',
    ],
    'Vos droits': [
      'Accès et rectification',
      'Effacement et portabilité',
      'Opposition et limitation',
    ],
  };

  @override
  Widget build(BuildContext context) {
    return ProfileSheetScaffold(
      title: 'Confidentialité',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
            child: Text(_intro, style: ProfileText.documentBody),
          ),
          ProfileCard(
            dividerInset: 20,
            children: [
              for (final section in _sections.entries)
                _LegalSection(heading: section.key, lines: section.value),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegalSection extends StatelessWidget {
  const _LegalSection({required this.heading, required this.lines});

  final String heading;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: ProfileText.documentHeading),
          for (final line in lines) ...[
            const SizedBox(height: 8),
            Text(line, style: ProfileText.documentBody),
          ],
        ],
      ),
    );
  }
}
