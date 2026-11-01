import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../company_contact.dart';
import '../company_share.dart';
import 'app_action_group.dart';

typedef ShareUriLauncher = Future<bool> Function(Uri uri);
typedef ShareTextCopier = Future<void> Function(String text);
typedef SystemShareLauncher =
    Future<void> Function(String text, String subject);

/// Envoi de la fiche de l’entreprise vers les réseaux sociaux.
///
/// Les réseaux à lien web (WhatsApp, Facebook, Telegram, X, LinkedIn, e-mail)
/// ouvrent leur composeur. Instagram n’accepte aucun partage texte par lien :
/// le message est copié puis l’application est ouverte. « Autres applications »
/// passe par la feuille de partage du système.
class ShareCompanyDialog extends StatefulWidget {
  const ShareCompanyDialog({
    super.key,
    this.openUri,
    this.copyText,
    this.openSystemShare,
  });

  /// Remplaçable pour les tests et les appareils sans application cible.
  final ShareUriLauncher? openUri;
  final ShareTextCopier? copyText;
  final SystemShareLauncher? openSystemShare;

  @override
  State<ShareCompanyDialog> createState() => _ShareCompanyDialogState();
}

class _ShareCompanyDialogState extends State<ShareCompanyDialog> {
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
          backgroundColor: AppActionPalette.ink,
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
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      title: const Text(
        'Partager ÉCHELLE EG39',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppActionPalette.ink,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMessageWell(),
              const SizedBox(height: 18),
              AppActionGroup(
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
                    icon: FontAwesomeIcons.facebook,
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
                    icon: FontAwesomeIcons.x,
                    brand: AppActionPalette.ink,
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
                    brand: AppActionPalette.accent,
                    label: 'E-mail',
                    onTap: () => _openNetwork(CompanyShare.emailUri()),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AppActionGroup(
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }

  Widget _buildMessageWell() {
    return Container(
      key: const ValueKey('share-message-preview'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppActionPalette.parchment,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppActionPalette.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  CompanyContact.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppActionPalette.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            CompanyContact.phoneDisplay,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: AppActionPalette.muted,
            ),
          ),
          const Text(
            CompanyContact.email,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: AppActionPalette.muted,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            CompanyShare.fullMessage,
            key: const ValueKey('share-message-text'),
            maxLines: _isMessageExpanded ? null : 3,
            overflow: _isMessageExpanded
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Color(0xFF333333),
            ),
          ),
          TextButton(
            key: const ValueKey('share-message-toggle'),
            onPressed: () =>
                setState(() => _isMessageExpanded = !_isMessageExpanded),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              alignment: Alignment.centerLeft,
              foregroundColor: AppActionPalette.accent,
            ),
            child: Text(
              _isMessageExpanded ? 'Masquer le message' : 'Voir le message',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppActionPalette.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _networkRow({
    required String id,
    required FaIconData icon,
    required Color brand,
    required String label,
    required VoidCallback onTap,
  }) {
    return AppActionRow(
      key: ValueKey('share-network-$id'),
      onTap: onTap,
      label: label,
      leading: AppGlyphTile(child: FaIcon(icon, size: 16, color: brand)),
    );
  }

  Widget _utilityRow({
    required String id,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return AppActionRow(
      key: ValueKey('share-action-$id'),
      onTap: onTap,
      label: label,
      trailing: trailing,
      leading: AppGlyphTile(
        child: Icon(icon, size: 17, color: AppActionPalette.accent),
      ),
    );
  }

  Widget _buildCopiedBadge() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check, size: 15, color: AppActionPalette.accent),
        SizedBox(width: 4),
        Text(
          'Copié',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppActionPalette.accent,
          ),
        ),
      ],
    );
  }
}
