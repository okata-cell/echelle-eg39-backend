import 'package:echelle_eg_39/password_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PasswordPolicy', () {
    test('accepte les caractères spéciaux et les phrases longues', () {
      expect(PasswordPolicy.validate('Chantier#2026'), isNull);
      expect(PasswordPolicy.validate('Bornes.Leica-2026'), isNull);
      expect(PasswordPolicy.validate('Métré+récép 2026!'), isNull);
      expect(
        PasswordPolicy.validate(
          'Nivellement du terrain nord-ouest, 12 bornes à 30 m #2026',
        ),
        isNull,
      );
    });

    test('impose dix caractères et un plafond large', () {
      expect(
        PasswordPolicy.validate('Ab3!56789'),
        'Le mot de passe doit contenir au moins 10 caractères.',
      );
      expect(
        PasswordPolicy.validate('Ab3!' * 40),
        'Le mot de passe ne peut pas dépasser 128 caractères.',
      );
    });

    test('impose trois familles de caractères', () {
      expect(PasswordPolicy.validate('terrainnord'), contains('trois familles'));
      expect(
        PasswordPolicy.validate('terrainnord12'),
        contains('trois familles'),
      );
      expect(PasswordPolicy.validate('terrainnord1!'), isNull);
    });

    test('refuse les mots de passe évidents', () {
      // `azerty1234` tombe d'abord sur la règle des trois familles.
      expect(PasswordPolicy.validate('azerty1234'), contains('trois familles'));
      expect(PasswordPolicy.validate('Azerty1234!'), contains('plus courants'));
      expect(PasswordPolicy.validate('Password123!'), contains('plus courants'));
    });

    test('refuse les répétitions et les suites', () {
      expect(
        PasswordPolicy.validate('Aaaa1!vvvv'),
        contains('répéter quatre fois'),
      );
      expect(
        PasswordPolicy.validate('Abcd1234!x'),
        contains('suites de caractères'),
      );
    });

    test('refuse le nom, l’e-mail et le téléphone du titulaire', () {
      String? refus(String password) => PasswordPolicy.validate(
        password,
        firstName: 'Afi',
        lastName: 'Koffi',
        email: 'afi.koffi@example.com',
        phone: '+22890718293',
      );

      expect(refus('Afi#Chantier26'), contains('votre nom'));
      expect(refus('Koffi#2026!x'), contains('votre nom'));
      expect(refus('afi.koffi#2026!'), contains('votre nom'));
      expect(refus('Terrain#718293'), contains('votre nom'));
      expect(refus('Nivellement#2026'), isNull);
    });

    test('la règle affichée reste lisible', () {
      expect(PasswordPolicy.rules, contains('10 caractères minimum'));
      expect(PasswordPolicy.rules, contains('trois familles'));
    });
  });
}
