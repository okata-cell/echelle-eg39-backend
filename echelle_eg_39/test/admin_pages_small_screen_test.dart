// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

// Garde-fou des trois pages admin signalées le 15/11 sur le Motorola
// (320 dp, police Android 130 %) :
//   * Appareils        — débordement horizontal de 51 px sur la carte ;
//   * Locations        — la page semblait vide pendant le chargement, seuls
//                        les entêtes restaient visibles ;
//   * Demandes d'achat — même symptôme au chargement.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echelle_eg_39/LocationsMenu.dart';
import 'package:echelle_eg_39/admin_ventes_page.dart';
import 'package:echelle_eg_39/appareils.page.dart';
import 'package:echelle_eg_39/data_manager.dart';

/// Motorola Edge 2021 à densité maximale : 320 x 729 dp, police 130 %.
const Size _ecran = Size(320, 729);
const double _police = 1.3;

Widget _page(Widget enfant) {
  return MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(size: _ecran, textScaler: const TextScaler.linear(_police)),
        child: Scaffold(body: enfant),
      ),
    ),
  );
}

void main() {
  tearDown(() => DataManager().clearAppareils());

  testWidgets('Appareils : aucune carte ne déborde à 320 dp', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = _ecran;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _page(
        AdminAppareilsPage(
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
            {
              'id': 102,
              'code': 'APP-TEST-102',
              'nom': 'Station totale',
              'type': 'Station totale',
              'imageUrl': 'https://example.com/station.jpg',
              'prixLocation': 30000,
              'prixVente': 3750000,
              'disponible': false,
            },
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isNull,
      reason: 'La carte d’appareil ne doit pas déborder en 320 dp',
    );
    expect(find.text('GPS de test'), findsOneWidget);
  });

  testWidgets('Locations : le chargement reste visible sous l’entête', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = _ecran;
    addTearDown(tester.view.reset);

    // Chargement qui ne se termine jamais : on observe l'état initial.
    final jamais = Completer<List<Map<String, dynamic>>>();
    await tester.pumpWidget(
      _page(LocationPage(loadLocations: () => jamais.future)),
    );
    await tester.pump();

    final chargement = tester.getRect(find.text('Chargement des locations…'));
    expect(
      chargement.height,
      greaterThan(0),
      reason:
          'Avec les compteurs affichés, l’indicateur était écrasé à zéro pixel',
    );
    expect(chargement.bottom, lessThanOrEqualTo(_ecran.height));

    // La page applique un `.timeout(15 s)` : on termine le chargement pour
    // annuler ce minuteur avant la fin du test.
    jamais.complete(const <Map<String, dynamic>>[]);
    await tester.pumpAndSettle();
  });

  testWidgets('Demandes d’achat : le chargement reste visible sous l’entête', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = _ecran;
    addTearDown(tester.view.reset);

    final jamais = Completer<List<Map<String, dynamic>>>();
    await tester.pumpWidget(
      _page(AdminVentesPageFixed(loadDemandes: () => jamais.future)),
    );
    await tester.pump();

    final chargement = tester.getRect(
      find.text('Chargement des demandes d\'achat…'),
    );
    expect(chargement.height, greaterThan(0));
    expect(chargement.bottom, lessThanOrEqualTo(_ecran.height));
  });
}
