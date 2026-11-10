// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'package:echelle_eg_39/quote_request_lock.dart';
import 'package:echelle_eg_39/widgets/quote_pending_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _devis({
  int id = 1,
  String serviceId = '1',
  String statut = 'en_attente',
  String createdAt = '2026-11-10T10:15:00.000Z',
}) {
  return <String, dynamic>{
    'id': id,
    'serviceId': serviceId,
    'statut': statut,
    'createdAt': createdAt,
  };
}

void main() {
  group('devisAttendReponse', () {
    test('reconnaît les deux statuts sans réponse', () {
      expect(devisAttendReponse('en_attente'), isTrue);
      expect(devisAttendReponse('en_traitement'), isTrue);
      expect(devisAttendReponse(' EN_TRAITEMENT '), isTrue);
    });

    test('laisse passer après une décision de l’admin', () {
      expect(devisAttendReponse('approuvee'), isFalse);
      expect(devisAttendReponse('rejetee'), isFalse);
      expect(devisAttendReponse('termine'), isFalse);
      expect(devisAttendReponse(null), isFalse);
    });
  });

  group('indexerDevisOuverts', () {
    test('verrouille la prestation tant que la réponse n’est pas arrivée', () {
      final index = indexerDevisOuverts(<Map<String, dynamic>>[
        _devis(id: 4, serviceId: '1'),
        _devis(id: 5, serviceId: '2', statut: 'en_traitement'),
      ]);

      expect(index.keys, containsAll(<String>['1', '2']));
      expect(index['1']!['id'], 4);
    });

    test('débloque la prestation après approbation ou rejet', () {
      final index = indexerDevisOuverts(<Map<String, dynamic>>[
        _devis(id: 6, serviceId: '1', statut: 'approuvee'),
        _devis(id: 7, serviceId: '2', statut: 'rejetee'),
      ]);

      expect(index, isEmpty);
    });

    test('garde la demande la plus récente pour un même service', () {
      final index = indexerDevisOuverts(<Map<String, dynamic>>[
        _devis(id: 8, createdAt: '2026-11-08T09:00:00.000Z'),
        _devis(id: 9, createdAt: '2026-11-10T09:00:00.000Z'),
      ]);

      expect(index['1']!['id'], 9);
    });

    test('ignore les demandes sans service identifié', () {
      final index = indexerDevisOuverts(<Map<String, dynamic>>[
        _devis(id: 10, serviceId: ''),
      ]);

      expect(index, isEmpty);
    });
  });

  test('devisOuvertPourService ne verrouille que le bon service', () {
    final devis = <Map<String, dynamic>>[
      _devis(id: 3, serviceId: '9', statut: 'en_traitement'),
    ];

    expect(devisOuvertPourService(devis, '9')?['id'], 3);
    expect(devisOuvertPourService(devis, '41'), isNull);
    expect(devisOuvertPourService(devis, null), isNull);
  });

  test('libellés affichés sur la carte', () {
    expect(libelleStatutDemande('en_traitement'), 'En cours d’examen');
    expect(libelleStatutDemande('en_attente'), 'En attente de traitement');
    expect(referenceDemande(16), 'DEV-16');
    expect(referenceDemande(null), '');
    expect(dateDemandeVersTexte('2026-11-10T09:00:00.000'), contains('/11/'));
  });

  testWidgets('la carte annonce l’attente et mène au suivi', (tester) async {
    var suiviOuvert = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: QuotePendingNotice(
              demande: _devis(id: 16),
              onSuivre: () => suiviOuvert = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Demande en attente de réponse'), findsOneWidget);
    expect(find.textContaining('DEV-16'), findsOneWidget);
    expect(find.text('Suivre'), findsOneWidget);
    expect(find.textContaining('Demander un devis'), findsNothing);

    await tester.tap(find.byType(QuotePendingNotice));
    expect(suiviOuvert, isTrue);
  });
}

/// Alias de lecture pour le test : la fonction publique garde son nom métier.
String dateDemandeVersTexte(String createdAt) => dateDemandeLibelle(createdAt);
