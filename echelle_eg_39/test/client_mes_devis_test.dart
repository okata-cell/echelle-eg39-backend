import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echelle_eg_39/client_mes_devis.dart';

Map<String, dynamic> devis({
  int id = 57,
  String statut = 'en_attente',
  String? commentaireAdmin,
  String? description = 'Relevé du terrain',
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
    'createdAt': '2026-09-25T10:00:00.000Z',
    'updatedAt': '2026-09-25T10:00:00.000Z',
  };
}

Widget pageAvec(DevisLoader loader) {
  return MaterialApp(
    home: ClientMesDevisPage(loadDevis: loader),
  );
}

void main() {
  testWidgets('affiche les devis du compte avec leur statut', (tester) async {
    await tester.pumpWidget(
      pageAvec(() async => [devis(), devis(id: 58, statut: 'termine')]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mes devis'), findsOneWidget);
    expect(find.text('Bornage de terrain'), findsNWidgets(2));
    expect(find.text('Devis #57 · 25/09/2026'), findsOneWidget);
    expect(find.text('En attente'), findsOneWidget);
    // Les 4 libellés d'étape sont toujours rendus : 2 cartes = 2 occurrences,
    // plus le badge du devis terminé.
    expect(find.text('Terminée'), findsNWidgets(3));
    expect(find.text('Demande envoyée'), findsNWidgets(2));
  });

  testWidgets('un devis refusé affiche le motif de l’administration', (
    tester,
  ) async {
    await tester.pumpWidget(
      pageAvec(
        () async => [devis(statut: 'rejetee', commentaireAdmin: 'Budget insuffisant')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Refusée'), findsOneWidget);
    expect(find.text('Motif du refus'), findsOneWidget);
    expect(find.text('Budget insuffisant'), findsOneWidget);
  });

  testWidgets('le message de suivi est affiché hors rejet', (tester) async {
    await tester.pumpWidget(
      pageAvec(
        () async => [devis(statut: 'envoye', commentaireAdmin: 'Devis transmis par e-mail')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Devis envoyé'), findsOneWidget);
    expect(find.text("Message de l'administration"), findsOneWidget);
    expect(find.text('Devis transmis par e-mail'), findsOneWidget);
  });

  testWidgets('un compte sans devis invite à créer une demande', (tester) async {
    await tester.pumpWidget(pageAvec(() async => []));
    await tester.pumpAndSettle();

    expect(find.text('Aucune demande de devis'), findsOneWidget);
  });

  testWidgets('une erreur affiche un bouton de nouvelle tentative', (
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

  testWidgets('tirer vers le bas recharge les devis', (tester) async {
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
