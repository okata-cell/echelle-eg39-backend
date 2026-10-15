import 'dart:async';

import 'package:echelle_eg_39/quote_request_dialog.dart';
import 'package:echelle_eg_39/service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const _service = Service(
  id: '1',
  name: 'Levée de détail',
  description: 'Relevé précis du terrain.',
  category: 'Levés topographiques',
  imageUrl: '',
  features: [],
);

Widget _testApp({
  required QuoteRequestSubmit onSubmit,
  String initialTelephone = '+228 90 12 34 56',
  String requesterName = 'Afi Koffi',
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            key: const ValueKey('open-quote-dialog'),
            onPressed: () {
              showDialog<bool>(
                context: context,
                builder: (_) => QuoteRequestDialog(
                  serviceName: _service.name,
                  requesterName: requesterName,
                  initialTelephone: initialTelephone,
                  categoryColor: const Color(0xFF2563EB),
                  onSubmit: onSubmit,
                ),
              );
            },
            child: const Text('Ouvrir le formulaire'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('open-quote-dialog')));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('le nom obligatoire est assemblé depuis le profil', () {
    expect(
      quoteRequestNameFromProfile({
        'firstName': ' Afi ',
        'lastName': ' Koffi ',
      }),
      'Afi Koffi',
    );
    expect(
      quoteRequestNameFromProfile({'firstName': 'Afi', 'lastName': ''}),
      'Afi',
    );
    expect(
      quoteRequestNameFromProfile({'firstName': '', 'lastName': null}),
      '',
    );
  });

  testWidgets('montre seulement la description et le téléphone', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(onSubmit: (_) async {}));
    await _openDialog(tester);

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byKey(const ValueKey('quote-description')), findsOneWidget);
    expect(find.byKey(const ValueKey('quote-telephone')), findsOneWidget);
    expect(find.text('Votre nom complet'), findsNothing);
    expect(find.text('Email'), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('quote-telephone')))
          .controller!
          .text,
      '+228 90 12 34 56',
    );
  });

  testWidgets('valide la description et le téléphone avant envoi', (
    tester,
  ) async {
    var submitCalls = 0;
    await tester.pumpWidget(
      _testApp(
        initialTelephone: '',
        onSubmit: (_) async {
          submitCalls++;
        },
      ),
    );
    await _openDialog(tester);

    await tester.tap(find.byKey(const ValueKey('quote-submit-button')));
    await tester.pumpAndSettle();
    expect(find.text('La description est requise'), findsOneWidget);
    expect(find.text('Le téléphone est requis'), findsOneWidget);
    expect(submitCalls, 0);

    await tester.enterText(
      find.byKey(const ValueKey('quote-description')),
      'Court',
    );
    await tester.enterText(
      find.byKey(const ValueKey('quote-telephone')),
      '+228 90 12 34 56',
    );
    await tester.tap(find.byKey(const ValueKey('quote-submit-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Décrivez votre projet en détail (min. 10 caractères)'),
      findsOneWidget,
    );
    expect(submitCalls, 0);
  });

  testWidgets('transmet description, téléphone et nom du profil', (
    tester,
  ) async {
    QuoteRequestData? submitted;
    await tester.pumpWidget(
      _testApp(
        onSubmit: (request) async {
          submitted = request;
        },
      ),
    );
    await _openDialog(tester);

    await tester.enterText(
      find.byKey(const ValueKey('quote-description')),
      'Réaliser le relevé complet de la parcelle.',
    );
    await tester.enterText(
      find.byKey(const ValueKey('quote-telephone')),
      '+228 91 22 33 44',
    );
    await tester.tap(find.byKey(const ValueKey('quote-submit-button')));
    await tester.pumpAndSettle();

    expect(
      submitted?.description,
      'Réaliser le relevé complet de la parcelle.',
    );
    expect(submitted?.telephone, '+228 91 22 33 44');
    expect(submitted?.requesterName, 'Afi Koffi');
    expect(find.byType(QuoteRequestDialog), findsNothing);
  });

  testWidgets(
    'désactive les actions et montre la progression pendant l’envoi',
    (tester) async {
      final pendingSubmit = Completer<void>();
      await tester.pumpWidget(_testApp(onSubmit: (_) => pendingSubmit.future));
      await _openDialog(tester);

      await tester.enterText(
        find.byKey(const ValueKey('quote-description')),
        'Vérifier les limites et les niveaux du terrain.',
      );
      await tester.enterText(
        find.byKey(const ValueKey('quote-telephone')),
        '+228 90 12 34 56',
      );
      await tester.tap(find.byKey(const ValueKey('quote-submit-button')));
      await tester.pump();

      final submitButton = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('quote-submit-button')),
      );
      expect(submitButton.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      pendingSubmit.complete();
      await tester.pumpAndSettle();
      expect(find.byType(QuoteRequestDialog), findsNothing);
    },
  );

  testWidgets('annuler ferme le formulaire sans envoyer', (tester) async {
    var submitCalls = 0;
    await tester.pumpWidget(
      _testApp(
        onSubmit: (_) async {
          submitCalls++;
        },
      ),
    );
    await _openDialog(tester);

    await tester.tap(find.byKey(const ValueKey('quote-cancel-button')));
    await tester.pumpAndSettle();

    expect(find.byType(QuoteRequestDialog), findsNothing);
    expect(submitCalls, 0);
  });

  testWidgets('garde le formulaire ouvert et affiche une erreur d’envoi', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(onSubmit: (_) async => throw Exception('Connexion perdue')),
    );
    await _openDialog(tester);

    await tester.enterText(
      find.byKey(const ValueKey('quote-description')),
      'Réaliser un plan topographique détaillé.',
    );
    await tester.enterText(
      find.byKey(const ValueKey('quote-telephone')),
      '+228 90 12 34 56',
    );
    await tester.tap(find.byKey(const ValueKey('quote-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Envoi impossible. Connexion perdue'), findsOneWidget);
    expect(find.byType(QuoteRequestDialog), findsOneWidget);
  });
}
