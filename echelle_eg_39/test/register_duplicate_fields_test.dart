import 'package:echelle_eg_39/api_service.dart';
import 'package:echelle_eg_39/register.page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Inscription refusée par le serveur sur un champ précis.
Future<Map<String, dynamic>> refuseAvecChamps(List<String> champs) async {
  throw ApiException(
    type: ApiErrorType.request,
    message: champs.length == 2
        ? 'Cet e-mail et ce numéro de téléphone sont déjà utilisés.'
        : champs.first == 'email'
        ? 'Cette adresse e-mail est déjà utilisée.'
        : 'Ce numéro de téléphone est déjà utilisé.',
    statusCode: 409,
    fields: champs,
  );
}

Future<void> remplirFormulaire(WidgetTester tester) async {
  final champs = find.byType(TextFormField);
  await tester.enterText(champs.at(0), 'Ama');
  await tester.enterText(champs.at(1), 'Kossi');
  await tester.enterText(champs.at(2), 'silvaokata@gmail.com');
  await tester.enterText(champs.at(3), '90112233');
  await tester.enterText(champs.at(4), 'Zq7#Lm2!Pr9@Vt4\$');
  await tester.enterText(champs.at(5), 'Zq7#Lm2!Pr9@Vt4\$');
  await tester.pumpAndSettle();
}

Future<void> envoyer(WidgetTester tester) async {
  final bouton = find.byKey(const ValueKey('register-submit-button'));
  await tester.ensureVisible(bouton);
  await tester.pumpAndSettle();
  await tester.tap(bouton);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('e-mail déjà pris : le message tombe sous le champ e-mail', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RegisterPage(
          registerAccount: (_, _, _, _, _) => refuseAvecChamps(['email']),
          saveOfflineAccount: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await remplirFormulaire(tester);
    await envoyer(tester);

    expect(
      find.text('Cette adresse e-mail est déjà utilisée par un autre compte.'),
      findsOneWidget,
    );
    expect(find.textContaining('téléphone est déjà utilisé'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('numéro déjà pris : le message tombe sous le champ téléphone', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RegisterPage(
          registerAccount: (_, _, _, _, _) => refuseAvecChamps(['phone']),
          saveOfflineAccount: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await remplirFormulaire(tester);
    await envoyer(tester);

    expect(
      find.text('Ce numéro de téléphone est déjà utilisé par un autre compte.'),
      findsOneWidget,
    );
    expect(find.textContaining('adresse e-mail est déjà'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('les deux pris : les deux champs sont marqués', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RegisterPage(
          registerAccount: (_, _, _, _, _) =>
              refuseAvecChamps(['email', 'phone']),
          saveOfflineAccount: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await remplirFormulaire(tester);
    await envoyer(tester);

    expect(
      find.text('Cette adresse e-mail est déjà utilisée par un autre compte.'),
      findsOneWidget,
    );
    expect(
      find.text('Ce numéro de téléphone est déjà utilisé par un autre compte.'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
