// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'package:flutter/material.dart';

/// Couleurs partagées par les feuilles d’action du profil.
class AppActionPalette {
  const AppActionPalette._();

  static const Color ink = Color(0xFF1D1D1F);
  static const Color muted = Color(0xFF7A7A7A);
  static const Color accent = Color(0xFF2563EB);
  static const Color parchment = Color(0xFFF5F5F7);
  static const Color hairline = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFF0F0F0);
}

/// Vignette carrée qui porte une marque ou une icône de 16 à 18 px.
class AppGlyphTile extends StatelessWidget {
  const AppGlyphTile({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppActionPalette.parchment,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Center(child: child),
    );
  }
}

/// Bloc de lignes séparées par un filet, comme une table groupée iOS.
class AppActionGroup extends StatelessWidget {
  const AppActionGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) {
        rows.add(
          const Divider(
            height: 1,
            thickness: 1,
            color: AppActionPalette.divider,
          ),
        );
      }
      rows.add(children[index]);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppActionPalette.hairline),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(mainAxisSize: MainAxisSize.min, children: rows),
      ),
    );
  }
}

/// Ligne d’action : vignette, libellé et, au besoin, un état à droite.
class AppActionRow extends StatelessWidget {
  const AppActionRow({
    super.key,
    required this.leading,
    required this.label,
    required this.onTap,
    this.trailing,
    this.height = 44,
  });

  final Widget leading;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final double height;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppActionPalette.ink,
                  ),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}
