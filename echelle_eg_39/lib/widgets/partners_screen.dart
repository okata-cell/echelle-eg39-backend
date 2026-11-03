import 'package:flutter/material.dart';

import '../profile_theme.dart';
import 'profile_sheet.dart';

/// Partenaires de l’entreprise : les deux marques réellement distribuées.
class PartnersScreen extends StatelessWidget {
  const PartnersScreen({super.key});

  static const List<({String name, String detail})> _partners = [
    (name: 'Leica', detail: 'Équipements de précision suisses'),
    (name: 'e-survey', detail: 'GPS de nouvelle génération'),
  ];

  @override
  Widget build(BuildContext context) {
    return ProfileSheetScaffold(
      title: 'Partenaires',
      child: ProfileCard(
        children: [
          for (final partner in _partners)
            ProfileSheetRow(
              key: ValueKey('partner-${partner.name}'),
              title: partner.name,
              titleStyle: ProfileText.name,
              subtitle: partner.detail,
              subtitleStyle: ProfileText.documentBody,
              minHeight: 104,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            ),
        ],
      ),
    );
  }
}
