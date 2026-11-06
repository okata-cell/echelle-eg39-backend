// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'support_knowledge.dart';

/// Réponse du répondeur local.
class AssistantReply {
  const AssistantReply({
    required this.answer,
    required this.matchedLabel,
    required this.followUpQuestions,
  });

  final String answer;

  /// Thème reconnu, utile pour la journalisation.
  final String matchedLabel;

  /// Questions proches, proposées pour affiner la demande.
  final List<String> followUpQuestions;
}

/// Répondeur local de l’assistant support.
///
/// Fonctionne hors ligne, sans clé API et sans coût : il compare les mots de la
/// question à la fiche de l’entreprise et ne répond que sur des faits
/// connus. En cas de doute il ne répond pas, et l’application transmet la
/// demande au support humain.
class SupportAssistant {
  const SupportAssistant({this.minimumScore = 4});

  /// Score minimal pour répondre sans intervention humaine.
  final int minimumScore;

  static const String greetingAnswer =
      'Bonjour. Posez votre question sur nos services, nos horaires, notre '
      'adresse ou nos équipements : je réponds à partir de la fiche de '
      'l’entreprise. Sinon, votre message est transmis à l’équipe.';

  static const Set<String> _stopWords = {
    'le',
    'la',
    'les',
    'un',
    'une',
    'des',
    'de',
    'du',
    'd',
    'l',
    'a',
    'au',
    'aux',
    'et',
    'ou',
    'en',
    'pour',
    'par',
    'sur',
    'avec',
    'sans',
    'dans',
    'est',
    'sont',
    'etes',
    'etre',
    'que',
    'qui',
    'quoi',
    'quel',
    'quelle',
    'quels',
    'quelles',
    'comment',
    'combien',
    'quand',
    'pourquoi',
    'je',
    'tu',
    'il',
    'elle',
    'nous',
    'vous',
    'ils',
    'elles',
    'mon',
    'ma',
    'mes',
    'ton',
    'ta',
    'tes',
    'son',
    'sa',
    'ses',
    'votre',
    'vos',
    'notre',
    'nos',
    'ce',
    'cette',
    'ces',
    's',
    'y',
    'ne',
    'pas',
    'plus',
    'moins',
    'svp',
    'plait',
    'bonjour',
    'bonsoir',
    'salut',
    'merci',
    'cordialement',
    'voudrais',
    'vouloir',
    'peux',
    'peut',
    'pouvez',
    'avoir',
    'faites',
    'faire',
    'savoir',
    'dire',
    'stp',
    'cherche',
    'besoin',
    'info',
    'information',
    'informations',
    'renseignement',
    'renseignements',
  };

  static const Map<String, String> _accents = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ä': 'a',
    'ã': 'a',
    'ç': 'c',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ñ': 'n',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ÿ': 'y',
    'œ': 'oe',
    'æ': 'ae',
  };

  /// Minuscules, sans accents ni ponctuation, espaces normalisés.
  static String normalize(String input) {
    final buffer = StringBuffer();
    for (final rune in input.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      if (_accents.containsKey(char)) {
        buffer.write(_accents[char]);
      } else if (RegExp(r'[a-z0-9]').hasMatch(char)) {
        buffer.write(char);
      } else {
        buffer.write(' ');
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Singulier approximatif : « equipements » et « equipement » se rejoignent.
  static String _stem(String token) {
    if (token.length > 4 && token.endsWith('s')) {
      return token.substring(0, token.length - 1);
    }
    return token;
  }

  static Set<String> _significantTokens(String text) => normalize(text)
      .split(' ')
      .where((token) => token.isNotEmpty && !_stopWords.contains(token))
      .map(_stem)
      .toSet();

  /// Retourne une réponse si la question correspond à un fait connu.
  AssistantReply? answer(String question) {
    final normalized = normalize(question);
    if (normalized.isEmpty) {
      return const AssistantReply(
        answer: greetingAnswer,
        matchedLabel: 'Accueil',
        followUpQuestions: [],
      );
    }

    final tokens = _significantTokens(question);
    if (tokens.isEmpty) {
      return const AssistantReply(
        answer: greetingAnswer,
        matchedLabel: 'Accueil',
        followUpQuestions: [],
      );
    }

    SupportTopic? bestTopic;
    var bestScore = 0;
    final scored = <(SupportTopic, int)>[];

    for (final topic in kSupportTopics) {
      final questionTokens = _significantTokens(topic.question);
      var keywordHits = 0;
      for (final keyword in topic.keywords) {
        final normalizedKeyword = normalize(keyword);
        if (normalizedKeyword.contains(' ')) {
          if (normalized.contains(normalizedKeyword)) keywordHits += 2;
        } else if (tokens.contains(_stem(normalizedKeyword))) {
          keywordHits += 1;
        }
      }
      final overlap = tokens.where(questionTokens.contains).length;
      final score = 2 * keywordHits + 3 * overlap;
      if (score > 0) scored.add((topic, score));
      if (score > bestScore) {
        bestScore = score;
        bestTopic = topic;
      }
    }

    if (bestTopic == null || bestScore < minimumScore) return null;

    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final followUp = scored
        .where((entry) => entry.$1.question != bestTopic!.question)
        .map((entry) => entry.$1.question)
        .take(2)
        .toList();

    return AssistantReply(
      answer: bestTopic.answer,
      matchedLabel: bestTopic.question,
      followUpQuestions: followUp,
    );
  }
}
