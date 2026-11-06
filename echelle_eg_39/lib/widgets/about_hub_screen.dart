// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'package:flutter/material.dart';

import '../app_links.dart';
import '../profile_theme.dart';
import 'company_info_screen.dart';
import 'credits_screen.dart';
import 'invite_app_screen.dart';
import 'partners_screen.dart';
import 'privacy_policy_screen.dart';
import 'profile_sheet.dart';
import 'services_screen.dart';
import 'share_company_screen.dart';
import 'team_screen.dart';
import 'terms_of_use_screen.dart';

/// Sommaire « À propos ».
///
/// Les quatre destinations de l’entreprise forment une grille de tuiles, les
/// trois documents de l’application restent une liste compacte, et les deux
/// actions de partage sont isolées sous leur propre intitulé : on ne peut pas
/// les confondre avec un document de plus.
class AboutHubScreen extends StatelessWidget {
  const AboutHubScreen({super.key, this.openUri, this.launchMaps});

  /// Remplace l’ouverture du composeur e-mail / WhatsApp (tests, hors ligne).
  final Future<bool> Function(Uri uri)? openUri;

  /// Remplace l’ouverture de l’itinéraire (tests, hors ligne).
  final Future<bool> Function(Uri uri)? launchMaps;

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProfileSheetScaffold(
      title: 'À propos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfileTileGrid(
            tiles: [
              ProfileTile(
                key: const ValueKey('about-tile-company'),
                icon: Icons.business_outlined,
                label: "Informations sur l'entreprise",
                onTap: () => _open(
                  context,
                  CompanyInfoScreen(launchMaps: launchMaps),
                ),
              ),
              ProfileTile(
                key: const ValueKey('about-tile-services'),
                icon: Icons.handyman_outlined,
                label: 'Nos services',
                onTap: () => _open(context, const ServicesScreen()),
              ),
              ProfileTile(
                key: const ValueKey('about-tile-team'),
                icon: Icons.groups_outlined,
                label: 'Notre équipe',
                onTap: () => _open(context, const TeamScreen()),
              ),
              ProfileTile(
                key: const ValueKey('about-tile-partners'),
                icon: Icons.handshake_outlined,
                label: 'Nos partenaires',
                onTap: () => _open(context, const PartnersScreen()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ProfileCard(
            children: [
              ProfileSheetRow(
                key: const ValueKey('about-row-privacy'),
                title: 'Politique de confidentialité',
                minHeight: 52,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                onTap: () => _open(context, const PrivacyPolicyScreen()),
              ),
              ProfileSheetRow(
                key: const ValueKey('about-row-terms'),
                title: 'Conditions d’utilisation',
                minHeight: 52,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                onTap: () => _open(context, const TermsOfUseScreen()),
              ),
              ProfileSheetRow(
                key: const ValueKey('about-row-credits'),
                title: 'Crédits',
                minHeight: 52,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                onTap: () => _open(context, const CreditsScreen()),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text('Actions', style: ProfileText.sectionTitle),
          ),
          const SizedBox(height: 8),
          ProfileCard(
            children: [
              ProfileSheetRow(
                key: const ValueKey('about-action-invite'),
                icon: Icons.file_download_outlined,
                title: 'Inviter à installer',
                subtitle: AppLinks.isPublished
                    ? 'Lien Google Play et App Store'
                    : 'Bientôt sur Google Play et l’App Store',
                subtitleStyle: ProfileText.rowSubtitle,
                minHeight: 64,
                onTap: () => _open(context, InviteAppScreen(openUri: openUri)),
              ),
              ProfileSheetRow(
                key: const ValueKey('about-action-share'),
                icon: Icons.share_outlined,
                title: 'Partager nos coordonnées',
                subtitle: 'Envoyez notre fiche à vos collègues',
                subtitleStyle: ProfileText.rowSubtitle,
                minHeight: 64,
                onTap: () =>
                    _open(context, ShareCompanyScreen(openUri: openUri)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
