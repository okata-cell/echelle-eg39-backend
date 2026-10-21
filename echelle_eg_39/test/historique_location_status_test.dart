import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echelle_eg_39/historique.dart';
import 'package:echelle_eg_39/history_purchase_status.dart';
import 'package:echelle_eg_39/service_image_thumbnail.dart';

Map<String, dynamic> location({
  required int id,
  required String name,
  required String status,
  String? comment,
  String startDate = '2030-06-10',
  String? returnDate = '2030-06-15',
}) {
  return {
    'id': id,
    'code': 'LOC-$id',
    'appareilNom': name,
    'appareilType': 'GPS',
    'appareilId': id,
    'imageUrl': '',
    'dateDebut': startDate,
    'dateFin': returnDate,
    'prixJournalier': 25000,
    'montantTotal': 150000,
    'statut': status,
    'commentaireAdmin': comment,
  };
}

Map<String, dynamic> purchase({
  required int id,
  required String name,
  required String status,
  int quantity = 1,
  int total = 250000,
  String? comment,
}) {
  return {
    'id': id,
    'code': 'DA-$id',
    'appareilNom': name,
    'createdAt': '2030-06-11T12:00:00.000Z',
    'quantite': quantity,
    'appareilPrix': total ~/ quantity,
    'total': total,
    'statut': status,
    'commentaireAdmin': comment,
  };
}

Widget historyPage({
  required HistoriqueDataLoader loadLocations,
  HistoriqueDataLoader? loadPurchases,
  Duration? refreshInterval = Duration.zero,
}) {
  return MaterialApp(
    home: HistoriqueScreen(
      loadLocations: loadLocations,
      loadPurchases: loadPurchases ?? () async => [],
      refreshInterval: refreshInterval,
    ),
  );
}

Future<void> tapHistoryFilter(
  WidgetTester tester,
  String section,
  String filter,
) async {
  final filterFinder = find.byKey(ValueKey('history-filter-$section-$filter'));
  await tester.ensureVisible(filterFinder);
  await tester.tap(filterFinder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('les statuts d’achat restent distincts des statuts de location', () {
    expect(normalizePurchaseStatus('en_attente'), 'en_attente');
    expect(normalizePurchaseStatus('approuvee'), 'approuvee');
    expect(normalizePurchaseStatus('rejetee'), 'rejetee');
    expect(normalizePurchaseStatus('livree'), 'livree');
    expect(normalizePurchaseStatus('termine'), 'termine');
    expect(normalizePurchaseStatus('en_cours'), 'inconnu');
    expect(normalizePurchaseStatus('valeur-inconnue'), 'inconnu');
  });

  testWidgets('les photos locations/achats utilisent leurs clés stables', (
    tester,
  ) async {
    await tester.pumpWidget(
      historyPage(
        loadLocations: () async => [
          {
            ...location(id: 81, name: 'GPS E600', status: 'en_attente'),
            'appareilCode': 'APP-001',
            'imageUrl': 'https://example.com/rental-gps.jpg',
          },
        ],
        loadPurchases: () async => [
          {
            ...purchase(id: 82, name: 'Niveau de test', status: 'en_attente'),
            'appareilCode': 'APP-002',
            'appareilType': 'GPS',
            'imageUrl': 'https://example.com/sale-level.jpg',
          },
        ],
      ),
    );
    await tester.pumpAndSettle();

    final rentalKey = const ValueKey('history-transaction-image-location-81');
    expect(
      tester.widget<ServiceImageThumbnail>(find.byKey(rentalKey)).imageUrl,
      'https://example.com/rental-gps.jpg',
    );

    await tester.tap(find.text('Achats'));
    await tester.pumpAndSettle();
    final purchaseKey = const ValueKey('history-transaction-image-achat-82');
    expect(
      tester.widget<ServiceImageThumbnail>(find.byKey(purchaseKey)).imageUrl,
      'https://example.com/sale-level.jpg',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('actualise le statut location et détaille le motif du refus', (
    tester,
  ) async {
    var status = 'en_attente';
    await tester.pumpWidget(
      historyPage(
        loadLocations: () async => [
          location(
            id: 12,
            name: 'GPS E600',
            status: status,
            comment: status == 'rejetee' ? 'Appareil indisponible' : null,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('En attente'), findsNWidgets(2));
    expect(find.text('GPS E600'), findsOneWidget);

    status = 'rejetee';
    await tester.tap(find.byTooltip('Actualiser'));
    await tester.pumpAndSettle();

    expect(find.text('Refusée'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.info_outline).last);
    await tester.pumpAndSettle();
    expect(find.text('Motif du rejet:'), findsOneWidget);
    expect(find.text('Appareil indisponible'), findsOneWidget);
    expect(find.text('Non transmis par le service'), findsOneWidget);
    expect(find.textContaining('Payer'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('les filtres locations séparent les états réels', (tester) async {
    await tester.pumpWidget(
      historyPage(
        loadLocations: () async => [
          location(id: 1, name: 'GPS refusé', status: 'rejetee'),
          location(id: 2, name: 'GPS annulé', status: 'annulee'),
          location(id: 3, name: 'GPS terminé', status: 'termine'),
          location(id: 4, name: 'GPS approuvé', status: 'approuvee'),
          location(id: 5, name: 'GPS actif', status: 'en_cours'),
          location(
            id: 6,
            name: 'GPS retour dépassé',
            status: 'en_cours',
            startDate: '2020-06-10',
            returnDate: '2020-06-15',
          ),
          location(id: 7, name: 'GPS retard signalé', status: 'en_retard'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tapHistoryFilter(tester, 'locations', 'refusee');
    expect(find.text('GPS refusé'), findsOneWidget);
    expect(find.text('GPS annulé'), findsOneWidget);
    expect(find.text('GPS terminé'), findsNothing);

    await tapHistoryFilter(tester, 'locations', 'termine');
    expect(find.text('GPS terminé'), findsOneWidget);
    expect(find.text('GPS refusé'), findsNothing);

    await tapHistoryFilter(tester, 'locations', 'approuvee');
    expect(find.text('GPS approuvé'), findsOneWidget);
    // The only “En cours” text is the available filter chip, not a row status.
    expect(find.text('En cours'), findsOneWidget);

    await tapHistoryFilter(tester, 'locations', 'a-verifier');
    expect(find.text('GPS retour dépassé'), findsOneWidget);
    expect(find.text('GPS retard signalé'), findsOneWidget);
    expect(find.text('Date dépassée · à confirmer avec EG39'), findsOneWidget);
    expect(find.textContaining('pénalité'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('les statuts achat approuvée et livrée restent distincts', (
    tester,
  ) async {
    await tester.pumpWidget(
      historyPage(
        loadLocations: () async => [],
        loadPurchases: () async => [
          purchase(id: 21, name: 'GPS en attente', status: 'en_attente'),
          purchase(
            id: 22,
            name: 'Station approuvée',
            status: 'approuvee',
            quantity: 2,
            total: 500000,
          ),
          purchase(id: 23, name: 'Niveau livré', status: 'livree'),
          purchase(id: 24, name: 'Dossier refusé', status: 'rejetee'),
          purchase(id: 25, name: 'Dossier terminé', status: 'termine'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Achats'));
    await tester.pumpAndSettle();

    expect(find.text('Station approuvée'), findsOneWidget);
    expect(find.text('Quantité demandée : 2'), findsOneWidget);
    expect(find.text('Approuvée'), findsOneWidget);
    expect(find.text('En cours'), findsNothing);
    expect(find.text('Livrée'), findsOneWidget);
    expect(find.text('Terminée'), findsOneWidget);
    expect(find.textContaining('À régler'), findsNothing);
    expect(find.textContaining('Non payé'), findsNothing);

    await tapHistoryFilter(tester, 'achats', 'rejetee');
    expect(find.text('Dossier refusé'), findsOneWidget);
    expect(find.text('GPS en attente'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('une date de retour passée se formule comme à vérifier', (
    tester,
  ) async {
    await tester.pumpWidget(
      historyPage(
        loadLocations: () async => [
          location(
            id: 35,
            name: 'GPS à contrôler',
            status: 'en_cours',
            startDate: '2020-06-10',
            returnDate: '2020-06-15',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Retour à vérifier'), findsOneWidget);
    expect(find.text('À vérifier'), findsNWidgets(2)); // chip and status badge
    expect(find.textContaining('pénalité'), findsNothing);
    expect(find.textContaining('à régler'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('un filtre vide peut être effacé', (tester) async {
    await tester.pumpWidget(
      historyPage(
        loadLocations: () async => [
          location(id: 41, name: 'GPS en attente', status: 'en_attente'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tapHistoryFilter(tester, 'locations', 'termine');
    expect(find.text('Aucun dossier dans ce filtre'), findsOneWidget);

    await tester.tap(find.text('Effacer le filtre'));
    await tester.pumpAndSettle();
    expect(find.text('GPS en attente'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('une erreur locations ne bloque pas les achats ni leur retry', (
    tester,
  ) async {
    var locationCalls = 0;
    var purchaseCalls = 0;

    await tester.pumpWidget(
      historyPage(
        loadLocations: () async {
          locationCalls++;
          if (locationCalls == 1) throw Exception('locations indisponibles');
          return [
            location(id: 91, name: 'Location rétablie', status: 'en_cours'),
          ];
        },
        loadPurchases: () async {
          purchaseCalls++;
          return [purchase(id: 92, name: 'Achat accessible', status: 'livree')];
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Locations indisponibles'), findsOneWidget);
    await tester.tap(find.text('Achats'));
    await tester.pumpAndSettle();
    expect(find.text('Achat accessible'), findsOneWidget);

    await tester.tap(find.text('Locations'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(find.text('Location rétablie'), findsOneWidget);
    expect(locationCalls, 2);
    expect(purchaseCalls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('une erreur achats laisse les locations consultables', (
    tester,
  ) async {
    await tester.pumpWidget(
      historyPage(
        loadLocations: () async => [
          location(id: 93, name: 'Location disponible', status: 'en_cours'),
        ],
        loadPurchases: () async => throw Exception('achats indisponibles'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Location disponible'), findsOneWidget);
    expect(find.text('Locations indisponibles'), findsNothing);

    await tester.tap(find.text('Achats'));
    await tester.pumpAndSettle();
    expect(find.text('Achats indisponibles'), findsOneWidget);

    await tester.tap(find.text('Locations'));
    await tester.pumpAndSettle();
    expect(find.text('Location disponible'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('une erreur de rafraîchissement reste propre à son onglet', (
    tester,
  ) async {
    var locationCalls = 0;
    var purchaseCalls = 0;
    var failLocations = false;

    await tester.pumpWidget(
      historyPage(
        loadLocations: () async {
          locationCalls++;
          if (failLocations) throw Exception('serveur locations indisponible');
          return [
            location(id: 94, name: 'Location en cache', status: 'en_cours'),
          ];
        },
        loadPurchases: () async {
          purchaseCalls++;
          return [purchase(id: 95, name: 'Achat en cache', status: 'livree')];
        },
      ),
    );
    await tester.pumpAndSettle();

    failLocations = true;
    await tester.tap(find.byTooltip('Actualiser'));
    await tester.pumpAndSettle();

    expect(find.text('Actualisation des locations impossible'), findsOneWidget);
    expect(find.text('Location en cache'), findsOneWidget);
    expect(locationCalls, 2);
    expect(purchaseCalls, 2);

    await tester.tap(find.text('Achats'));
    await tester.pumpAndSettle();
    expect(find.text('Achat en cache'), findsOneWidget);
    expect(find.text('Actualisation des locations impossible'), findsNothing);

    await tester.tap(find.text('Locations'));
    await tester.pumpAndSettle();
    failLocations = false;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(find.text('Location en cache'), findsOneWidget);
    expect(find.text('Actualisation des locations impossible'), findsNothing);
    expect(locationCalls, 3);
    expect(purchaseCalls, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('le tirage vers le bas recharge les locations', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      historyPage(
        loadLocations: () async {
          calls++;
          return [location(id: 4, name: 'GPS actualisé', status: 'en_cours')];
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(calls, 1);

    await tester.fling(find.text('GPS actualisé'), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();
    expect(calls, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('rafraîchit périodiquement puis annule le timer au démontage', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      historyPage(
        loadLocations: () async {
          calls++;
          return [location(id: 5, name: 'GPS suivi', status: 'en_cours')];
        },
        refreshInterval: const Duration(seconds: 5),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 1);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(calls, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
    expect(calls, 2);
  });
}
