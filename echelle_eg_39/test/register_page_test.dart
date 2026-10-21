import 'package:echelle_eg_39/api_service.dart';
import 'package:echelle_eg_39/offline_registration_store.dart';
import 'package:echelle_eg_39/password_recovery_scaffold.dart';
import 'package:echelle_eg_39/register.page.dart';
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

  Future<void> fillValidForm(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).at(0), 'Afi');
    await tester.enterText(find.byType(TextFormField).at(1), 'Koffi');
    await tester.enterText(find.byType(TextFormField).at(2), 'afi@example.com');
    await tester.enterText(find.byType(TextFormField).at(3), '90000000');
    await tester.enterText(find.byType(TextFormField).at(4), '1234AZER');
    await tester.enterText(find.byType(TextFormField).at(5), '1234AZER');
  }

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

  testWidgets('enregistre hors ligne uniquement via le callback sécurisé', (
    tester,
  ) async {
    OfflineRegistrationDraft? capturedDraft;
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
    await tester.ensureVisible(
      find.byKey(const ValueKey('register-submit-button')),
    );
    await tester.tap(find.byKey(const ValueKey('register-submit-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(capturedDraft?.firstName, 'Afi');
    expect(capturedDraft?.lastName, 'Koffi');
    expect(capturedDraft?.phone, '+22890000000');
    expect(capturedDraft?.password, '1234AZER');
    expect(
      find.text(
        'Inscription enregistrée sur cet appareil. Synchronisation en attente.',
      ),
      findsOneWidget,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('userPassword'), isNull);
    expect(prefs.getString('offline_registration_metadata_v2'), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
