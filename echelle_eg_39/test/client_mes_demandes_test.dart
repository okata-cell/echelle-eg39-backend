import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echelle_eg_39/client_mes_demandes.dart';
import 'package:echelle_eg_39/service_image_thumbnail.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'userEmail': 'client@example.com'});
  });

  testWidgets('chaque demande client affiche la photo de son appareil', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClientMesDemandesPage(
          loadDemandes: () async => [
            {
              'id': 51,
              'clientEmail': 'client@example.com',
              'appareilNom': 'GPS E600',
              'appareilCode': 'APP-001',
              'appareilType': 'GPS',
              'imageUrl': 'https://example.com/gps-e600.jpg',
              'quantite': 1,
              'appareilPrix': 250000,
              'total': 250000,
              'statut': 'en_attente',
            },
            {
              'id': 52,
              'clientEmail': 'client@example.com',
              'appareilNom': 'GPS E800',
              'appareilCode': 'APP-002',
              'appareilType': 'GPS',
              'imageUrl': 'https://example.com/gps-e800.jpg',
              'quantite': 2,
              'appareilPrix': 300000,
              'total': 600000,
              'statut': 'approuvee',
            },
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ServiceImageThumbnail>(
            find.byKey(const ValueKey('client-purchase-image-51')),
          )
          .imageUrl,
      'https://example.com/gps-e600.jpg',
    );
    expect(
      tester
          .widget<ServiceImageThumbnail>(
            find.byKey(const ValueKey('client-purchase-image-52')),
          )
          .imageUrl,
      'https://example.com/gps-e800.jpg',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
