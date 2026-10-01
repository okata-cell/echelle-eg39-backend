import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echelle_eg_39/api_service.dart';
import 'package:echelle_eg_39/location.dart';

const _equipmentResponse = <Map<String, dynamic>>[
  {
    'id': 2039,
    'nom': 'GPS de test',
    'type': 'GPS',
    'prixLocation': 25000,
    'prixVente': 2500000,
    'disponible': true,
    'imageUrl': 'https://example.test/gps.png',
  },
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'token': 'test-token',
      'userEmail': 'client@example.com',
    });
  });

  testWidgets('les dates sont choisies et un conflit désactive louer', (
    tester,
  ) async {
    var availabilityCalls = 0;
    var createCalls = 0;
    final today = DateTime(2026, 10, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: LocationScreen(
          today: () => today,
          loadAppareils: ({disponible}) async => _equipmentResponse,
          checkAvailability:
              ({
                required appareilId,
                required dateDebut,
                required dateFin,
              }) async {
                availabilityCalls++;
                expect(dateDebut, '2026-10-03');
                expect(dateFin, '2026-10-05');
                return {'disponible': false, 'raison': 'chevauchement'};
              },
          createLocation: (appareilId, dateDebut, dateFin) async {
            createCalls++;
            return {};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rentButton = find.widgetWithText(ElevatedButton, 'Louer');
    expect(rentButton, findsOneWidget);
    expect(tester.widget<ElevatedButton>(rentButton).onPressed, isNull);
    expect(find.text('Début : 01/10/2026'), findsOneWidget);

    await tester.tap(find.text('Début : 01/10/2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3').last);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(find.text('Début : 03/10/2026'), findsOneWidget);

    await tester.tap(find.text('Choisir la date de retour'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5').last);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    expect(availabilityCalls, 1);
    expect(
      find.text('Cette période chevauche une autre réservation.'),
      findsOneWidget,
    );
    expect(tester.widget<ElevatedButton>(rentButton).onPressed, isNull);
    expect(createCalls, 0);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('envoie la plage choisie au backend', (tester) async {
    final today = DateTime(2026, 10, 1);
    final createdPayload = <String>[];
    final availabilityRanges = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: LocationScreen(
          today: () => today,
          loadAppareils: ({disponible}) async => _equipmentResponse,
          checkAvailability:
              ({
                required appareilId,
                required dateDebut,
                required dateFin,
              }) async {
                availabilityRanges
                  ..add(dateDebut)
                  ..add(dateFin);
                return {'disponible': true};
              },
          createLocation: (appareilId, dateDebut, dateFin) async {
            createdPayload
              ..add('$appareilId')
              ..add(dateDebut)
              ..add(dateFin);
            return {
              'location': {'statut': 'en_attente'},
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Début : 01/10/2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3').last);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choisir la date de retour'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5').last);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    final rentButton = find.widgetWithText(ElevatedButton, 'Louer');
    expect(tester.widget<ElevatedButton>(rentButton).onPressed, isNotNull);
    await tester.tap(rentButton);
    await tester.pumpAndSettle();

    expect(availabilityRanges, ['2026-10-03', '2026-10-05']);
    expect(createdPayload, ['2039', '2026-10-03', '2026-10-05']);
    expect(find.textContaining('Demande de location envoyée'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'une erreur de route de prévisualisation laisse envoyer la demande',
    (tester) async {
      final today = DateTime(2026, 10, 1);
      var createCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: LocationScreen(
            today: () => today,
            loadAppareils: ({disponible}) async => _equipmentResponse,
            checkAvailability:
                ({
                  required appareilId,
                  required dateDebut,
                  required dateFin,
                }) async {
                  throw Exception('Route non trouvée');
                },
            createLocation: (appareilId, dateDebut, dateFin) async {
              createCalls++;
              return {};
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Début : 01/10/2026'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3').last);
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choisir la date de retour'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5').last);
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Vérification indisponible'), findsOneWidget);
      expect(find.text('À confirmer'), findsOneWidget);
      final rentButton = find.widgetWithText(ElevatedButton, 'Louer');
      expect(tester.widget<ElevatedButton>(rentButton).onPressed, isNotNull);

      await tester.tap(rentButton);
      await tester.pumpAndSettle();

      expect(createCalls, 1);
      expect(
        find.textContaining('Demande de location envoyée'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('un conflit confirmé par le POST est montré au client', (
    tester,
  ) async {
    final today = DateTime(2026, 10, 1);
    var createCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: LocationScreen(
          today: () => today,
          loadAppareils: ({disponible}) async => _equipmentResponse,
          checkAvailability:
              ({
                required appareilId,
                required dateDebut,
                required dateFin,
              }) async => {'disponible': true},
          createLocation: (appareilId, dateDebut, dateFin) async {
            createCalls++;
            throw const ApiException(
              type: ApiErrorType.request,
              message: 'Période indisponible',
              statusCode: 409,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choisir la date de retour'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5').last);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    final rentButton = find.widgetWithText(ElevatedButton, 'Louer');
    expect(tester.widget<ElevatedButton>(rentButton).onPressed, isNotNull);
    await tester.tap(rentButton);
    await tester.pumpAndSettle();

    expect(createCalls, 1);
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Période indisponible'),
      ),
      findsOneWidget,
    );
    expect(tester.widget<ElevatedButton>(rentButton).onPressed, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
