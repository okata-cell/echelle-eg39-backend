import 'package:echelle_eg_39/company_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  test('la position et l’adresse de l’agence sont exactes', () {
    expect(CompanyLocation.name, 'ÉCHELLE EG39');
    expect(
      CompanyLocation.address,
      'Lomé, Rue des frères franciscains, après les rails',
    );
    expect(CompanyLocation.coordinates.latitude, closeTo(6.186033, 0.000001));
    expect(CompanyLocation.coordinates.longitude, closeTo(1.179523, 0.000001));
    expect(CompanyLocation.mapsUrl, contains('https://maps.app.goo.gl/'));
  });

  testWidgets('la fiche affiche le nom sur la carte et l’adresse en dessous', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        CompanyLocationCard(
          mapBuilder: (_) => const SizedBox(key: ValueKey('test-map')),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('test-map')), findsOneWidget);
    expect(find.text('Entreprise ÉCHELLE EG39'), findsOneWidget);
    expect(
      find.text('Lomé, Rue des frères franciscains, après les rails'),
      findsOneWidget,
    );
    expect(find.textContaining('55PH+CR6 Lomé, Togo'), findsOneWidget);
    expect(find.textContaining('6.18603'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Entreprise ÉCHELLE EG39')).dy,
      lessThan(
        tester
            .getTopLeft(
              find.text('Lomé, Rue des frères franciscains, après les rails'),
            )
            .dy,
      ),
    );
  });

  testWidgets('l’ouverture de carte respecte la hauteur demandée', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        CompanyLocationCard(
          mapHeight: 168,
          mapBuilder: (_) => const SizedBox(key: ValueKey('test-map')),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('company-map-frame'))).height,
      168,
    );
  });

  testWidgets('le marqueur décrit l’emplacement de l’entreprise', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Center(
          child: SizedBox.square(dimension: 54, child: CompanyLocationMarker()),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('Emplacement de l’entreprise ÉCHELLE EG39'),
      findsOneWidget,
    );
  });

  testWidgets('« Itinéraire » ouvre le lien de localisation de l’agence', (
    tester,
  ) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      _host(
        CompanyLocationCard(
          mapBuilder: (_) => const SizedBox(),
          openMaps: (uri) async {
            opened.add(uri);
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('company-location-itinerary')));
    await tester.pumpAndSettle();

    expect(opened, [CompanyLocation.mapsUri]);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('un échec d’ouverture est signalé sans bloquer la fiche', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        CompanyLocationCard(
          mapBuilder: (_) => const SizedBox(),
          openMaps: (_) async => false,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('company-location-itinerary')));
    await tester.pumpAndSettle();

    expect(
      find.text('Impossible d’ouvrir l’itinéraire pour le moment.'),
      findsOneWidget,
    );
  });

  testWidgets('la copie transmet l’adresse complète', (tester) async {
    String? copied;
    await tester.pumpWidget(
      _host(
        CompanyLocationCard(
          mapBuilder: (_) => const SizedBox(),
          copyAddress: (address) async => copied = address,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('company-location-copy')));
    await tester.pumpAndSettle();

    expect(
      copied,
      'ÉCHELLE EG39 — Lomé, Rue des frères franciscains, après les rails',
    );
    expect(find.text('Adresse copiée.'), findsOneWidget);
  });

  testWidgets('la fiche reste lisible sur un petit écran', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _host(
        CompanyLocationCard(
          mapBuilder: (_) => const SizedBox(),
          openMaps: (_) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Entreprise ÉCHELLE EG39'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('company-location-itinerary')),
      findsOneWidget,
    );
  });

  testWidgets('la carte réelle se construit avec son marqueur', (tester) async {
    await tester.pumpWidget(_host(const CompanyLocationCard()));
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(CompanyLocationMarker), findsOneWidget);
    expect(find.text('Entreprise ÉCHELLE EG39'), findsOneWidget);
  });
}
