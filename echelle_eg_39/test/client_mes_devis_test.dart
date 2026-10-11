import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echelle_eg_39/client_mes_devis.dart';
import 'package:echelle_eg_39/service.dart';
import 'package:echelle_eg_39/service_image_thumbnail.dart';

Map<String, dynamic> devis({
  int id = 57,
  String statut = 'en_attente',
  String? commentaireAdmin,
  String? description = 'Relevé du terrain',
  Object? montant,
  Object? updatedAt = '2026-09-25T10:00:00.000Z',
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
    'updatedAt': updatedAt,
  };
}

Widget pageAvec(DevisLoader loader, {DevisDeleter? deleteDevis, Key? key}) {
  return MaterialApp(
    key: key,
    home: ClientMesDevisPage(
      loadDevis: loader,
      deleteDevis: deleteDevis,
      serviceImageResolver: (serviceId) =>
          serviceId == '4' ? 'https://services.example.com/bornage.jpg' : null,
    ),
  );
}

void main() {
  test(
    'le catalogue résout une image à partir de l’identifiant du service',
    () {
      expect(
        ServiceScreen.imageUrlForId('4'),
        ServiceScreen.catalog
            .firstWhere((service) => service.id == '4')
            .imageUrl,
      );
      expect(ServiceScreen.imageUrlForId('service-inconnu'), isNull);
      expect(ServiceScreen.imageUrlForId(null), isNull);
    },
  );

  testWidgets('affiche les demandes du compte et leur statut', (tester) async {
    await tester.pumpWidget(
      pageAvec(() async => [devis(), devis(id: 58, statut: 'termine')]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mes devis'), findsOneWidget);
    expect(find.text('Bornage de terrain'), findsNWidgets(2));
    expect(
      tester
          .widget<ServiceImageThumbnail>(
            find.byKey(const ValueKey('client-devis-service-image-57')),
          )
          .imageUrl,
      'https://services.example.com/bornage.jpg',
    );
    expect(find.text('Devis #57 · 25/09/2026'), findsOneWidget);
    expect(find.text('En attente'), findsOneWidget);
    expect(find.text('Terminée'), findsNWidgets(3));
    expect(find.text('Demande envoyée'), findsNWidgets(2));
  });

  testWidgets('la barre suit les cinq étapes réelles du devis', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      const stages = <String, String>{
        'en_attente': 'Demande envoyée',
        'en_traitement': 'En traitement',
        'approuvee': 'Décision rendue',
        'rejetee': 'Décision rendue',
        'en_cours': 'Service en cours',
        'termine': 'Terminée',
      };

      for (final entry in stages.entries) {
        await tester.pumpWidget(
          pageAvec(
            () async => [
              devis(
                id: 70,
                statut: entry.key,
                montant:
                    entry.key == 'en_attente' || entry.key == 'en_traitement'
                    ? null
                    : 125000,
              ),
            ],
            key: ValueKey(entry.key),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsLabel('Étape actuelle : ${entry.value}'),
          findsOneWidget,
          reason: 'statut ${entry.key}',
        );
      }
    } finally {
      semantics.dispose();
    }
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
    expect(
      find.byKey(const ValueKey('approved-devis-details')),
      findsOneWidget,
    );
    expect(find.text('1 250 000 FCFA'), findsOneWidget);
    final approvalBadge = tester.widget<Text>(find.text('Devis approuvé'));
    expect(approvalBadge.style?.fontWeight, FontWeight.w800);
    expect(approvalBadge.style?.color, const Color(0xFF059669));
    final amount = tester.widget<Text>(find.text('1 250 000 FCFA'));
    expect(amount.style?.fontWeight, FontWeight.w900);
    expect(amount.style?.fontSize, 21);
    expect(find.text('Accepter le devis'), findsNothing);
    expect(find.text('Refuser le devis'), findsNothing);
    expect(find.text('Ouvrir le PDF'), findsNothing);
    expect(find.textContaining('Valable jusqu’au'), findsNothing);
  });

  testWidgets('le montant reste visible pendant le suivi et après clôture', (
    tester,
  ) async {
    await tester.pumpWidget(
      pageAvec(
        () async => [
          devis(id: 60, statut: 'en_cours', montant: 1250000),
          devis(id: 61, statut: 'termine', montant: 1250000),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('En cours'), findsOneWidget);
    expect(find.text('Terminée'), findsNWidgets(3));
    expect(find.text('Montant approuvé'), findsNWidgets(2));
    expect(find.text('1 250 000 FCFA'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('approved-devis-details')),
      findsNWidgets(2),
    );
  });

  testWidgets(
    'affiche la dernière mise à jour avec la date et l’heure locale',
    (tester) async {
      const rawUpdatedAt = '2026-09-25T10:07:00.000Z';
      final localDate = DateTime.parse(rawUpdatedAt).toLocal();
      final date =
          '${localDate.day.toString().padLeft(2, '0')}/'
          '${localDate.month.toString().padLeft(2, '0')}/${localDate.year}';
      final time =
          '${localDate.hour.toString().padLeft(2, '0')}:'
          '${localDate.minute.toString().padLeft(2, '0')}';

      await tester.pumpWidget(
        pageAvec(() async => [devis(updatedAt: rawUpdatedAt)]),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Dernière mise à jour le $date à $time'),
        findsOneWidget,
      );
    },
  );

  testWidgets('retombe sur la date de création si updateAt manque', (
    tester,
  ) async {
    final createdAt = DateTime.parse('2026-09-25T10:00:00.000Z').toLocal();
    final date =
        '${createdAt.day.toString().padLeft(2, '0')}/'
        '${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
    final time =
        '${createdAt.hour.toString().padLeft(2, '0')}:'
        '${createdAt.minute.toString().padLeft(2, '0')}';

    await tester.pumpWidget(pageAvec(() async => [devis(updatedAt: null)]));
    await tester.pumpAndSettle();

    expect(find.text('Dernière mise à jour le $date à $time'), findsOneWidget);
  });

  testWidgets('suppression active seulement après refus ou clôture', (
    tester,
  ) async {
    final statuses = <String, bool>{
      'rejetee': true,
      'termine': true,
      'en_attente': false,
      'en_traitement': false,
      'approuvee': false,
      'en_cours': false,
      'envoye': false,
    };

    var id = 100;
    for (final entry in statuses.entries) {
      final currentId = id++;
      await tester.pumpWidget(
        pageAvec(
          () async => [
            devis(
              id: currentId,
              statut: entry.key,
              description: null,
              montant: entry.key == 'rejetee' ? null : 25000,
            ),
          ],
          key: ValueKey(currentId),
        ),
      );
      await tester.pumpAndSettle();

      final button = tester
          .widgetList<OutlinedButton>(find.byType(OutlinedButton))
          .single;
      expect(button.onPressed != null, entry.value, reason: entry.key);
    }
  });

  testWidgets('annuler la confirmation ne supprime pas la demande', (
    tester,
  ) async {
    var deleteCalls = 0;
    await tester.pumpWidget(
      pageAvec(
        () async => [devis(statut: 'rejetee')],
        deleteDevis: (_) async {
          deleteCalls++;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Supprimer'));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer cette demande ?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Annuler'));
    await tester.pumpAndSettle();

    expect(deleteCalls, 0);
    expect(find.text('Devis #57 · 25/09/2026'), findsOneWidget);
  });

  testWidgets('confirmation supprime la demande et recharge la liste', (
    tester,
  ) async {
    var loadCalls = 0;
    final deletedIds = <int>[];
    await tester.pumpWidget(
      pageAvec(
        () async {
          loadCalls++;
          return loadCalls == 1 ? [devis(statut: 'termine')] : [];
        },
        deleteDevis: (id) async {
          deletedIds.add(id);
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();

    expect(deletedIds, [57]);
    expect(loadCalls, 2);
    expect(find.text('Demande de devis supprimée.'), findsOneWidget);
    expect(find.text('Aucune demande de devis'), findsOneWidget);
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
