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

Future<void> _tapDatePicker(
  WidgetTester tester, {
  required bool isReturnDate,
}) async {
  final key = isReturnDate
      ? 'location-return-date-2039'
      : 'location-start-date-2039';
  final picker = find.byKey(ValueKey(key));
  await tester.scrollUntilVisible(
    picker,
    180,
    scrollable: _verticalListFinder().first,
  );
  await tester.tap(picker);
}

Finder _verticalListFinder() => find.byWidgetPredicate(
  (widget) =>
      widget is Scrollable && widget.axisDirection == AxisDirection.down,
);

void _useMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(375, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'token': 'test-token',
      'userEmail': 'client@example.com',
    });
  });

  testWidgets('la fiche met en avant la photo et garde louer désactivé', (
    tester,
  ) async {
    _useMobileViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: LocationScreen(
          today: () => DateTime(2026, 10, 1),
          loadAppareils: ({disponible}) async => _equipmentResponse,
          checkAvailability:
              ({
                required appareilId,
                required dateDebut,
                required dateFin,
              }) async => {'disponible': true},
          createLocation: (appareilId, dateDebut, dateFin) async => {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final photo = find.byKey(const ValueKey('location-equipment-photo-2039'));
    expect(photo, findsOneWidget);
    expect(find.text('GPS de test'), findsOneWidget);
    expect(find.text('Disponible'), findsOneWidget);
    expect(find.text('Prix / jour'), findsOneWidget);
    expect(find.textContaining('FCFA'), findsOneWidget);
    expect(
      find.text(
        'La disponibilité de la période sera vérifiée après le choix du retour.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const ValueKey('location-rent-2039')),
          )
          .onPressed,
      isNull,
    );

    final image = tester.widget<Image>(
      find.descendant(of: photo, matching: find.byType(Image)),
    );
    expect((image.image as NetworkImage).url, 'https://example.test/gps.png');

    await tester.tap(find.byTooltip('Agrandir la photo'));
    await tester.pumpAndSettle();
    expect(
      find.text('Pincez pour zoomer • Double-tap pour agrandir'),
      findsOneWidget,
    );
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('la recherche se filtre et son effacement vide le champ', (
    tester,
  ) async {
    _useMobileViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: LocationScreen(
          loadAppareils: ({disponible}) async => [
            ..._equipmentResponse,
            {
              'id': 2040,
              'nom': 'Niveau de test',
              'type': 'Niveau',
              'prixLocation': 18000,
              'prixVente': 900000,
              'disponible': true,
              'imageUrl': 'https://example.test/level.png',
            },
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final search = find.byType(TextField);
    await tester.enterText(search, 'GPS');
    await tester.pumpAndSettle();
    expect(find.text('GPS de test'), findsOneWidget);
    expect(find.text('Niveau de test'), findsNothing);

    await tester.tap(find.byTooltip('Effacer la recherche'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(search).controller!.text, isEmpty);
    expect(find.text('GPS de test'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Niveau de test'),
      220,
      scrollable: _verticalListFinder().first,
    );
    expect(find.text('Niveau de test'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('les dates sont choisies et un conflit désactive louer', (
    tester,
  ) async {
    _useMobileViewport(tester);
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
    expect(find.text('01/10/2026'), findsOneWidget);

    await _tapDatePicker(tester, isReturnDate: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('3').last);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(find.text('03/10/2026'), findsOneWidget);

    await _tapDatePicker(tester, isReturnDate: true);
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
    _useMobileViewport(tester);
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

    await _tapDatePicker(tester, isReturnDate: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('3').last);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    await _tapDatePicker(tester, isReturnDate: true);
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
      _useMobileViewport(tester);
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

      await _tapDatePicker(tester, isReturnDate: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('3').last);
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      await _tapDatePicker(tester, isReturnDate: true);
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
    _useMobileViewport(tester);
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

    await _tapDatePicker(tester, isReturnDate: true);
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
