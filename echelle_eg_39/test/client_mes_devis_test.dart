import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echelle_eg_39/client_mes_devis.dart';

Map<String, dynamic> devis({
  int id = 57,
  String statut = 'en_attente',
  String? commentaireAdmin,
  String? description = 'Relevé du terrain',
  Object? montant,
  String? dateValidite,
  String? documentUrl,
  bool offreExpiree = false,
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
    'dateValidite': dateValidite,
    'documentUrl': documentUrl,
    'offreExpiree': offreExpiree,
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

    expect(find.text('Demande refusée'), findsOneWidget);
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

  testWidgets('une offre affiche son prix, son échéance, son PDF et les décisions', (
    tester,
  ) async {
    final validity = DateTime.now().add(const Duration(days: 7));
    final dateValidite = '${validity.year.toString().padLeft(4, '0')}-'
        '${validity.month.toString().padLeft(2, '0')}-'
        '${validity.day.toString().padLeft(2, '0')}';

    await tester.pumpWidget(
      pageAvec(
        () async => [
          devis(
            id: 59,
            statut: 'envoye',
            montant: '1250000',
            dateValidite: dateValidite,
            documentUrl: 'https://files.example.com/devis-59.pdf',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 250 000 FCFA'), findsOneWidget);
    expect(find.text('Valable jusqu’au ${dateValidite.split('-').reversed.join('/')}'), findsOneWidget);
    expect(find.text('Ouvrir le PDF'), findsOneWidget);
    expect(find.text('Accepter le devis'), findsOneWidget);
    expect(find.text('Refuser le devis'), findsOneWidget);
  });

  testWidgets('une offre expirée ne propose plus de décision', (tester) async {
    await tester.pumpWidget(
      pageAvec(
        () async => [
          devis(
            id: 60,
            statut: 'envoye',
            montant: 50000,
            dateValidite: '2000-01-01',
            documentUrl: 'https://files.example.com/devis-60.pdf',
            offreExpiree: true,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Offre expirée — contactez-nous pour demander une nouvelle offre.'), findsOneWidget);
    expect(find.text('Accepter le devis'), findsNothing);
    expect(find.text('Refuser le devis'), findsNothing);
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
