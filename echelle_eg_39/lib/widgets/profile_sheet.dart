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
    this.busy = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Envoi en cours : la pilule garde sa couleur et affiche un cercle d'attente.
  final bool busy;

  /// Action destructive (suppression de compte) : la pilule passe en rouge.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color accent = danger ? ProfileTokens.danger : ProfileTokens.primary;

    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: accent,
        disabledForegroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        textStyle: ProfileText.actionLabel,
        shape: const StadiumBorder(),
      ),
      child: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Row(
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

/// Tuile d’une grille de destinations : icône, libellé, chevron.
///
/// Le libellé est ancré en bas de la tuile pour que les quatre tuiles d’une
/// même rangée alignent leur texte, quelle que soit la longueur des intitulés.
class ProfileTile extends StatelessWidget {
  const ProfileTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.description,
    this.height = 112,
  });

  final IconData icon;
  final String label;
  final String? description;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: ProfileTokens.surface,
          borderRadius: BorderRadius.circular(ProfileTokens.radiusCard),
          border: Border.all(color: ProfileTokens.border),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(icon, size: 22, color: ProfileTokens.primary),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: _label()),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: ProfileTokens.chevron,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label() {
    if (description == null) {
      return Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: ProfileText.rowTitle.copyWith(fontSize: 15),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: ProfileText.rowTitle.copyWith(fontSize: 15),
        ),
        const SizedBox(height: 4),
        Text(
          description!,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: ProfileText.rowSubtitle,
        ),
      ],
    );
  }
}

/// Grille de tuiles à deux colonnes, gouttière de 12 px.
class ProfileTileGrid extends StatelessWidget {
  const ProfileTileGrid({super.key, required this.tiles, this.spacing = 12});

  final List<Widget> tiles;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var index = 0; index < tiles.length; index += 2) {
      final hasSecond = index + 1 < tiles.length;
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: tiles[index]),
            SizedBox(width: spacing),
            if (hasSecond)
              Expanded(child: tiles[index + 1])
            else
              const Expanded(child: SizedBox.shrink()),
          ],
        ),
      );
      if (index + 2 < tiles.length) rows.add(SizedBox(height: spacing));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// Sélecteur segmenté des groupes de champs d’une feuille de formulaire.
class ProfileSegmentedControl extends StatelessWidget {
  const ProfileSegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ProfileTokens.initials,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++)
            Expanded(
              child: Semantics(
                button: true,
                selected: index == selectedIndex,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () => onSelected(index),
                    child: Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: index == selectedIndex
                          ? BoxDecoration(
                              color: ProfileTokens.surface,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: ProfileTokens.border),
                            )
                          : null,
                      child: Text(
                        labels[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ProfileText.sheetRow.copyWith(
                          fontSize: 14,
                          fontWeight: index == selectedIndex
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: index == selectedIndex
                              ? ProfileTokens.ink
                              : ProfileTokens.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Champ de formulaire d’une feuille : libellé visible, mention facultative,
/// valeur saisie et message d’erreur éventuel.
class ProfileTextField extends StatelessWidget {
  const ProfileTextField({
    super.key,
    required this.label,
    required this.controller,
    this.optional = false,
    this.helperText,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.validator,
  });

  final String label;
  final TextEditingController controller;

  /// Ajoute « Facultatif » à droite du libellé ; le champ reste enregistrable
  /// vide.
  final bool optional;
  final String? helperText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final String? Function(String? value)? validator;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(ProfileTokens.radiusField),
      borderSide: const BorderSide(color: ProfileTokens.border),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: ProfileText.footNote)),
            if (optional) Text('Facultatif', style: ProfileText.footNote),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          validator: validator,
          style: ProfileText.fieldText,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: ProfileTokens.canvas,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: border,
            enabledBorder: border,
            disabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: const BorderSide(
                color: ProfileTokens.primary,
                width: 1.5,
              ),
            ),
            errorBorder: border.copyWith(
              borderSide: const BorderSide(color: ProfileTokens.danger),
            ),
            focusedErrorBorder: border.copyWith(
              borderSide: const BorderSide(
                color: ProfileTokens.danger,
                width: 1.5,
              ),
            ),
            errorStyle: ProfileText.footNote.copyWith(
              color: ProfileTokens.danger,
            ),
            helperText: helperText,
            helperStyle: ProfileText.footNote,
          ),
        ),
      ],
    );
  }
}
