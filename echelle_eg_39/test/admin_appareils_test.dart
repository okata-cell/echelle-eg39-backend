import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echelle_eg_39/appareils.page.dart';
import 'package:echelle_eg_39/data_manager.dart';

void main() {
  tearDown(() => DataManager().clearAppareils());

  testWidgets('le chargement initial affiche les appareils reçus de l’API', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminAppareilsPage(
            loadAppareils: () async => [
              {
                'id': 101,
                'code': 'APP-TEST-101',
                'nom': 'GPS de test',
                'type': 'GPS',
                'imageUrl': 'https://example.com/gps.jpg',
                'prixLocation': 25000,
                'prixVente': 2500000,
                'disponible': true,
              },
            ],
          ),
        ),
      ),
    );

    expect(find.text('Chargement du parc matériel…'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Chargement du parc matériel…'), findsNothing);
    expect(find.text('GPS de test'), findsOneWidget);
    expect(find.text('APP-TEST-101'), findsOneWidget);
  });
}
