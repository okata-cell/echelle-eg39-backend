import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_links.dart';
import '../company_contact.dart';
import 'app_action_group.dart';

typedef InviteUriLauncher = Future<bool> Function(Uri uri);
typedef InviteTextCopier = Future<void> Function(String text);
typedef InviteShareLauncher =
    Future<void> Function(String text, String subject);

/// Invitation d’un nouvel utilisateur à installer l’application.
///
/// Tant que l’application n’est pas publiée, l’écran l’annonce clairement au
/// lieu de proposer un lien qui n’existe pas encore.
class InviteAppDialog extends StatefulWidget {
  const InviteAppDialog({
    super.key,
    this.androidUrl = AppLinks.androidStoreUrl,
    this.iosUrl = AppLinks.iosStoreUrl,
    this.openUri,
    this.copyText,
    this.openSystemShare,
  });

  final String androidUrl;
  final String iosUrl;

  /// Remplaçables pour les tests.
  final InviteUriLauncher? openUri;
  final InviteTextCopier? copyText;
  final InviteShareLauncher? openSystemShare;

  @override
  State<InviteAppDialog> createState() => _InviteAppDialogState();
}

class _InviteAppDialogState extends State<InviteAppDialog> {
  bool _isMessageExpanded = false;
  bool _isCopied = false;

  List<StoreLink> get _storeLinks => AppLinks.buildStoreLinks(
    androidUrl: widget.androidUrl,
    iosUrl: widget.iosUrl,
  );

  String get _message => AppLinks.inviteMessage(
    androidUrl: widget.androidUrl,
    iosUrl: widget.iosUrl,
  );

  Future<void> _writeToClipboard(String text) async {
    final copy = widget.copyText;
    if (copy != null) {
      await copy(text);
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
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

  Future<void> _openStore(StoreLink link) async {
    final launcher = widget.openUri;
    var opened = false;
    try {
      opened = launcher != null
          ? await launcher(Uri.parse(link.url))
          : await launchUrl(
              Uri.parse(link.url),
              mode: LaunchMode.externalApplication,
            );
    } catch (_) {
      opened = false;
    }
    if (opened) return;
    await _writeToClipboard(link.url);
    _announce('Store indisponible. Lien copié dans le presse-papiers.');
  }

  Future<void> _shareInvitation() async {
    final share = widget.openSystemShare;
    try {
      if (share != null) {
        await share(_message, CompanyContact.name);
      } else {
        await SharePlus.instance.share(
          ShareParams(text: _message, subject: CompanyContact.name),
        );
      }
    } catch (_) {
      await _writeToClipboard(_message);
      _announce('Partage indisponible. Message copié dans le presse-papiers.');
    }
  }

  Future<void> _copyInvitation() async {
    await _writeToClipboard(_message);
    if (!mounted) return;
    setState(() => _isCopied = true);
  }

  @override
  Widget build(BuildContext context) {
    final links = _storeLinks;

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      title: Text(
        links.isEmpty
            ? 'Application bientôt disponible'
            : 'Inviter à installer',
        style: const TextStyle(
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
              _buildIntro(links),
              if (links.isNotEmpty) ...[
                const SizedBox(height: 18),
                AppActionGroup(
                  children: [
                    for (final link in links)
                      AppActionRow(
                        key: ValueKey('invite-store-${link.platform.name}'),
                        onTap: () => _openStore(link),
                        label: link.name,
                        leading: AppGlyphTile(
                          child: FaIcon(
                            link.platform == StorePlatform.android
                                ? FontAwesomeIcons.googlePlay
                                : FontAwesomeIcons.apple,
                            size: 17,
                            color: link.platform == StorePlatform.android
                                ? const Color(0xFF01875F)
                                : AppActionPalette.ink,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                AppActionGroup(
                  children: [
                    AppActionRow(
                      key: const ValueKey('invite-share'),
                      onTap: _shareInvitation,
                      label: 'Partager le lien',
                      leading: const AppGlyphTile(
                        child: Icon(
                          Icons.ios_share,
                          size: 17,
                          color: AppActionPalette.accent,
                        ),
                      ),
                    ),
                    AppActionRow(
                      key: const ValueKey('invite-copy'),
                      onTap: _copyInvitation,
                      label: 'Copier le message',
                      leading: const AppGlyphTile(
                        child: Icon(
                          Icons.content_copy_outlined,
                          size: 17,
                          color: AppActionPalette.accent,
                        ),
                      ),
                      trailing: _isCopied ? _buildCopiedBadge() : null,
                    ),
                  ],
                ),
              ],
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

  Widget _buildIntro(List<StoreLink> links) {
    if (links.isEmpty) {
      return Container(
        key: const ValueKey('invite-unavailable'),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppActionPalette.parchment,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.hourglass_empty,
              size: 18,
              color: AppActionPalette.muted,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                AppLinks.unavailableNotice,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: Color(0xFF333333),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const ValueKey('invite-message-preview'),
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
                  '${CompanyContact.name} — application mobile',
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
          const SizedBox(height: 10),
          Text(
            _message,
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
            key: const ValueKey('invite-message-toggle'),
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
