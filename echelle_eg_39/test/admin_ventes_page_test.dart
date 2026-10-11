import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echelle_eg_39/admin_ventes_page.dart';
import 'package:echelle_eg_39/service_image_thumbnail.dart';

void main() {
  testWidgets('chaque demande admin affiche la photo de son appareil', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminVentesPageFixed(
            loadDemandes: () async => [
              {
                'id': 61,
                'code': 'DA-61',
                'clientNom': 'Client un',
                'appareilNom': 'GPS E600',
                'appareilCode': 'APP-001',
                'appareilType': 'GPS',
                'imageUrl': 'https://example.com/admin-gps-e600.jpg',
                'quantite': 1,
                'total': 250000,
                'statut': 'en_attente',
              },
              {
                'id': 62,
                'code': 'DA-62',
                'clientNom': 'Client deux',
                'appareilNom': 'GPS E800',
                'appareilCode': 'APP-002',
                'appareilType': 'GPS',
                'imageUrl': 'https://example.com/admin-gps-e800.jpg',
                'quantite': 2,
                'total': 600000,
                'statut': 'en_attente',
              },
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ServiceImageThumbnail>(
            find.byKey(const ValueKey('admin-purchase-image-61')),
          )
          .imageUrl,
      'https://example.com/admin-gps-e600.jpg',
    );
    expect(
      tester
          .widget<ServiceImageThumbnail>(
            find.byKey(const ValueKey('admin-purchase-image-62')),
          )
          .imageUrl,
      'https://example.com/admin-gps-e800.jpg',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
