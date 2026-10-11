import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echelle_eg_39/LocationsMenu.dart';
import 'package:echelle_eg_39/service_image_thumbnail.dart';

void main() {
  testWidgets(
    'affiche les cinq files et filtre les locations correspondantes',
    (tester) async {
      final requests = <Map<String, dynamic>>[
        _location(1, 'en_attente'),
        _location(2, 'en_cours'),
        _location(3, 'termine'),
        _location(4, 'rejetee'),
        _location(5, 'annulee'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationPage(loadLocations: () async => requests),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Réservations à traiter'), findsOneWidget);
      expect(find.text('En attente'), findsOneWidget);
      expect(find.text('En cours'), findsOneWidget);
      expect(find.text('Terminées'), findsOneWidget);
      expect(find.text('Historique'), findsOneWidget);
      expect(find.text('Toutes'), findsOneWidget);
      expect(find.text('LOCATION #1'), findsOneWidget);
      expect(find.text('Approuver'), findsOneWidget);
      expect(find.text('Rejeter'), findsOneWidget);
      expect(find.text('LOCATION #3'), findsNothing);

      await tester.tap(find.text('Terminées'));
      await tester.pumpAndSettle();
      expect(find.text('LOCATION #3'), findsOneWidget);
      expect(find.text('LOCATION #4'), findsNothing);

      await tester.tap(find.text('Historique'));
      await tester.pumpAndSettle();
      expect(find.text('LOCATION #4'), findsOneWidget);
      expect(find.text('LOCATION #5'), findsOneWidget);
      expect(find.text('LOCATION #3'), findsNothing);

      await tester.tap(find.text('Toutes'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('LOCATION #3'),
        280,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(find.text('LOCATION #3'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('LOCATION #5'),
        280,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(find.text('LOCATION #5'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('ramène en haut la file quand une nouvelle réservation arrive', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var requests = List<Map<String, dynamic>>.generate(
      12,
      (index) => _location(index + 1, 'en_attente'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LocationPage(loadLocations: () async => requests)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('LOCATION #12'),
      300,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first,
    );
    expect(find.text('LOCATION #12'), findsOneWidget);

    requests = [_location(99, 'en_attente'), ...requests];
    await tester.tap(find.byTooltip('Actualiser'));
    await tester.pumpAndSettle();

    expect(find.text('LOCATION #99'), findsOneWidget);
    expect(find.text('13'), findsNWidgets(3));
    await tester.scrollUntilVisible(
      find.text('LOCATION #12'),
      300,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first,
    );
    expect(find.text('LOCATION #12'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });

  testWidgets('le chargement revient en haut après actualisation manuelle', (
    tester,
  ) async {
    var loadCount = 0;
    final requests = List<Map<String, dynamic>>.generate(
      12,
      (index) => _location(index + 1, 'en_attente'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationPage(
            loadLocations: () async {
              loadCount++;
              return requests;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(loadCount, 1);

    await tester.pump(const Duration(minutes: 1));
    expect(loadCount, 1, reason: 'aucun rafraîchissement automatique');

    final list = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('LOCATION #12'),
      300,
      scrollable: list,
    );
    expect(find.text('LOCATION #12'), findsOneWidget);

    await tester.tap(find.byTooltip('Actualiser'));
    await tester.pumpAndSettle();
    expect(loadCount, 2);
    expect(find.text('LOCATION #1'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('chaque location affiche la photo de son appareil', (
    tester,
  ) async {
    final locations = [
      {
        ..._location(41, 'en_attente'),
        'appareilCode': 'APP-001',
        'imageUrl': 'https://example.com/gps-41.jpg',
      },
      {
        ..._location(42, 'en_attente'),
        'appareilCode': 'APP-002',
        'imageUrl': 'https://example.com/gps-42.jpg',
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationPage(loadLocations: () async => locations),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstImage = tester.widget<ServiceImageThumbnail>(
      find.byKey(const ValueKey('admin-location-image-id:41')),
    );
    final secondImage = tester.widget<ServiceImageThumbnail>(
      find.byKey(const ValueKey('admin-location-image-id:42')),
    );
    expect(firstImage.imageUrl, 'https://example.com/gps-41.jpg');
    expect(secondImage.imageUrl, 'https://example.com/gps-42.jpg');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('une demande reste visible même si son identifiant est absent', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationPage(
            loadLocations: () async => [
              {
                'code': 'LOC-SANS-ID',
                'clientNom': 'Client test',
                'appareilNom': 'GPS test',
                'appareilType': 'GPS',
                'dateDebut': '2026-10-01',
                'dateFin': '2026-10-03',
                'montantTotal': 75000,
                'statut': 'en_attente',
              },
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Réservations à traiter'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(3));
    expect(find.text('GPS test'), findsOneWidget);
    expect(find.text('LOC-SANS-ID'), findsOneWidget);
    expect(
      find.textContaining('identifiant de réservation manquant'),
      findsOneWidget,
    );
    expect(find.text('Approuver'), findsNothing);
    expect(find.text('Rejeter'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('une location en cours peut être terminée par un admin', (
    tester,
  ) async {
    var status = 'en_cours';
    var terminatedId = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationPage(
            loadLocations: () async => [_location(8, status)],
            terminateLocation: (locationId) async {
              terminatedId = locationId;
              status = 'termine';
              return null;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('En cours'));
    await tester.pumpAndSettle();
    expect(find.text('LOCATION #8'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Confirmer le retour'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmer le retour'));
    await tester.pumpAndSettle();

    expect(terminatedId, 8);
    await tester.tap(find.text('Terminées'));
    await tester.pumpAndSettle();
    expect(find.text('LOCATION #8'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'un admin marque le retard sans libérer avant le retour physique',
    (tester) async {
      var status = 'en_cours';
      var overdueId = 0;
      var terminatedId = 0;
      final today = DateTime(2026, 10, 5);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationPage(
              today: () => today,
              loadLocations: () async => [_location(9, status)],
              markLocationOverdue: (id) async {
                overdueId = id;
                status = 'en_retard';
                return null;
              },
              terminateLocation: (id) async {
                terminatedId = id;
                status = 'termine';
                return null;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('En cours'));
      await tester.pumpAndSettle();

      expect(find.text('Marquer en retard'), findsOneWidget);
      await tester.tap(find.text('Marquer en retard'));
      await tester.pumpAndSettle();

      expect(overdueId, 9);
      expect(status, 'en_retard');
      expect(terminatedId, 0, reason: 'le retard ne confirme pas un retour');
      expect(find.text('EN RETARD'), findsOneWidget);
      expect(find.text('Confirmer le retour'), findsOneWidget);

      await tester.tap(find.text('Confirmer le retour'));
      await tester.pumpAndSettle();
      expect(terminatedId, 0, reason: 'la boîte doit attendre confirmation');
      await tester.tap(find.text('Pas encore'));
      await tester.pumpAndSettle();
      expect(terminatedId, 0);

      await tester.tap(find.text('Confirmer le retour'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Confirmer le retour'),
      );
      await tester.pumpAndSettle();
      expect(terminatedId, 9);
      expect(status, 'termine');

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Map<String, dynamic> _location(int id, String status) => {
  'id': id,
  'code': 'LOC-$id',
  'clientNom': 'Client $id',
  'clientPhone': '+2289000000$id',
  'appareilId': id,
  'appareilNom': 'GPS $id',
  'appareilType': 'GPS',
  'imageUrl': '',
  'dateDebut': '2026-09-25',
  'dateFin': '2026-10-02',
  'montantTotal': 175000,
  'statut': status,
};
