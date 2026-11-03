import 'package:flutter/material.dart';

import '../profile_theme.dart';

/// Châssis commun des feuilles de détail du Profil.
///
/// Une barre de titre de 60 px ouvre un chevron de retour bleu et le titre de
/// la feuille ; le contenu défile sur le fond parchemin, et une barre d’action
/// facultative reste collée en bas.
class ProfileSheetScaffold extends StatelessWidget {
  const ProfileSheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.bottomBar,
    this.padding = const EdgeInsets.fromLTRB(
      ProfileTokens.pagePadding,
      4,
      ProfileTokens.pagePadding,
      24,
    ),
  });

  final String title;
  final Widget child;
  final Widget? bottomBar;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProfileTokens.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHeader(title: title),
            Expanded(
              child: SingleChildScrollView(padding: padding, child: child),
            ),
            ?bottomBar,
          ],
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 8),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('profile-sheet-back'),
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Retour',
            iconSize: 24,
            color: ProfileTokens.primary,
            style: IconButton.styleFrom(
              minimumSize: const Size(
                ProfileTokens.touchTarget,
                ProfileTokens.touchTarget,
              ),
            ),
            icon: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ProfileText.sheetTitle,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte blanche à filet fin, avec filets de séparation entre les lignes.
class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.children,
    this.divide = true,
    this.dividerInset = 16,
  });

  final List<Widget> children;
  final bool divide;
  final double dividerInset;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (divide && index > 0) {
        rows.add(
          Divider(
            height: 1,
            thickness: 1,
            indent: dividerInset,
            endIndent: dividerInset,
            color: ProfileTokens.divider,
          ),
        );
      }
      rows.add(children[index]);
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ProfileTokens.surface,
        borderRadius: BorderRadius.circular(ProfileTokens.radiusCard),
        border: Border.all(color: ProfileTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}

/// Ligne d’une feuille : icône ou vignette, libellé, valeur et chevron.
class ProfileSheetRow extends StatelessWidget {
  const ProfileSheetRow({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.titleStyle,
    this.subtitle,
    this.subtitleStyle,
    this.body,
    this.trailing,
    this.onTap,
    this.minHeight = 64,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.semanticsLabel,
  });

  final IconData? icon;
  final Widget? leading;
  final String title;
  final TextStyle? titleStyle;
  final String? subtitle;
  final TextStyle? subtitleStyle;

  /// Contenu libre sous le libellé (deux lignes de valeur, par exemple).
  final Widget? body;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double minHeight;
  final EdgeInsetsGeometry padding;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final effectiveTrailing = trailing ??
        (onTap == null
            ? null
            : const Icon(
                Icons.chevron_right,
                size: 17,
                color: ProfileTokens.chevron,
              ));

    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 12),
            ] else if (icon != null) ...[
              Icon(icon, size: 20, color: ProfileTokens.primary),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle ?? ProfileText.rowTitle,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: subtitleStyle ?? ProfileText.listValue,
                    ),
                  ],
                  if (body != null) ...[
                    const SizedBox(height: 3),
                    body!,
                  ],
                ],
              ),
            ),
            if (effectiveTrailing != null) ...[
              const SizedBox(width: 8),
              effectiveTrailing,
            ],
          ],
        ),
      ),
    );

    if (onTap == null) {
      return Semantics(
        label: semanticsLabel,
        container: semanticsLabel != null,
        child: content,
      );
    }

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

/// Section de document : intitulé puis paragraphes, sans puce décorative.
class ProfileDocumentBlock extends StatelessWidget {
  const ProfileDocumentBlock({
    super.key,
    required this.heading,
    this.paragraphs = const <String>[],
    this.footNotes = const <String>[],
    this.extra,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 18),
  });

  final String heading;
  final List<String> paragraphs;
  final List<String> footNotes;
  final Widget? extra;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: ProfileText.documentHeading),
          for (final paragraph in paragraphs) ...[
            const SizedBox(height: 8),
            Text(paragraph, style: ProfileText.documentBody),
          ],
          for (final note in footNotes) ...[
            const SizedBox(height: 4),
            Text(note, style: ProfileText.footNote),
          ],
          if (extra != null) ...[const SizedBox(height: 12), extra!],
        ],
      ),
    );
  }
}

/// Barre d’actions collée en bas de feuille, séparée par un filet.
class ProfileActionBar extends StatelessWidget {
  const ProfileActionBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: ProfileTokens.canvas,
        border: Border(top: BorderSide(color: ProfileTokens.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(children: children),
        ),
      ),
    );
  }
}

/// Pilule d’action principale d’une feuille.
class ProfilePillButton extends StatelessWidget {
  const ProfilePillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: ProfileTokens.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        textStyle: ProfileText.actionLabel,
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: 8),
          ],
          Text(label),
        ],
      ),
    );
  }
}

/// Bouton carré discret pour les actions secondaires (copie, partage).
class ProfileQuietIconButton extends StatelessWidget {
  const ProfileQuietIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      iconSize: 17,
      style: IconButton.styleFrom(
        minimumSize: const Size(
          ProfileTokens.touchTarget,
          ProfileTokens.touchTarget,
        ),
        maximumSize: const Size(
          ProfileTokens.touchTarget,
          ProfileTokens.touchTarget,
        ),
        padding: EdgeInsets.zero,
        side: const BorderSide(color: ProfileTokens.border),
        foregroundColor: ProfileTokens.muted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ProfileTokens.radiusField),
        ),
      ),
      icon: Icon(icon),
    );
  }
}

/// Petite pastille arrondie, utilisée pour les technologies.
class ProfileChip extends StatelessWidget {
  const ProfileChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: ProfileTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ProfileTokens.border),
      ),
      child: Text(label, style: ProfileText.chip),
    );
  }
}
