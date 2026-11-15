import 'package:echelle_eg_39/api_service.dart';
import 'package:echelle_eg_39/login_feedback.dart';
import 'package:echelle_eg_39/login.page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('refus du serveur posé sur le bon champ', () {
    test('un mauvais mot de passe n’accuse que le mot de passe', () {
      final feedback = feedbackConnexion(
        const ApiException(
          type: ApiErrorType.invalidPassword,
          message: 'Mot de passe incorrect',
          statusCode: 401,
        ),
        identifiantEstEmail: true,
      );

      expect(
        feedback.erreurMotDePasse,
        'Mot de passe incorrect pour ce compte.',
      );
      expect(feedback.erreurIdentifiant, isNull);
    });

    test('un identifiant inconnu parle de ce qui a été saisi', () {
      final email = feedbackConnexion(
        const ApiException(
          type: ApiErrorType.invalidIdentifier,
          message: 'Email ou téléphone introuvable',
          statusCode: 401,
        ),
        identifiantEstEmail: true,
      );
      expect(
        email.erreurIdentifiant,
        'Aucun compte avec cette adresse e-mail.',
      );
      expect(email.erreurMotDePasse, isNull);

      final telephone = feedbackConnexion(
        const ApiException(
          type: ApiErrorType.invalidIdentifier,
          message: 'Email ou téléphone introuvable',
          statusCode: 401,
        ),
        identifiantEstEmail: false,
      );
      expect(
        telephone.erreurIdentifiant,
        'Aucun compte avec ce numéro de téléphone.',
      );
    });

    test('un blocage ou une panne ne désigne aucun champ', () {
      for (final type in [
        ApiErrorType.accountLocked,
        ApiErrorType.accountDeleted,
        ApiErrorType.network,
        ApiErrorType.serverUnavailable,
        ApiErrorType.invalidCredentials,
      ]) {
        final feedback = feedbackConnexion(
          ApiException(type: type, message: 'peu importe'),
          identifiantEstEmail: true,
        );
        expect(feedback.aUneErreurDeChamp, isFalse);
      }
    });
  });

  group('écran de connexion', () {
    setUpAll(() {
      GoogleFonts.config.allowRuntimeFetching = false;
    });

    testWidgets('signale le champ identifiant vide sous le champ', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(const MaterialApp(home: LoginPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      expect(
        find.text('Saisissez votre e-mail ou votre numéro de téléphone.'),
        findsOneWidget,
      );
      // Aucun snack-bar : le message vit sous le champ concerné.
      expect(find.byType(SnackBar), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('signale un identifiant au mauvais format', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(const MaterialApp(home: LoginPage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '0707070707');
      await tester.enterText(find.byType(TextField).last, 'Zq7#Lm2!Pr9@Vt4\$');
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      expect(
        find.text('Numéro incomplet : +228 suivi de 8 ou 9 chiffres.'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('signale le mot de passe vide sous son champ', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(const MaterialApp(home: LoginPage()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).first,
        'silvaokata@gmail.com',
      );
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      expect(find.text('Saisissez votre mot de passe.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
