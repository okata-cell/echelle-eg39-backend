// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'package:flutter/material.dart';

import '../profile_theme.dart';
import 'profile_sheet.dart';

/// Terme du glossaire : libellé et définition, en lecture seule.
typedef GlossaryTerm = ({String term, String definition});

/// Glossaire consultable : recherche puis index alphabétique.
class GlossaryScreen extends StatefulWidget {
  const GlossaryScreen({
    super.key,
    this.terms = defaultTerms,
  });

  /// Liste affichée, remplaçable pour les tests.
  final List<GlossaryTerm> terms;

  static const List<GlossaryTerm> defaultTerms = [
    (term: 'Altimétrie', definition: 'Mesure des altitudes et des hauteurs'),
    (term: 'Azimut', definition: 'Angle horizontal mesuré dans le sens horaire'),
    (term: 'Bornage', definition: 'Délimitation d’une propriété'),
    (term: 'Cadastre', definition: 'Enregistrement public des propriétés foncières'),
    (term: 'Gisement', definition: 'Angle horizontal mesuré à partir du nord'),
    (term: 'Nivellement', definition: 'Détermination des différences d’altitude'),
    (
      term: 'Station totale',
      definition: 'Instrument combinant théodolite et distancemètre',
    ),
  ];

  /// Repères d’index affichés : les termes présents tombent dans ces plages.
  static const List<({String label, String letters})> _index = [
    (label: 'A', letters: 'A'),
    (label: 'B–G', letters: 'BCDEFG'),
    (label: 'N–S', letters: 'NOPQRS'),
  ];

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<GlossaryTerm> get _visibleTerms {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.terms;
    return widget.terms
        .where(
          (entry) =>
              entry.term.toLowerCase().contains(query) ||
              entry.definition.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  /// Un terme sans repère connu prend sa propre initiale comme intitulé.
  String _labelFor(String term) {
    final letter = term.isEmpty ? '' : term.substring(0, 1).toUpperCase();
    for (final group in GlossaryScreen._index) {
      if (group.letters.contains(letter)) return group.label;
    }
    return letter;
  }

  void _clearSearch() {
    _controller.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final terms = _visibleTerms;
    final rows = <Widget>[];
    var currentLabel = '';

    for (final entry in terms) {
      final label = _labelFor(entry.term);
      if (label != currentLabel) {
        currentLabel = label;
        rows.add(_GlossaryIndexLabel(label: label));
      }
      rows.add(
        ProfileSheetRow(
          key: ValueKey('glossary-term-${entry.term}'),
          title: entry.term,
          subtitle: entry.definition,
          minHeight: 72,
        ),
      );
    }

    return ProfileSheetScaffold(
      title: 'Glossaire',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchField(),
          const SizedBox(height: 12),
          if (rows.isEmpty) _buildEmptyState() else ProfileCard(children: rows),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: ProfileTokens.touchTarget,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: ProfileTokens.surface,
        borderRadius: BorderRadius.circular(ProfileTokens.radiusField),
        border: Border.all(color: ProfileTokens.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: ProfileTokens.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: const ValueKey('glossary-search'),
              controller: _controller,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              style: ProfileText.fieldText,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Rechercher un terme',
                hintStyle: ProfileText.fieldText.copyWith(
                  color: ProfileTokens.muted,
                ),
              ),
            ),
          ),
          if (_query.isNotEmpty)
            IconButton(
              onPressed: _clearSearch,
              tooltip: 'Effacer la recherche',
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              color: ProfileTokens.muted,
              icon: const Icon(Icons.cancel),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text('Aucun terme trouvé.', style: ProfileText.listValue),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _clearSearch,
          style: TextButton.styleFrom(
            foregroundColor: ProfileTokens.primary,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, ProfileTokens.touchTarget),
          ),
          child: const Text('Effacer la recherche'),
        ),
      ],
    );
  }
}

class _GlossaryIndexLabel extends StatelessWidget {
  const _GlossaryIndexLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ProfileTokens.surfaceMuted,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(label, style: ProfileText.footNote),
    );
  }
}
