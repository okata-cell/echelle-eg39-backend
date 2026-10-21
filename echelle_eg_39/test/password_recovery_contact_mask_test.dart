import 'package:echelle_eg_39/password_recovery_contact_mask.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('maskRecoveryContact', () {
    test('conserve la première lettre et le domaine de l’e-mail', () {
      expect(
        maskRecoveryContact('  Marie@example.com ', isEmail: true),
        'M•••@example.com',
      );
    });

    test('conserve le préfixe Togo et les deux derniers chiffres', () {
      expect(
        maskRecoveryContact('+228 90 12 34 56', isEmail: false),
        '+228 •••••• 56',
      );
      expect(maskRecoveryContact('90123456', isEmail: false), '+228 •••••• 56');
    });

    test('masque les contacts trop courts sans exposer leur contenu', () {
      expect(maskRecoveryContact('m', isEmail: true), '••••••');
      expect(maskRecoveryContact('12', isEmail: false), '•••••• 12');
    });
  });
}
