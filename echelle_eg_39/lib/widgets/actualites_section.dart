// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'package:flutter/material.dart';

import '../actualite.dart';
import '../profile_theme.dart';

/// Section « Dernières actualités » de l'accueil, dans sa version « vitrine
/// imagée » : une annonce pleine largeur portant son titre sur la photo, puis
/// les annonces suivantes en tuiles de deux colonnes.
///
/// Aucune carte n'est cliquable : seule l'action « Voir tout » ouvre la liste.
/// C'est pourquoi les textes ne sont jamais tronqués par un « lire la suite »
/// et que l'épinglage se lit à la taille, pas à une pastille.
class ActualitesSection extends StatelessWidget {
  const ActualitesSection({
    super.key,
    required this.items,
    required this.isLoading,
    required this.onSeeAll,
  });

  final List<Actualite> items;
  final bool isLoading;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final bool hasItems = items.isNotEmpty;
    // Une section vide n'a rien à raconter : on ne laisse pas un bloc fantôme
    // sur l'accueil quand l'administrateur n'a rien publié, ni quand le serveur
    // est injoignable et qu'aucune actualité n'est en cache.
    if (!isLoading && !hasItems) {
      return const SizedBox.shrink();
    }

    final Actualite? hero = hasItems ? items.first : null;
    final List<Actualite> tiles = items.length > 1
        ? items.skip(1).take(4).toList(growable: false)
        : const [];

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(onSeeAll: onSeeAll),
          if (isLoading && !hasItems)
            const _ActualitesSkeleton()
          else if (hero != null) ...[
            ActualiteHeroCard(actualite: hero),
            if (tiles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  ProfileTokens.pagePadding,
                  16,
                  ProfileTokens.pagePadding,
                  0,
                ),
                child: ActualiteGrid(items: tiles),
              ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ProfileTokens.pagePadding,
        0,
        ProfileTokens.pagePadding,
        12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('Dernières actualités', style: ProfileText.sheetTitle),
          ),
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              foregroundColor: ProfileTokens.primary,
              minimumSize: const Size(0, ProfileTokens.touchTarget),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              textStyle: ProfileText.actionLabel,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Voir tout'),
                SizedBox(width: 2),
                Icon(Icons.arrow_forward, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Annonce mise en avant : photo pleine largeur et légende sur la partie basse,
/// comme une affiche. L'absence de photo donne un aplat d'encre, jamais un
/// cadre gris « image manquante ».
class ActualiteHeroCard extends StatelessWidget {
  const ActualiteHeroCard({super.key, required this.actualite});

  final Actualite actualite;

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = actualite.imageUrl;
    final bool hasImage = actualite.hasImage;

    return Semantics(
      container: true,
      label:
          '${actualite.epingle ? 'Actualité épinglée' : 'À la une'} : '
          '${actualite.titre}. ${actualite.description}. '
          '${actualite.periodeLabel}',
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                semanticLabel: 'Photo de l’actualité ${actualite.titre}',
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) return child;
                  return const ColoredBox(color: ProfileTokens.ink);
                },
                errorBuilder: (context, error, stackTrace) =>
                    const ColoredBox(color: ProfileTokens.ink),
              )
            else
              const ColoredBox(color: ProfileTokens.ink),
            if (hasImage)
              const DecoratedBox(
                decoration: BoxDecoration(
                  // La légende occupe désormais trois lignes de texte : le
                  // voile descend plus haut pour que la description reste
                  // lisible sur une photo claire.
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000),
                      Color(0x73000000),
                      Color(0xCC000000),
                    ],
                    stops: [0.2, 0.58, 1],
                  ),
                ),
              ),
            Positioned(
              left: ProfileTokens.pagePadding,
              right: ProfileTokens.pagePadding,
              bottom: ProfileTokens.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actualite.titre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ProfileText.sheetTitle.copyWith(
                      color: Colors.white,
                      height: 1.19,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // L'annonce mise en avant se lit comme les autres : sans sa
                  // description, l'épinglée serait la seule carte muette de la
                  // section, sur l'accueil comme dans « Toutes les actualités ».
                  Text(
                    actualite.description,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: ProfileText.rowSubtitle.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      height: 1.38,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    actualite.periodeLabel,
                    style: ProfileText.footNote.copyWith(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tuile d'annonce : photo carrée légendée. Le texte reste lisible sans
/// interaction, c'est la raison d'être de cette mise en page.
class ActualiteTile extends StatelessWidget {
  const ActualiteTile({super.key, required this.actualite});

  final Actualite actualite;

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = actualite.imageUrl;

    return Semantics(
      container: true,
      label: 'Actualité : ${actualite.titre}, ${actualite.periodeLabel}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: actualite.hasImage
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      semanticLabel: 'Photo de l’actualité ${actualite.titre}',
                      frameBuilder:
                          (context, child, frame, wasSynchronouslyLoaded) {
                            if (wasSynchronouslyLoaded || frame != null) {
                              return child;
                            }
                            return const ColoredBox(color: ProfileTokens.ink);
                          },
                      errorBuilder: (context, error, stackTrace) =>
                          const ColoredBox(color: ProfileTokens.ink),
                    )
                  : const ColoredBox(color: ProfileTokens.ink),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            actualite.titre,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ProfileText.rowTitle.copyWith(fontSize: 14, height: 1.3),
          ),
          const SizedBox(height: 5),
          Text(
            actualite.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ProfileText.rowSubtitle.copyWith(
              color: ProfileTokens.ink.withValues(alpha: 0.72),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            actualite.periodeLabel,
            style: ProfileText.footNote.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grille des annonces : deux colonnes sur téléphone, trois sur tablette.
class ActualiteGrid extends StatelessWidget {
  const ActualiteGrid({super.key, required this.items, this.spacing = 16});

  final List<Actualite> items;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final int columns = constraints.maxWidth >= 560 ? 3 : 2;
        final double width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: 20,
          children: [
            for (final actualite in items)
              SizedBox(
                width: width,
                child: ActualiteTile(actualite: actualite),
              ),
          ],
        );
      },
    );
  }
}

class _ActualitesSkeleton extends StatelessWidget {
  const _ActualitesSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AspectRatio(
          aspectRatio: 4 / 3,
          child: ColoredBox(color: ProfileTokens.initials),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ProfileTokens.pagePadding,
            16,
            ProfileTokens.pagePadding,
            0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < 2; index++) ...[
                if (index > 0) const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AspectRatio(
                        aspectRatio: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: ProfileTokens.initials,
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: ProfileTokens.initials,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FractionallySizedBox(
                        widthFactor: 0.7,
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: ProfileTokens.initials,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
