import 'package:flutter/material.dart';

import '../company_contact.dart';
import '../profile_theme.dart';
import 'direct_contact_screen.dart';
import 'faq_screen.dart';
import 'glossary_screen.dart';
import 'profile_sheet.dart';

/// Sommaire « Centre d’aide ».
///
/// Deux ressources documentaires en tuiles, puis la prise de contact dans une
/// carte pleine largeur : consulter et joindre l’équipe ne se lisent pas comme
/// deux entrées de la même liste.
class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key, this.launchUri});

  /// Remplace l’ouverture du composeur téléphone / e-mail (tests, hors ligne).
  final Future<bool> Function(Uri uri)? launchUri;

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProfileSheetScaffold(
      title: "Centre d'aide",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfileTileGrid(
            tiles: [
              ProfileTile(
                key: const ValueKey('help-tile-faq'),
                icon: Icons.help_outline,
                label: 'FAQ dynamique',
                description: 'Questions fréquentes organisées par catégories',
                height: 144,
                onTap: () => _open(context, const FaqScreen()),
              ),
              ProfileTile(
                key: const ValueKey('help-tile-glossary'),
                icon: Icons.translate,
                label: 'Glossaire',
                description: 'Définitions des termes techniques',
                height: 144,
                onTap: () => _open(context, const GlossaryScreen()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ProfileCard(
            children: [
              ProfileSheetRow(
                key: const ValueKey('help-contact-card'),
                leading: const Icon(
                  Icons.phone_outlined,
                  size: 21,
                  color: ProfileTokens.primary,
                ),
                title: 'Contact direct',
                subtitle: 'Téléphone, e-mail, WhatsApp',
                subtitleStyle: ProfileText.rowSubtitle,
                minHeight: 124,
                body: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        CompanyContact.phoneDisplay,
                        style: ProfileText.identityStrong,
                      ),
                      const SizedBox(height: 2),
                      Text(CompanyContact.email, style: ProfileText.listValue),
                    ],
                  ),
                ),
                onTap: () =>
                    _open(context, DirectContactScreen(launchUri: launchUri)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
