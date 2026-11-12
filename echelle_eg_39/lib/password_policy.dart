// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

/// Règles de mot de passe, alignées sur celles du serveur.
///
/// L'application les applique pour guider la saisie ; le serveur reste seul
/// juge, avec une liste de mots interdits plus longue. Aucun caractère n'est
/// proscrit : les caractères spéciaux sont même encouragés, et la longueur
/// maximale laisse passer les phrases de passe.
abstract final class PasswordPolicy {
  static const int minLength = 10;
  static const int maxLength = 128;

  /// Rappel affiché sous les champs.
  static const String rules =
      '10 caractères minimum, dont trois familles parmi minuscules, '
      'majuscules, chiffres et caractères spéciaux.';

  /// Les mots de passe les plus évidents, refusés sans attendre le serveur.
  static const Set<String> _evidents = <String>{
    '1234567890',
    // Les racines seules comptent aussi : « Azerty1234! » ne doit pas passer
    // parce qu'on lui a ajouté des chiffres et un point d'exclamation.
    'azerty',
    'azerty1234',
    'qwerty',
    'admin',
    'welcome',
    'soleil',
    'testtest',
    'azertyuiop',
    'qwertyuiop',
    'motdepasse',
    'motdepasse1',
    'password',
    'password1',
    'password123',
    'admin1234',
    'bienvenue',
    'welcome1',
    'test1234',
    'echelle',
    'echelleeg39',
    'eg39',
    '1234AZER',
  };

  /// Message d'erreur, ou `null` si le mot de passe convient.
  ///
  /// [firstName], [lastName], [email] et [phone] servent à refuser un mot de
  /// passe qui reprendrait l'identité du titulaire.
  static String? validate(
    String? value, {
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
  }) {
    final password = value ?? '';
    if (password.isEmpty) return 'Le mot de passe est requis.';

    final longueur = password.runes.length;
    if (longueur < minLength) {
      return 'Le mot de passe doit contenir au moins $minLength caractères.';
    }
    if (longueur > maxLength) {
      return 'Le mot de passe ne peut pas dépasser $maxLength caractères.';
    }

    final familles = <bool>[
      RegExp(r'[a-z]').hasMatch(password),
      RegExp(r'[A-Z]').hasMatch(password),
      RegExp(r'[0-9]').hasMatch(password),
      RegExp(r'[^A-Za-z0-9]').hasMatch(password),
    ].where((presente) => presente).length;

    if (familles < 3) {
      return 'Ajoutez au moins trois familles de caractères : minuscules, '
          'majuscules, chiffres ou caractères spéciaux.';
    }

    final propre = _nettoyer(password);
    if (_evidents.contains(propre) ||
        _evidents.contains(propre.replaceAll(RegExp(r'[^a-z]'), ''))) {
      return 'Ce mot de passe fait partie des plus courants. '
          'Choisissez-en un autre.';
    }

    if (RegExp(r'(.)\1{3}').hasMatch(password)) {
      return 'Évitez de répéter quatre fois le même caractère.';
    }

    if (_contientUneSuite(password)) {
      return 'Évitez les suites de caractères comme 1234 ou abcd, '
          'faciles à deviner.';
    }

    for (final jeton in _elementsPersonnels(
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
    )) {
      if (propre.contains(jeton)) {
        return 'Le mot de passe ne doit pas reprendre votre nom, votre e-mail '
            'ou votre numéro de téléphone.';
      }
    }

    return null;
  }

  /// Vrai quand le mot de passe est acceptable (raccourci pour les tests).
  static bool isValid(String? value) => validate(value) == null;

  static String _nettoyer(String valeur) => valeur
      .toLowerCase()
      .replaceAll(RegExp('[àáâãäå]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[íìîï]'), 'i')
      .replaceAll(RegExp('[óòôö]'), 'o')
      .replaceAll(RegExp('[úùûü]'), 'u')
      .replaceAll(RegExp('ç'), 'c')
      .replaceAll(RegExp(r'\s+'), '');

  /// Quatre caractères consécutifs croissants ou décroissants.
  static bool _contientUneSuite(String password) {
    for (var index = 0; index + 3 < password.length; index += 1) {
      final a = password.codeUnitAt(index);
      final b = password.codeUnitAt(index + 1);
      final c = password.codeUnitAt(index + 2);
      final d = password.codeUnitAt(index + 3);

      if (b - a == 1 && c - b == 1 && d - c == 1) return true;
      if (b - a == -1 && c - b == -1 && d - c == -1) return true;
    }
    return false;
  }

  static List<String> _elementsPersonnels({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
  }) {
    final jetons = <String>{};

    void ajouter(String? valeur) {
      final propre = _nettoyer(valeur ?? '');
      if (propre.length >= 3) jetons.add(propre);
    }

    ajouter(firstName);
    ajouter(lastName);
    ajouter((email ?? '').split('@').first);

    final chiffres = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (chiffres.length >= 6) {
      ajouter(chiffres);
      ajouter(chiffres.substring(chiffres.length - 6));
    }

    return jetons.toList(growable: false);
  }
}
