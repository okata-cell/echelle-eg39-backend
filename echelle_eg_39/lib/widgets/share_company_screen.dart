import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../company_contact.dart';
import '../company_share.dart';
import '../profile_theme.dart';
import 'app_action_group.dart';
import 'profile_sheet.dart';

/// Envoi de la fiche de l’entreprise vers les réseaux sociaux.
///
/// Les réseaux à lien web (WhatsApp, Facebook, Telegram, X, LinkedIn, e-mail)
/// ouvrent leur composeur. Instagram n’accepte aucun partage texte par lien :
/// le message est copié puis l’application est ouverte. « Autres applications »
/// passe par la feuille de partage du système.
class ShareCompanyScreen extends StatefulWidget {
  const ShareCompanyScreen({
    super.key,
    this.openUri,
    this.copyText,
    this.openSystemShare,
  });

  /// Remplaçable pour les tests et les appareils sans application cible.
  final Future<bool> Function(Uri uri)? openUri;
  final Future<void> Function(String text)? copyText;
  final Future<void> Function(String text, String subject)? openSystemShare;

  @override
  State<ShareCompanyScreen> createState() => _ShareCompanyScreenState();
}

class _ShareCompanyScreenState extends State<ShareCompanyScreen> {
  bool _isMessageExpanded = false;
  bool _isCopied = false;

  Future<void> _writeToClipboard(String text) async {
    final copy = widget.copyText;
    if (copy != null) {
      await copy(text);
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
  }

  void _close() {
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _announce(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: ProfileTokens.ink,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<bool> _openUri(Uri uri) async {
    final launcher = widget.openUri;
    try {
      return launcher != null
          ? await launcher(uri)
          : await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<void> _openNetwork(Uri uri) async {
    final opened = await _openUri(uri);
    if (opened) {
      _close();
      return;
    }
    await _writeToClipboard(CompanyShare.fullMessage);
    _announce('Réseau indisponible. Message copié dans le presse-papiers.');
    _close();
  }

  Future<void> _openInstagram() async {
    await _writeToClipboard(CompanyShare.fullMessage);
    var opened = await _openUri(CompanyShare.instagramAppUri());
    if (!opened) {
      opened = await _openUri(CompanyShare.instagramWebUri());
    }
    _announce(CompanyShare.instagramCopiedMessage);
    _close();
  }

  Future<void> _openSystemShare() async {
    final share = widget.openSystemShare;
    try {
      if (share != null) {
        await share(CompanyShare.fullMessage, CompanyContact.name);
      } else {
        await SharePlus.instance.share(
          ShareParams(
            text: CompanyShare.fullMessage,
            subject: CompanyContact.name,
          ),
        );
      }
      _close();
    } catch (_) {
      await _writeToClipboard(CompanyShare.fullMessage);
      _announce('Partage indisponible. Message copié dans le presse-papiers.');
      _close();
    }
  }

  Future<void> _copyMessage() async {
    await _writeToClipboard(CompanyShare.fullMessage);
    if (!mounted) return;
    setState(() => _isCopied = true);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    _close();
  }

  @override
  Widget build(BuildContext context) {
    return ProfileSheetScaffold(
      title: 'Partager nos coordonnées',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMessageWell(),
          const SizedBox(height: 12),
          ProfileCard(
            children: [
              _networkRow(
                id: 'whatsapp',
                icon: FontAwesomeIcons.whatsapp,
                brand: const Color(0xFF25D366),
                label: 'WhatsApp',
                onTap: () => _openNetwork(CompanyShare.whatsAppUri()),
              ),
              _networkRow(
                id: 'facebook',
                icon: FontAwesomeIcons.facebookF,
                brand: const Color(0xFF1877F2),
                label: 'Facebook',
                onTap: () => _openNetwork(CompanyShare.facebookUri()),
              ),
              _networkRow(
                id: 'instagram',
                icon: FontAwesomeIcons.instagram,
                brand: const Color(0xFFE1306C),
                label: 'Instagram',
                onTap: _openInstagram,
              ),
              _networkRow(
                id: 'telegram',
                icon: FontAwesomeIcons.telegram,
                brand: const Color(0xFF229ED9),
                label: 'Telegram',
                onTap: () => _openNetwork(CompanyShare.telegramUri()),
              ),
              _networkRow(
                id: 'x',
                icon: FontAwesomeIcons.xTwitter,
                brand: ProfileTokens.ink,
                label: 'X',
                onTap: () => _openNetwork(CompanyShare.xUri()),
              ),
              _networkRow(
                id: 'linkedin',
                icon: FontAwesomeIcons.linkedinIn,
                brand: const Color(0xFF0A66C2),
                label: 'LinkedIn',
                onTap: () => _openNetwork(CompanyShare.linkedInUri()),
              ),
              _networkRow(
                id: 'email',
                icon: FontAwesomeIcons.envelope,
                brand: ProfileTokens.primary,
                label: 'E-mail',
                onTap: () => _openNetwork(CompanyShare.emailUri()),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ProfileCard(
            children: [
              _utilityRow(
                id: 'system',
                icon: Icons.ios_share,
                label: 'Autres applications',
                onTap: _openSystemShare,
              ),
              _utilityRow(
                id: 'copy',
                icon: Icons.content_copy_outlined,
                label: 'Copier le message',
                onTap: _copyMessage,
                trailing: _isCopied ? _buildCopiedBadge() : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageWell() {
    return ProfileCard(
      children: [
        Padding(
          key: const ValueKey('share-message-preview'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(CompanyContact.name, style: ProfileText.rowTitle),
              const SizedBox(height: 4),
              Text(CompanyContact.phoneDisplay, style: ProfileText.listValue),
              Text(CompanyContact.email, style: ProfileText.listValue),
              const SizedBox(height: 10),
              Text(
                CompanyShare.fullMessage,
                key: const ValueKey('share-message-text'),
                // Quatre lignes : la présentation tient sans couper le numéro.
                maxLines: _isMessageExpanded ? null : 4,
                overflow: _isMessageExpanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: ProfileText.documentBody,
              ),
              const SizedBox(height: 4),
              Text(CompanyShare.publicUrl, style: ProfileText.footNote),
              TextButton(
                key: const ValueKey('share-message-toggle'),
                onPressed: () => setState(
                  () => _isMessageExpanded = !_isMessageExpanded,
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  alignment: Alignment.centerLeft,
                  foregroundColor: ProfileTokens.primary,
                ),
                child: Text(
                  _isMessageExpanded
                      ? 'Masquer le message'
                      : 'Voir le message',
                  style: ProfileText.actionLabel.copyWith(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _networkRow({
    required String id,
    required FaIconData icon,
    required Color brand,
    required String label,
    required VoidCallback onTap,
  }) {
    return ProfileSheetRow(
      key: ValueKey('share-network-$id'),
      leading: FaIcon(icon, size: 18, color: brand),
      title: label,
      titleStyle: ProfileText.sheetRow,
      minHeight: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      onTap: onTap,
    );
  }

  Widget _utilityRow({
    required String id,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ProfileSheetRow(
      key: ValueKey('share-action-$id'),
      leading: AppGlyphTile(
        child: Icon(icon, size: 17, color: ProfileTokens.primary),
      ),
      title: label,
      titleStyle: ProfileText.sheetRow,
      minHeight: 56,
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildCopiedBadge() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check, size: 15, color: ProfileTokens.primary),
        const SizedBox(width: 4),
        Text(
          'Copié',
          style: ProfileText.actionLabel.copyWith(
            fontSize: 12,
            color: ProfileTokens.primary,
          ),
        ),
      ],
    );
  }
}
