import 'package:echelle_eg_39/forgot_password.page.dart';
import 'package:echelle_eg_39/password_recovery_contact_mask.dart';
import 'package:echelle_eg_39/reset_password.page.dart';
import 'package:echelle_eg_39/widgets/temporary_password_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'conserve e-mail par défaut et affiche le téléphone et le code',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ForgotPasswordPage()));
      await tester.pump();

      expect(find.byKey(const ValueKey('recovery-email')), findsOneWidget);
      expect(find.text('Adresse e-mail'), findsOneWidget);
      expect(find.text('Numéro de téléphone'), findsNothing);
      expect(find.byKey(const ValueKey('recovery-code')), findsOneWidget);
      expect(find.text('Code de récupération'), findsOneWidget);

      await tester.tap(find.text('Téléphone'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('recovery-phone')), findsOneWidget);
      expect(find.byKey(const ValueKey('recovery-email')), findsNothing);
      expect(find.byKey(const ValueKey('recovery-code')), findsOneWidget);
    },
  );

  testWidgets(
    'transmet contact, canal et code puis affiche le mot de passe temporaire',
    (tester) async {
      String? sentContact;
      String? sentType;
      String? sentCode;

      await tester.pumpWidget(
        MaterialApp(
          home: ForgotPasswordPage(
            requestCode: (contact, type, recoveryCode) async {
              sentContact = contact;
              sentType = type;
              sentCode = recoveryCode;
              return const {
                'success': true,
                'temporaryPassword': '4821KLMN',
                'displaySeconds': 120,
              };
            },
            updatePassword: (_) async => const {'success': true},
            clearResetToken: () async {},
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('recovery-email')),
        ' Afi@example.com ',
      );
      await tester.enterText(
        find.byKey(const ValueKey('recovery-code')),
        'eg39-abcd-2345',
      );
      await tester.ensureVisible(find.text('Obtenir mon accès'));
      await tester.tap(find.text('Obtenir mon accès'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(sentContact, 'Afi@example.com');
      expect(sentType, 'email');
      expect(sentCode, 'eg39-abcd-2345');

      expect(find.byType(TemporaryPasswordDialog), findsOneWidget);
      expect(find.text('4821KLMN'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('temporary-password-choose-own')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ResetPasswordPage), findsOneWidget);
      expect(find.text('Choisissez un nouveau mot de passe'), findsOneWidget);
    },
  );

  testWidgets('un refus du serveur est affiché sans ouvrir de popup', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ForgotPasswordPage(
          requestCode: (_, _, _) async => const {
            'success': false,
            'code': 'RECOVERY_DENIED',
            'error': 'Identifiant ou code de récupération incorrect.',
          },
          clearResetToken: () async {},
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('recovery-email')),
      'afi@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('recovery-code')),
      'ABCD2345',
    );
    await tester.ensureVisible(find.text('Obtenir mon accès'));
    await tester.tap(find.text('Obtenir mon accès'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('Identifiant ou code de récupération incorrect.'),
      findsOneWidget,
    );
    expect(find.byType(TemporaryPasswordDialog), findsNothing);
  });

  testWidgets('un code incomplet est refusé avant tout appel', (tester) async {
    var called = false;

    await tester.pumpWidget(
      MaterialApp(
        home: ForgotPasswordPage(
          requestCode: (_, _, _) async {
            called = true;
            return const {'success': false};
          },
          clearResetToken: () async {},
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('recovery-email')),
      'afi@example.com',
    );
    await tester.enterText(find.byKey(const ValueKey('recovery-code')), 'AB');
    await tester.ensureVisible(find.text('Obtenir mon accès'));
    await tester.tap(find.text('Obtenir mon accès'));
    await tester.pump();

    expect(called, false);
    expect(
      find.text('Le code compte 8 caractères, par exemple EG39-ABCD-EFGH.'),
      findsOneWidget,
    );
  });

  testWidgets('nouveau mot de passe respecte la règle du serveur', (
    tester,
  ) async {
    String? savedPassword;
    await tester.pumpWidget(
      MaterialApp(
        home: ResetPasswordPage(
          contactInfo: 'afi@example.com',
          contactType: RecoveryContactType.email,
          updatePassword: (password) async {
            savedPassword = password;
            return const {'success': true};
          },
          clearResetToken: () async {},
        ),
      ),
    );
    await tester.pump();

    final password = find.byKey(const ValueKey('recovery-new-password'));
    final confirmation = find.byKey(
      const ValueKey('recovery-confirm-password'),
    );
    await tester.enterText(password, 'abcdef');
    await tester.enterText(confirmation, 'abcdef');
    await tester.ensureVisible(find.text('Mettre à jour le mot de passe'));
    await tester.tap(find.text('Mettre à jour le mot de passe'));
    await tester.pump();
    expect(
      find.text('6 caractères minimum, dont une lettre et un chiffre.'),
      findsOneWidget,
    );
    expect(savedPassword, isNull);

    await tester.enterText(password, '1234AZER');
    await tester.enterText(confirmation, '1234AZEZ');
    await tester.pumpAndSettle();
    expect(
      find.text('Les mots de passe ne correspondent pas.'),
      findsOneWidget,
    );
    expect(savedPassword, isNull);

    await tester.enterText(confirmation, '1234AZER');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mettre à jour le mot de passe'));
    await tester.pump();
    expect(savedPassword, '1234AZER');

    await tester.pump(const Duration(milliseconds: 1500));
  });

  test('le contact masqué reste distinct du contact transmis au serveur', () {
    const rawContact = 'afi@example.com';
    expect(maskRecoveryContact(rawContact, isEmail: true), 'a•••@example.com');
    expect(rawContact, 'afi@example.com');
  });
}
