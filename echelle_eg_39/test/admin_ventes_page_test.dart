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

  testWidgets(
    'un admin peut supprimer une demande approuvée avec confirmation',
    (tester) async {
      final demande = <String, dynamic>{
        'id': 91,
        'code': 'DA-91',
        'clientNom': 'Client test',
        'appareilNom': 'GPS E600',
        'statut': 'approuvee',
        'quantite': 1,
        'total': 250000,
      };
      final demandes = [demande];
      final deletedIds = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminVentesPageFixed(
              loadDemandes: () async =>
                  List<Map<String, dynamic>>.from(demandes),
              deleteDemande: (id) async {
                deletedIds.add(id);
                demandes.removeWhere((item) => item['id'] == id);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('delete-purchase-request-91')),
        findsNothing,
      );
      await tester.tap(find.text('Approuvées').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('delete-purchase-request-91')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('delete-purchase-request-91')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Supprimer la demande ?'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(deletedIds, isEmpty);

      await tester.tap(
        find.byKey(const ValueKey('delete-purchase-request-91')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Supprimer'));
      await tester.pumpAndSettle();

      expect(deletedIds, [91]);
      expect(find.text('GPS E600'), findsNothing);
      expect(find.text('Demande #91 supprimée.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
