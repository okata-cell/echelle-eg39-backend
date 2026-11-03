import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_links.dart';
import '../company_contact.dart';
import '../profile_theme.dart';
import 'app_action_group.dart';
import 'profile_sheet.dart';

/// Invitation d’un nouvel utilisateur à installer l’application.
///
/// Tant que l’application n’est pas publiée, l’écran l’annonce clairement au
/// lieu de proposer un lien qui n’existe pas encore.
class InviteAppScreen extends StatefulWidget {
  const InviteAppScreen({
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
  final Future<bool> Function(Uri uri)? openUri;
  final Future<void> Function(String text)? copyText;
  final Future<void> Function(String text, String subject)? openSystemShare;

  @override
  State<InviteAppScreen> createState() => _InviteAppScreenState();
}

class _InviteAppScreenState extends State<InviteAppScreen> {
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
          backgroundColor: ProfileTokens.ink,
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

    return ProfileSheetScaffold(
      title: links.isEmpty
          ? 'Application bientôt disponible'
          : 'Inviter à installer',
      bottomBar: links.isEmpty
          ? ProfileActionBar(
              children: [
                Expanded(
                  child: ProfilePillButton(
                    key: const ValueKey('invite-copy'),
                    label: _isCopied ? 'Copié' : 'Copier le message',
                    icon: _isCopied ? Icons.check : Icons.content_copy_outlined,
                    onPressed: _copyInvitation,
                  ),
                ),
              ],
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (links.isEmpty) _buildUnavailableNotice() else _buildMessagePreview(),
          if (links.isNotEmpty) ...[
            const SizedBox(height: 12),
            ProfileCard(
              children: [
                for (final link in links)
                  ProfileSheetRow(
                    key: ValueKey('invite-store-${link.platform.name}'),
                    leading: AppGlyphTile(
                      child: FaIcon(
                        link.platform == StorePlatform.android
                            ? FontAwesomeIcons.googlePlay
                            : FontAwesomeIcons.apple,
                        size: 17,
                        color: link.platform == StorePlatform.android
                            ? const Color(0xFF01875F)
                            : ProfileTokens.ink,
                      ),
                    ),
                    title: link.name,
                    titleStyle: ProfileText.sheetRow,
                    minHeight: 56,
                    onTap: () => _openStore(link),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ProfileCard(
              children: [
                ProfileSheetRow(
                  key: const ValueKey('invite-share'),
                  leading: const AppGlyphTile(
                    child: Icon(
                      Icons.ios_share,
                      size: 17,
                      color: ProfileTokens.primary,
                    ),
                  ),
                  title: 'Partager le lien',
                  titleStyle: ProfileText.sheetRow,
                  minHeight: 56,
                  onTap: _shareInvitation,
                ),
                ProfileSheetRow(
                  key: const ValueKey('invite-copy'),
                  leading: const AppGlyphTile(
                    child: Icon(
                      Icons.content_copy_outlined,
                      size: 17,
                      color: ProfileTokens.primary,
                    ),
                  ),
                  title: 'Copier le message',
                  titleStyle: ProfileText.sheetRow,
                  minHeight: 56,
                  trailing: _isCopied ? _buildCopiedBadge() : null,
                  onTap: _copyInvitation,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUnavailableNotice() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('invite-unavailable'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ProfileTokens.surfaceMuted,
            borderRadius: BorderRadius.circular(ProfileTokens.radiusField),
            border: Border.all(color: ProfileTokens.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.hourglass_empty,
                size: 18,
                color: ProfileTokens.muted,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  AppLinks.unavailableNotice,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: ProfileTokens.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ProfileCard(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Message d’invitation', style: ProfileText.footNote),
                  const SizedBox(height: 6),
                  Text(_message, style: ProfileText.documentBody),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMessagePreview() {
    return ProfileCard(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            key: const ValueKey('invite-message-preview'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${CompanyContact.name} — application mobile',
                style: ProfileText.rowTitle,
              ),
              const SizedBox(height: 8),
              Text(
                _message,
                maxLines: _isMessageExpanded ? null : 3,
                overflow: _isMessageExpanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: ProfileText.documentBody,
              ),
              TextButton(
                key: const ValueKey('invite-message-toggle'),
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
