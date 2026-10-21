import 'package:echelle_eg_39/forgot_password.page.dart';
import 'package:echelle_eg_39/password_recovery_contact_mask.dart';
import 'package:echelle_eg_39/reset_password.page.dart';
import 'package:echelle_eg_39/verify_code.page.dart';
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
    'conserve e-mail par défaut et affiche le champ téléphone au choix',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ForgotPasswordPage()));
      await tester.pump();

      expect(find.byKey(const ValueKey('recovery-email')), findsOneWidget);
      expect(find.text('Adresse e-mail'), findsOneWidget);
      expect(find.text('Où recevoir votre code ?'), findsOneWidget);

      await tester.tap(find.text('Téléphone'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('recovery-phone')), findsOneWidget);
      expect(find.text('Numéro de téléphone'), findsOneWidget);
      expect(find.byKey(const ValueKey('recovery-email')), findsNothing);
    },
  );

  testWidgets('demande le code avec le contact et le canal sélectionnés', (
    tester,
  ) async {
    String? submittedContact;
    String? submittedType;
    await tester.pumpWidget(
      MaterialApp(
        home: ForgotPasswordPage(
          requestCode: (contact, type) async {
            submittedContact = contact;
            submittedType = type;
            return const {
              'success': true,
              'message':
                  'Si un compte existe avec ces informations, un code sera envoyé.',
            };
          },
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('recovery-email')),
      ' Afi@example.com ',
    );
    await tester.ensureVisible(find.text('Envoyer le code'));
    await tester.tap(find.text('Envoyer le code'));
    await tester.pumpAndSettle();

    expect(submittedContact, 'Afi@example.com');
    expect(submittedType, 'email');
    expect(find.byType(VerifyCodePage), findsOneWidget);
    expect(find.textContaining('A•••@example.com'), findsOneWidget);
  });

  testWidgets(
    'le renvoi OTP appelle à nouveau le backend sans montrer le code',
    (tester) async {
      var requestCount = 0;
      String? lastContact;
      String? lastType;
      await tester.pumpWidget(
        MaterialApp(
          home: ForgotPasswordPage(
            requestCode: (contact, type) async {
              requestCount++;
              lastContact = contact;
              lastType = type;
              return const {
                'success': true,
                'contactInfo': '+22890123456',
                'verificationCode': '123456',
              };
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Téléphone'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('recovery-phone')),
        '+22890123456',
      );
      await tester.ensureVisible(find.text('Envoyer le code'));
      await tester.tap(find.text('Envoyer le code'));
      await tester.pumpAndSettle();
      expect(requestCount, 1);

      await tester.ensureVisible(
        find.byKey(const ValueKey('recovery-resend-code')),
      );
      await tester.tap(find.byKey(const ValueKey('recovery-resend-code')));
      await tester.pumpAndSettle();

      expect(requestCount, 2);
      expect(lastContact, '+22890123456');
      expect(lastType, 'phone');
      expect(
        find.text(
          'Si un compte existe avec ce contact, un nouveau code sera envoyé.',
        ),
        findsOneWidget,
      );
      expect(find.text('123456'), findsNothing);
    },
  );

  testWidgets('un renvoi échoué n’affiche jamais une confirmation de succès', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VerifyCodePage(
          contactInfo: 'afi@example.com',
          contactType: RecoveryContactType.email,
          requestCode: (_, _) async => throw Exception('Service indisponible'),
          verifyCode: (_, _) async => const {'success': false},
          updatePassword: (_) async => const {'success': false},
          clearResetToken: () async {},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('recovery-resend-code')));
    await tester.pumpAndSettle();

    expect(find.text('Service indisponible'), findsOneWidget);
    expect(find.text('Nouveau code envoyé !'), findsNothing);
  });

  testWidgets('OTP valide ouvre la réinitialisation sans perdre le contact', (
    tester,
  ) async {
    String? verifiedCode;
    String? verifiedContact;
    await tester.pumpWidget(
      MaterialApp(
        home: VerifyCodePage(
          contactInfo: 'afi@example.com',
          contactType: RecoveryContactType.email,
          requestCode: (_, _) async => const {'success': true},
          verifyCode: (code, contact) async {
            verifiedCode = code;
            verifiedContact = contact;
            return const {'success': true, 'tempToken': 'temporary-token'};
          },
          updatePassword: (_) async => const {'success': true},
          clearResetToken: () async {},
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('recovery-otp-input')),
      '12x34567',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('recovery-otp-input')))
          .controller!
          .text,
      '123456',
    );
    await tester.ensureVisible(find.text('Vérifier le code'));
    await tester.tap(find.text('Vérifier le code'));
    await tester.pumpAndSettle();

    expect(verifiedCode, '123456');
    expect(verifiedContact, 'afi@example.com');
    expect(find.byType(ResetPasswordPage), findsOneWidget);
    expect(find.text('Choisissez un nouveau mot de passe'), findsOneWidget);

    await tester.tap(find.byTooltip('Retour à la vérification du code'));
    await tester.pumpAndSettle();
    expect(find.text('Continuer'), findsOneWidget);

    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(find.byType(ResetPasswordPage), findsOneWidget);
    expect(verifiedCode, '123456');
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

    await tester.enterText(password, 'abc123');
    await tester.enterText(confirmation, 'abc124');
    await tester.pumpAndSettle();
    expect(
      find.text('Les mots de passe ne correspondent pas.'),
      findsOneWidget,
    );
    expect(savedPassword, isNull);

    await tester.enterText(confirmation, 'abc123');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mettre à jour le mot de passe'));
    await tester.pump();
    expect(savedPassword, 'abc123');

    await tester.pump(const Duration(milliseconds: 1500));
  });

  test('le contact masqué reste distinct du contact transmis au serveur', () {
    const rawContact = 'afi@example.com';
    expect(maskRecoveryContact(rawContact, isEmail: true), 'a•••@example.com');
    expect(rawContact, 'afi@example.com');
  });
}
