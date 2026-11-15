// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

// Garde-fou du défilement de la file Locations.
//
// Constat du 15/11 sur l'iPhone, police au maximum : l'écran Locations refusait
// de défiler alors que les six autres onglets admin fonctionnaient. La page
// empilait `Column(entête, Expanded(ListView))` : l'entête, plus haut que
// l'écran en grande police, écrasait la liste à zéro pixel. L'entête défile
// désormais avec la liste (`CustomScrollView`), comme sur les autres pages.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echelle_eg_39/LocationsMenu.dart';

Map<String, dynamic> _location(int id) => <String, dynamic>{
  'code': 'LOC-$id',
  'clientNom': 'Client $id',
  'appareilNom': 'GPS $id',
  'appareilType': 'GPS',
  'dateDebut': '2026-10-01',
  'dateFin': '2026-10-03',
  'montantTotal': 75000,
  'statut': 'en_attente',
};

Widget _page({required double facteurTexte}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(facteurTexte)),
        child: Scaffold(
          body: LocationPage(
            loadLocations: () async => <Map<String, dynamic>>[
              for (var i = 1; i <= 8; i++) _location(i),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final facteur in <double>[1.0, 3.1]) {
    testWidgets(
      'la file Locations défile — police ${(facteur * 100).round()} %',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_page(facteurTexte: facteur));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        final position = tester
            .state<ScrollableState>(
              find
                  .descendant(
                    of: find.byType(CustomScrollView).first,
                    matching: find.byType(Scrollable),
                  )
                  .first,
            )
            .position;

        expect(
          position.maxScrollExtent,
          greaterThan(0),
          reason:
              'La page doit avoir du contenu à défiler (police $facteur) : '
              'une fin de course nulle signifie que la liste a été écrasée.',
        );

        // Un geste réel déplace bien le contenu.
        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, -250),
        );
        await tester.pumpAndSettle();

        expect(
          position.pixels,
          greaterThan(0),
          reason: 'Le geste de défilement doit déplacer le contenu',
        );
      },
    );
  }
}
