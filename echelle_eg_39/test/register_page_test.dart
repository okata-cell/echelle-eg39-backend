import 'package:echelle_eg_39/api_service.dart';
import 'package:echelle_eg_39/offline_registration_store.dart';
import 'package:echelle_eg_39/password_recovery_scaffold.dart';
import 'package:echelle_eg_39/register.page.dart';
import 'package:echelle_eg_39/widgets/account_credentials_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  Future<void> fillValidForm(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).at(0), 'Afi');
    await tester.enterText(find.byType(TextFormField).at(1), 'Koffi');
    await tester.enterText(find.byType(TextFormField).at(2), 'afi@example.com');
    await tester.enterText(find.byType(TextFormField).at(3), '90000000');
    await tester.enterText(find.byType(TextFormField).at(4), '1234AZER');
    await tester.enterText(find.byType(TextFormField).at(5), '1234AZER');
  }

  Future<void> submitForm(WidgetTester tester) async {
    await tester.ensureVisible(
      find.byKey(const ValueKey('register-submit-button')),
    );
    await tester.tap(find.byKey(const ValueKey('register-submit-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  ValueNotifier<String?> captureClipboard() {
    final copied = ValueNotifier<String?>(null);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.value = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    return copied;
  }

  test('formate le numéro de téléphone en groupes lisibles', () {
    expect(formatAccountPhone('+22890000000'), '+228 90 00 00 00');
    expect(formatAccountPhone('+228901234567'), '+228 90 12 34 567');
    expect(formatAccountPhone('90000000'), '+228 90 00 00 00');
  });

  test('prépare le contenu copié dans le presse-papiers', () {
    const credentials = AccountCredentials(
      firstName: 'Afi',
      lastName: 'Koffi',
      email: 'afi@example.com',
      phone: '+22890000000',
      password: '1234AZER',
    );

    expect(credentials.clipboardText, contains('E-mail : afi@example.com'));
    expect(credentials.clipboardText, contains('Téléphone : +228 90 00 00 00'));
    expect(credentials.clipboardText, contains('Mot de passe : 1234AZER'));
    expect(
      credentials.clipboardText,
      contains('Gardez ces coordonnées dans un endroit sûr'),
    );
  });

  testWidgets('affiche le formulaire de compte avec le format togolais', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterPage()));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Créer un compte client'), findsOneWidget);
    expect(find.text('Vos coordonnées'), findsOneWidget);
    expect(find.text('+228'), findsOneWidget);
    expect(find.byType(PasswordRecoveryPhotoBackdrop), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(6));

    final phoneFieldFinder = find.byType(TextFormField).at(3);
    final phoneField = tester.widget<TextFormField>(phoneFieldFinder);
    final phoneDecorator = tester.widget<InputDecorator>(
      find.descendant(
        of: phoneFieldFinder,
        matching: find.byType(InputDecorator),
      ),
    );
    expect(phoneField.controller?.text, isEmpty);
    expect(phoneDecorator.decoration.hintText, '90000000');
    expect(find.text('Créer mon compte'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('register-submit-button')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('formate le téléphone et valide le mot de passe explicite', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterPage()));
    await tester.pump(const Duration(milliseconds: 600));

    final phoneField = find.byType(TextFormField).at(3);
    await tester.enterText(phoneField, '+228 90-12-34-567');
    expect(
      tester.widget<TextFormField>(phoneField).controller!.text,
      '901234567',
    );

    final passwordField = find.byType(TextFormField).at(4);
    await tester.enterText(passwordField, 'abcdef12');
    await tester.ensureVisible(
      find.byKey(const ValueKey('register-submit-button')),
    );
    await tester.tap(find.byKey(const ValueKey('register-submit-button')));
    await tester.pump();
    expect(
      find.text('4 chiffres puis 4 lettres majuscules (ex. 1234AZER).'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('affiche les identifiants après une création en ligne', (
    tester,
  ) async {
    final clipboard = captureClipboard();

    await tester.pumpWidget(
      MaterialApp(
        home: RegisterPage(registerAccount: (_, _, _, _, _) async => {'id': 7}),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await fillValidForm(tester);
    await submitForm(tester);

    final dialog = find.byType(AccountCredentialsDialog);
    expect(dialog, findsOneWidget);
    expect(find.text('Vos identifiants de connexion'), findsOneWidget);
    expect(
      find.text(
        'Le compte de Afi Koffi est actif. Voici ce qu’il faut conserver.',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('afi@example.com')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('+228 90 00 00 00')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('1234AZER')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('account-credentials-copy-close')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AccountCredentialsDialog), findsNothing);
    expect(
      find.text('Coordonnées copiées. Gardez-les en lieu sûr.'),
      findsOneWidget,
    );
    expect(clipboard.value, contains('Mot de passe : 1234AZER'));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('enregistre hors ligne uniquement via le callback sécurisé', (
    tester,
  ) async {
    OfflineRegistrationDraft? capturedDraft;
    final clipboard = captureClipboard();

    await tester.pumpWidget(
      MaterialApp(
        home: RegisterPage(
          registerAccount: (_, _, _, _, _) async => throw const ApiException(
            type: ApiErrorType.network,
            message: 'Réseau indisponible',
          ),
          saveOfflineAccount: (draft) async {
            capturedDraft = draft;
            return true;
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await fillValidForm(tester);
    await submitForm(tester);

    expect(capturedDraft?.firstName, 'Afi');
    expect(capturedDraft?.lastName, 'Koffi');
    expect(capturedDraft?.phone, '+22890000000');
    expect(capturedDraft?.password, '1234AZER');

    expect(find.byType(AccountCredentialsDialog), findsOneWidget);
    expect(
      find.text(
        'L’inscription de Afi Koffi est enregistrée. Voici ce qu’il faut conserver.',
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('account-credentials-copy-close')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text(
        'Coordonnées copiées. Inscription en attente de synchronisation.',
      ),
      findsOneWidget,
    );
    expect(clipboard.value, contains('Téléphone : +228 90 00 00 00'));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('userPassword'), isNull);
    expect(prefs.getString('offline_registration_metadata_v2'), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
