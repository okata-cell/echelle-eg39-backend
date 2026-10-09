import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echelle_eg_39/client_mes_devis.dart';

Map<String, dynamic> devis({
  int id = 57,
  String statut = 'en_attente',
  String? commentaireAdmin,
  String? description = 'Relevé du terrain',
  Object? montant,
}) {
  return {
    'id': id,
    'userId': 12,
    'clientEmail': 'afi@example.com',
    'clientNom': 'Afi Koffi',
    'serviceId': '4',
    'serviceName': 'Bornage de terrain',
    'description': description,
    'nom': 'Afi Koffi',
    'telephone': '+22890123456',
    'email': null,
    'statut': statut,
    'commentaireAdmin': commentaireAdmin,
    'montant': montant,
    'createdAt': '2026-09-25T10:00:00.000Z',
    'updatedAt': '2026-09-25T10:00:00.000Z',
  };
}

Widget pageAvec(DevisLoader loader) {
  return MaterialApp(home: ClientMesDevisPage(loadDevis: loader));
}

void main() {
  testWidgets('affiche les demandes du compte et leur statut', (tester) async {
    await tester.pumpWidget(
      pageAvec(() async => [devis(), devis(id: 58, statut: 'termine')]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mes devis'), findsOneWidget);
    expect(find.text('Bornage de terrain'), findsNWidgets(2));
    expect(find.text('Devis #57 · 25/09/2026'), findsOneWidget);
    expect(find.text('En attente'), findsOneWidget);
    expect(find.text('Terminée'), findsNWidgets(3));
    expect(find.text('Demande envoyée'), findsNWidgets(2));
  });

  testWidgets('une demande approuvée montre le montant communiqué', (
    tester,
  ) async {
    await tester.pumpWidget(
      pageAvec(() async => [devis(statut: 'approuvee', montant: '1250000')]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Devis approuvé'), findsOneWidget);
    expect(find.text('Montant approuvé'), findsOneWidget);
    expect(find.text('1 250 000 FCFA'), findsOneWidget);
    expect(find.text('Accepter le devis'), findsNothing);
    expect(find.text('Refuser le devis'), findsNothing);
    expect(find.text('Ouvrir le PDF'), findsNothing);
    expect(find.textContaining('Valable jusqu’au'), findsNothing);
  });

  testWidgets('une demande rejetée affiche le motif admin', (tester) async {
    await tester.pumpWidget(
      pageAvec(
        () async => [
          devis(statut: 'rejetee', commentaireAdmin: 'Budget insuffisant'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Demande refusée'), findsOneWidget);
    expect(find.text('Motif du refus'), findsOneWidget);
    expect(find.text('Budget insuffisant'), findsOneWidget);
    expect(find.text('Accepter le devis'), findsNothing);
    expect(find.text('Refuser le devis'), findsNothing);
  });

  testWidgets(
    'ne montre pas un commentaire admin historique sur une approbation',
    (tester) async {
      await tester.pumpWidget(
        pageAvec(
          () async => [
            devis(
              statut: 'approuvee',
              montant: 50000,
              commentaireAdmin: 'Ancien commentaire',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('50 000 FCFA'), findsOneWidget);
      expect(find.text('Ancien commentaire'), findsNothing);
    },
  );

  testWidgets('un compte sans demande est invité à en créer une', (
    tester,
  ) async {
    await tester.pumpWidget(pageAvec(() async => []));
    await tester.pumpAndSettle();

    expect(find.text('Aucune demande de devis'), findsOneWidget);
  });

  testWidgets('une erreur affiche une action de nouvelle tentative', (
    tester,
  ) async {
    var appels = 0;
    await tester.pumpWidget(
      pageAvec(() async {
        appels++;
        if (appels == 1) throw Exception('Serveur indisponible');
        return [devis()];
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('Serveur indisponible'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(appels, 2);
    expect(find.text('Devis #57 · 25/09/2026'), findsOneWidget);
  });

  testWidgets('tirer vers le bas recharge le suivi du client', (tester) async {
    var appels = 0;
    await tester.pumpWidget(
      pageAvec(() async {
        appels++;
        return [devis()];
      }),
    );
    await tester.pumpAndSettle();
    expect(appels, 1);

    await tester.fling(
      find.text('Devis #57 · 25/09/2026'),
      const Offset(0, 300),
      1000,
    );
    await tester.pumpAndSettle();

    expect(appels, 2);
  });
}
