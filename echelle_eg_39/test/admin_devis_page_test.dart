import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echelle_eg_39/admin_devis.page.dart';
import 'package:echelle_eg_39/service_image_thumbnail.dart';

Map<String, dynamic> devis(String statut) => {
  'id': 57,
  'userId': 12,
  'serviceId': '4',
  'serviceName': 'Bornage de terrain',
  'description': 'Délimitation d’une parcelle',
  'nom': 'Afi Koffi',
  'telephone': '+22890123456',
  'email': 'afi@example.com',
  'clientEmail': 'afi@example.com',
  'statut': statut,
  'createdAt': '2026-10-10T08:00:00.000Z',
};

void main() {
  testWidgets('la carte admin affiche la miniature du service associé', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminDevisPage(
            loadDevis: () async => [devis('en_attente')],
            serviceImageResolver: (serviceId) => serviceId == '4'
                ? 'https://services.example.com/bornage.jpg'
                : null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final thumbnail = tester.widget<ServiceImageThumbnail>(
      find.byKey(const ValueKey('admin-devis-service-image-57')),
    );
    expect(thumbnail.imageUrl, 'https://services.example.com/bornage.jpg');
    expect(thumbnail.semanticLabel, 'Image du service Bornage de terrain');
  });

  testWidgets('l’admin démarre l’examen avant de rendre sa décision', (
    tester,
  ) async {
    var status = 'en_attente';
    final updates = <(int, String)>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminDevisPage(
            loadDevis: () async => [devis(status)],
            updateDevisStatut: (id, nextStatus) async {
              updates.add((id, nextStatus));
              status = nextStatus;
              return {'devis': devis(status)};
            },
            serviceImageResolver: (_) => null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Commencer l’examen'), findsOneWidget);
    expect(find.text('Approuver le devis'), findsNothing);

    await tester.tap(find.text('Commencer l’examen'));
    await tester.pumpAndSettle();

    expect(updates, [(57, 'en_traitement')]);
    expect(find.text('EN TRAITEMENT'), findsOneWidget);
    expect(find.text('Approuver le devis'), findsOneWidget);
    expect(find.text('Rejeter'), findsOneWidget);
    expect(find.text('Commencer l’examen'), findsNothing);
  });
}
