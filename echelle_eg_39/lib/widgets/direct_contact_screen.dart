// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../company_contact.dart';
import '../profile_theme.dart';
import 'profile_sheet.dart';

/// Coordonnées de l’entreprise, chacune ouvrant son composeur système.
///
/// Sans application cible, la coordonnée est copiée pour rester utilisable :
/// c’est le repli déjà retenu par l’écran Profil.
class DirectContactScreen extends StatefulWidget {
  const DirectContactScreen({super.key, this.launchUri});

  /// Remplaçable pour les tests et les appareils sans application cible.
  final Future<bool> Function(Uri uri)? launchUri;

  @override
  State<DirectContactScreen> createState() => _DirectContactScreenState();
}

class _DirectContactScreenState extends State<DirectContactScreen> {
  Future<void> _open(
    Uri uri, {
    required String copyValue,
    required String fallbackMessage,
  }) async {
    var launched = false;
    try {
      final launcher = widget.launchUri;
      launched = launcher != null
          ? await launcher(uri)
          : await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (launched || !mounted) return;

    try {
      await Clipboard.setData(ClipboardData(text: copyValue));
    } catch (_) {
      // Le presse-papiers peut être indisponible : le message reste utile.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(fallbackMessage),
          backgroundColor: ProfileTokens.ink,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ProfileSheetScaffold(
      title: 'Contact direct',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfileCard(
            children: [
              ProfileSheetRow(
                key: const ValueKey('contact-phone'),
                icon: Icons.phone_outlined,
                title: 'Téléphone',
                subtitle: CompanyContact.phoneDisplay,
                minHeight: 72,
                onTap: () => _open(
                  CompanyContact.phoneUri,
                  copyValue: CompanyContact.phoneDisplay,
                  fallbackMessage: CompanyContact.phoneFallbackMessage,
                ),
              ),
              ProfileSheetRow(
                key: const ValueKey('contact-email'),
                icon: Icons.mail_outline,
                title: 'E-mail',
                subtitle: CompanyContact.email,
                minHeight: 72,
                onTap: () => _open(
                  CompanyContact.emailUri,
                  copyValue: CompanyContact.email,
                  fallbackMessage: CompanyContact.emailFallbackMessage,
                ),
              ),
              ProfileSheetRow(
                key: const ValueKey('contact-whatsapp'),
                leading: const FaIcon(
                  FontAwesomeIcons.whatsapp,
                  size: 18,
                  color: ProfileTokens.primary,
                ),
                title: 'WhatsApp',
                subtitle: CompanyContact.phoneDisplay,
                minHeight: 72,
                onTap: () => _open(
                  CompanyContact.whatsAppUri(
                    text: 'Bonjour ${CompanyContact.name}, j’ai besoin d’aide.',
                  ),
                  copyValue: CompanyContact.phoneDisplay,
                  fallbackMessage: CompanyContact.whatsAppFallbackMessage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ProfileCard(
            children: [
              ProfileSheetRow(
                key: const ValueKey('contact-hours'),
                title: 'Horaires',
                body: Text(CompanyContact.hours, style: ProfileText.listValue),
                minHeight: 88,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
