import 'package:flutter/material.dart';

import 'profile_sheet.dart';

/// Crédits : rôles de développement, technologies et version publiée.
class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  static const List<String> _roles = [
    'Développeur Principal',
    'Designer UI/UX',
    'Développeur Mobile',
  ];

  static const List<String> _technologies = ['Flutter', 'Dart', 'Firebase'];

  @override
  Widget build(BuildContext context) {
    return ProfileSheetScaffold(
      title: 'Crédits',
      child: ProfileCard(
        dividerInset: 20,
        children: [
          const ProfileDocumentBlock(
            heading: 'Développement',
            paragraphs: _roles,
          ),
          ProfileDocumentBlock(
            heading: 'Technologies utilisées',
            extra: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final technology in _technologies)
                  ProfileChip(label: technology),
              ],
            ),
          ),
          const ProfileDocumentBlock(
            heading: 'Version',
            paragraphs: ['1.0.0 — Mars 2024'],
          ),
        ],
      ),
    );
  }
}
