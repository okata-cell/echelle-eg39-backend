// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'package:flutter/material.dart';

import 'actualite.dart';
import 'actualites_repository.dart';
import 'profile_theme.dart';
import 'widgets/actualites_section.dart';
import 'widgets/profile_sheet.dart';

/// Écran « Toutes les actualités », dans le même langage que la section
/// d'accueil : une annonce en tête, puis la grille des précédentes.
///
/// Les annonces elles-mêmes ne sont pas cliquables ; cet écran sert seulement
/// à sortir de la limite de trois éléments de l'accueil.
class ActualitesScreen extends StatefulWidget {
  const ActualitesScreen({
    super.key,
    this.repository,
    this.initialItems = const <Actualite>[],
  });

  final ActualitesRepository? repository;

  /// Annonces déjà connues de l'accueil : la liste s'affiche sans attendre.
  final List<Actualite> initialItems;

  @override
  State<ActualitesScreen> createState() => _ActualitesScreenState();
}

class _ActualitesScreenState extends State<ActualitesScreen> {
  late final ActualitesRepository _repository =
      widget.repository ?? ActualitesRepository();

  late List<Actualite> _items = widget.initialItems;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final snapshot = await _repository.refresh(
        limit: ActualitesRepository.listLimit,
      );
      if (!mounted) return;
      setState(() {
        _items = snapshot.items;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProfileSheetScaffold(
      title: 'Toutes les actualités',
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(color: ProfileTokens.primary),
        ),
      );
    }

    if (_errorMessage != null && _items.isEmpty) {
      return _ErrorState(message: _errorMessage!, onRetry: _load);
    }

    if (_items.isEmpty) {
      return const _EmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ActualiteHeroCard(actualite: _items.first),
        if (_items.length > 1) ...[
          const SizedBox(height: 20),
          ActualiteGrid(items: _items.skip(1).toList(growable: false)),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(
            Icons.newspaper_outlined,
            size: 40,
            color: ProfileTokens.chevron,
          ),
          const SizedBox(height: 12),
          Text('Aucune actualité publiée', style: ProfileText.sectionTitle),
          const SizedBox(height: 6),
          Text(
            'Les prochaines annonces de l’agence apparaîtront ici.',
            textAlign: TextAlign.center,
            style: ProfileText.rowSubtitle,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 40,
            color: ProfileTokens.danger,
          ),
          const SizedBox(height: 12),
          Text(
            'Impossible de charger les actualités',
            textAlign: TextAlign.center,
            style: ProfileText.sectionTitle,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: ProfileText.rowSubtitle,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ProfileTokens.primary,
              side: const BorderSide(color: ProfileTokens.primary),
              minimumSize: const Size(0, ProfileTokens.touchTarget),
            ),
          ),
        ],
      ),
    );
  }
}
