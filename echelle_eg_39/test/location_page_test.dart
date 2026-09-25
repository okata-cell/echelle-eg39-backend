import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echelle_eg_39/LocationsMenu.dart';

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
            body: LocationPage(
              loadLocations: () async => requests,
              checkExpiredLocations: () async {},
              enableAutoRefresh: false,
            ),
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
