import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echelle_eg_39/historique.dart';

Map<String, dynamic> location({
  required int id,
  required String name,
  required String status,
  String? comment,
}) {
  return {
    'id': id,
    'code': 'LOC-$id',
    'appareilNom': name,
    'appareilType': 'GPS',
    'appareilId': id,
    'imageUrl': '',
    'dateDebut': '2030-06-10',
    'dateFin': '2030-06-15',
    'prixJournalier': 25000,
    'montantTotal': 150000,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('actualise le statut serveur et affiche le motif de refus', (
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
    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();
    expect(find.text('Motif du rejet:'), findsOneWidget);
    expect(find.text('Appareil indisponible'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('sépare les demandes refusées ou annulées des terminées', (
    tester,
  ) async {
    await tester.pumpWidget(
      historyPage(
        loadLocations: () async => [
          location(id: 1, name: 'GPS refusé', status: 'rejetee'),
          location(id: 2, name: 'GPS annulé', status: 'annulee'),
          location(id: 3, name: 'GPS terminé', status: 'termine'),
          location(id: 4, name: 'GPS accepté', status: 'approuvee'),
          location(id: 5, name: 'GPS en retard', status: 'en_retard'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Refusées / annulées'));
    await tester.pumpAndSettle();
    expect(find.text('GPS refusé'), findsOneWidget);
    expect(find.text('GPS annulé'), findsOneWidget);
    expect(find.text('GPS terminé'), findsNothing);

    await tester.tap(find.text('Terminés'));
    await tester.pumpAndSettle();
    expect(find.text('GPS terminé'), findsOneWidget);
    expect(find.text('GPS refusé'), findsNothing);
    expect(find.text('GPS annulé'), findsNothing);

    await tester.tap(find.text('En cours'));
    await tester.pumpAndSettle();
    expect(find.text('GPS accepté'), findsOneWidget);
    expect(find.text('Acceptée'), findsOneWidget);
    // En retard apparaît dans la bannière d'alerte et dans la transaction.
    expect(find.text('GPS en retard'), findsNWidgets(2));
    expect(find.text('En retard'), findsOneWidget);

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

    await tester.fling(
      find.text('GPS actualisé'),
      const Offset(0, 300),
      1000,
    );
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
