import 'dart:async';

import 'package:echelle_eg_39/location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _equipment = <Map<String, dynamic>>[
  {
    'id': 2039,
    'nom': 'GPS de test',
    'type': 'GPS',
    'prixLocation': 25000,
    'disponible': true,
    'imageUrl': 'https://example.test/gps.png',
  },
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'token': 'test-token'});
  });

  testWidgets(
    'le premier chargement montre une attente, jamais un résultat vide',
    (tester) async {
      final completer = Completer<List<Map<String, dynamic>>>();
      await tester.pumpWidget(
        MaterialApp(
          home: LocationScreen(
            loadAppareils: ({disponible}) => completer.future,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Chargement des équipements…'), findsOneWidget);
      expect(find.text('Aucun équipement trouvé'), findsNothing);
      expect(find.text('Aucun équipement disponible'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(_equipment);
      await tester.pumpAndSettle();

      expect(find.text('Chargement des équipements…'), findsNothing);
      expect(find.text('GPS de test'), findsOneWidget);
      expect(find.byKey(const ValueKey('card_2039')), findsOneWidget);
    },
  );

  testWidgets('un échec réseau propose de réessayer', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LocationScreen(
          loadAppareils: ({disponible}) async {
            attempts++;
            if (attempts == 1) throw Exception('réseau indisponible');
            return _equipment;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Impossible de charger les équipements.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('location-retry')), findsOneWidget);
    expect(find.text('Aucun équipement disponible'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('location-retry')));
    await tester.pumpAndSettle();

    expect(find.text('Impossible de charger les équipements.'), findsNothing);
    expect(find.text('GPS de test'), findsOneWidget);
  });

  testWidgets('une réponse vide affiche l’état vide, sans erreur', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LocationScreen(
          loadAppareils: ({disponible}) async =>
                  const <Map<String, dynamic>>[],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucun équipement disponible'), findsOneWidget);
    expect(find.text('Impossible de charger les équipements.'), findsNothing);
    expect(find.byKey(const ValueKey('location-retry')), findsNothing);
  });

  testWidgets('une actualisation vide retire les cartes affichées', (
    tester,
  ) async {
    var response = _equipment;
    await tester.pumpWidget(
      MaterialApp(
        home: LocationScreen(loadAppareils: ({disponible}) async => response),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('card_2039')), findsOneWidget);

    // Le serveur ne renvoie plus rien : la liste doit suivre, pas rester figée.
    response = const <Map<String, dynamic>>[];
    await tester.tap(find.byTooltip('Actualiser'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('card_2039')), findsNothing);
    expect(find.text('GPS de test'), findsNothing);
    expect(find.text('Aucun équipement disponible'), findsOneWidget);
  });

  testWidgets('un filtre sans résultat propose de le réinitialiser', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LocationScreen(
          loadAppareils: ({disponible}) async => _equipment,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('card_2039')), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'drone');
    await tester.pumpAndSettle();

    expect(find.text('Aucun équipement ne correspond'), findsOneWidget);
    expect(find.text('Aucun équipement disponible'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('location-clear-filters')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('card_2039')), findsOneWidget);
  });
}
