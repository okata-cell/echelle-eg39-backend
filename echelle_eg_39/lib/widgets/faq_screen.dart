import 'package:flutter/material.dart';

import '../profile_theme.dart';
import 'profile_sheet.dart';

/// FAQ consultable : chaque question révèle sa réponse sur place.
class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  /// La première réponse est ouverte à l’arrivée ; plusieurs peuvent l’être.
  final Set<int> _openEntries = {0};

  static const List<({String question, String answer})> _entries = [
    (
      question: 'Comment calibrer un GPS de précision ?',
      answer:
          'Pour calibrer un GPS de précision, placez-vous en zone dégagée et '
          'suivez les instructions du manuel.',
    ),
    (
      question: 'Quelle est la précision des GPS e-survey ?',
      answer: 'Les GPS e-survey ont une précision de 2-5mm en mode RTK.',
    ),
    (
      question: 'Comment régler un théodolite ?',
      answer:
          'Le réglage d’un théodolite nécessite une mise à niveau précise avec '
          'les vis calantes.',
    ),
    (
      question: 'Comment réserver un équipement ?',
      answer:
          'Utilisez la section Location de l’application pour vérifier la '
          'disponibilité et réserver.',
    ),
  ];

  void _toggle(int index) {
    setState(() {
      if (!_openEntries.remove(index)) _openEntries.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ProfileSheetScaffold(
      title: 'FAQ dynamique',
      child: ProfileCard(
        children: [
          for (var index = 0; index < _entries.length; index++)
            _FaqEntry(
              key: ValueKey('faq-entry-$index'),
              question: _entries[index].question,
              answer: _entries[index].answer,
              isOpen: _openEntries.contains(index),
              onTap: () => _toggle(index),
            ),
        ],
      ),
    );
  }
}

class _FaqEntry extends StatelessWidget {
  const _FaqEntry({
    super.key,
    required this.question,
    required this.answer,
    required this.isOpen,
    required this.onTap,
  });

  final String question;
  final String answer;
  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: isOpen,
      label: question,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        question,
                        style: ProfileText.rowTitle.copyWith(
                          color: isOpen
                              ? ProfileTokens.primary
                              : ProfileTokens.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      isOpen ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: isOpen
                          ? ProfileTokens.primary
                          : ProfileTokens.chevron,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(answer, style: ProfileText.documentBody),
            ),
        ],
      ),
    );
  }
}
