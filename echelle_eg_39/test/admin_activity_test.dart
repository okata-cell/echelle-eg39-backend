// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'package:echelle_eg_39/admin/admin_activity_service.dart';
import 'package:echelle_eg_39/admin/admin_activity_sheet.dart';
import 'package:echelle_eg_39/models_admin_activity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AdminActivityEvent _evenement({
  required int id,
  required String kind,
  required String reference,
  required String titre,
  required DateTime createdAt,
  String? demandeur,
  int? montant,
  DateTime? readAt,
  String? description,
  String? demandeStatut,
  bool supprimable = false,
}) {
  return AdminActivityEvent(
    id: id,
    kind: kind,
    reference: reference,
    titre: titre,
    createdAt: createdAt,
    demandeur: demandeur,
    montant: montant,
    readAt: readAt,
    description: description,
    demandeStatut: demandeStatut,
    supprimable: supprimable,
  );
}

void main() {
  final maintenant = DateTime(2026, 11, 10, 21, 10);

  group('AdminActivityEvent', () {
    test('lit la charge envoyée par le flux', () {
      final evenement = AdminActivityEvent.fromJson(<String, dynamic>{
        'id': 12,
        'kind': 'location',
        'reference': 'LOC-17930-8842',
        'titre': 'Station totale Leica TS06',
        'demandeur': 'Silva Okata · +228 90 94 94 39',
        'montant': 60000,
        'createdAt': '2026-11-10T20:58:00.000Z',
        'readAt': null,
        'metadata': <String, dynamic>{},
      });

      expect(evenement.kind, 'location');
      expect(evenement.reference, 'LOC-17930-8842');
      expect(evenement.montant, 60000);
      expect(evenement.nonLu, isTrue);
      expect(evenement.moduleLabel, 'Locations');
      expect(evenement.createdAt.isUtc, isFalse);
    });

    test('un devis conserve sa description', () {
      final evenement = AdminActivityEvent.fromJson(<String, dynamic>{
        'id': 3,
        'kind': 'devis',
        'reference': 'DEV-17930-8844',
        'titre': 'Implantation de 40 bornes',
        'createdAt': '2026-11-10T20:58:00.000Z',
        'metadata': <String, dynamic>{'description': '3 lots'},
      });

      expect(evenement.description, '3 lots');
      expect(evenement.montant, isNull);
      expect(evenement.moduleLabel, 'Devis');
    });

    test('marqueLu conserve la demande et date la lecture', () {
      final evenement = _evenement(
        id: 1,
        kind: 'vente',
        reference: 'DA-17930',
        titre: 'GPS e-survey E600',
        createdAt: maintenant,
      );

      final lu = evenement.marqueLu(maintenant);
      expect(lu.nonLu, isFalse);
      expect(lu.id, evenement.id);
      expect(lu.reference, evenement.reference);
      expect(lu.readAt, maintenant);
    });
  });

  group('Formats du registre', () {
    test('heure sur deux chiffres', () {
      expect(heureActivite(DateTime(2026, 11, 10, 9, 4)), '09:04');
      expect(heureActivite(DateTime(2026, 11, 10, 19, 58)), '19:58');
    });

    test('ancienneté en paliers', () {
      expect(
        ancienneteActivite(maintenant, maintenant: maintenant),
        'à l’instant',
      );
      expect(
        ancienneteActivite(
          maintenant.subtract(const Duration(seconds: 12)),
          maintenant: maintenant,
        ),
        'il y a 12 s',
      );
      expect(
        ancienneteActivite(
          maintenant.subtract(const Duration(minutes: 4)),
          maintenant: maintenant,
        ),
        'il y a 4 min',
      );
      expect(
        ancienneteActivite(
          maintenant.subtract(const Duration(days: 1)),
          maintenant: maintenant,
        ),
        'hier',
      );
    });

    test('sections par jour', () {
      final sections = grouperParJour(<AdminActivityEvent>[
        _evenement(
          id: 3,
          kind: 'devis',
          reference: 'DEV-3',
          titre: 'Bornes',
          createdAt: DateTime(2026, 11, 10, 19, 58),
        ),
        _evenement(
          id: 2,
          kind: 'vente',
          reference: 'DA-2',
          titre: 'GPS',
          createdAt: DateTime(2026, 11, 9, 18, 20),
        ),
        _evenement(
          id: 1,
          kind: 'location',
          reference: 'LOC-1',
          titre: 'Niveau',
          createdAt: DateTime(2026, 11, 9, 17, 5),
        ),
      ], maintenant: maintenant);

      expect(sections, hasLength(2));
      expect(sections.first.entete, 'Aujourd’hui');
      expect(sections.first.evenements, hasLength(1));
      expect(sections.last.entete, 'Hier, 9 nov.');
      expect(sections.last.evenements, hasLength(2));
    });
  });

  group('AdminActivityService', () {
    test('compte les non-lus par module', () {
      final service = AdminActivityService()
        ..injecter(
          <AdminActivityEvent>[
            _evenement(
              id: 1,
              kind: 'location',
              reference: 'LOC-1',
              titre: 'Station totale',
              createdAt: maintenant,
            ),
            _evenement(
              id: 2,
              kind: 'location',
              reference: 'LOC-2',
              titre: 'Niveau',
              createdAt: maintenant,
            ),
            _evenement(
              id: 3,
              kind: 'devis',
              reference: 'DEV-3',
              titre: 'Bornes',
              createdAt: DateTime(2026, 11, 9, 9),
              readAt: DateTime(2026, 11, 9, 10),
            ),
          ],
          nonLus: <String, int>{'location': 2, 'vente': 1, 'devis': 0},
        );

      expect(service.total, 3);
      expect(service.nonLusDe('location'), 2);
      expect(service.nonLusDe('devis'), 0);
    });

    test('acquitter une demande la garde dans le registre', () async {
      final service = AdminActivityService()
        ..injecter(
          <AdminActivityEvent>[
            _evenement(
              id: 1,
              kind: 'vente',
              reference: 'DA-1',
              titre: 'GPS e-survey',
              createdAt: DateTime.now(),
            ),
          ],
          nonLus: <String, int>{'location': 0, 'vente': 1, 'devis': 0},
        );

      await service.marquerLu(service.evenements.first);

      expect(service.evenements, hasLength(1));
      expect(service.evenements.first.nonLu, isFalse);
      expect(service.total, 0);
    });
  });

  testWidgets('la feuille Activité liste les demandes non lues', (
    tester,
  ) async {
    // Demandes reçues dans l'heure : la section affichée est celle du jour,
    // quel que soit le moment où la suite de tests est exécutée.
    final maintenant = DateTime.now();
    final service = AdminActivityService()
      ..injecter(
        <AdminActivityEvent>[
          _evenement(
            id: 1,
            kind: 'location',
            reference: 'LOC-17930-8842',
            titre: 'Station totale Leica TS06',
            createdAt: maintenant.subtract(const Duration(minutes: 12)),
            demandeur: 'Silva Okata · +228 90 94 94 39',
            montant: 60000,
          ),
          _evenement(
            id: 2,
            kind: 'devis',
            reference: 'DEV-17930-8844',
            titre: 'Implantation de 40 bornes',
            createdAt: maintenant.subtract(const Duration(minutes: 46)),
            demandeur: 'Ayi Mensah',
            description: '3 lots',
          ),
        ],
        nonLus: <String, int>{'location': 1, 'vente': 0, 'devis': 1},
      );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminActivitySheet(service: service, onModuleSelected: (_) {}),
        ),
      ),
    );

    expect(find.text('Activité'), findsOneWidget);
    expect(find.text('à traiter'), findsOneWidget);
    expect(find.text('LOC-17930-8842'), findsOneWidget);
    expect(find.text('Implantation de 40 bornes'), findsOneWidget);
    expect(find.text('Aujourd’hui'.toUpperCase()), findsOneWidget);
    expect(find.text('Tout marquer comme lu'), findsOneWidget);
  });

  group('Suppression de l’historique', () {
    test('le statut et l’autorisation viennent du serveur', () {
      final clos = AdminActivityEvent.fromJson(<String, dynamic>{
        'id': 7,
        'kind': 'location',
        'reference': 'LOC-7',
        'titre': 'Station totale',
        'createdAt': '2026-11-11T10:00:00.000Z',
        'demandeStatut': 'termine',
        'supprimable': true,
      });

      expect(clos.demandeStatut, 'termine');
      expect(clos.supprimable, isTrue);
      // L'acquittement ne doit pas effacer l'autorisation de suppression.
      expect(clos.marqueLu(DateTime(2026, 11, 11, 12)).supprimable, isTrue);

      final ouverte = AdminActivityEvent.fromJson(<String, dynamic>{
        'id': 8,
        'kind': 'devis',
        'reference': 'DEV-8',
        'titre': 'Bornes',
        'createdAt': '2026-11-11T10:00:00.000Z',
        'demandeStatut': 'en_cours',
        'supprimable': false,
      });

      expect(ouverte.supprimable, isFalse);
    });

    testWidgets('la corbeille n’apparaît que sur les demandes closes', (
      tester,
    ) async {
      final service = AdminActivityService()
        ..injecter(
          <AdminActivityEvent>[
            _evenement(
              id: 1,
              kind: 'location',
              reference: 'LOC-CLOSE',
              titre: 'Station totale rendue',
              createdAt: DateTime.now(),
              demandeStatut: 'termine',
              supprimable: true,
            ),
            _evenement(
              id: 2,
              kind: 'location',
              reference: 'LOC-OUVERTE',
              titre: 'Niveau en cours',
              createdAt: DateTime.now(),
              demandeStatut: 'en_cours',
            ),
          ],
          nonLus: <String, int>{'location': 0, 'vente': 0, 'devis': 0},
        );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminActivitySheet(service: service, onModuleSelected: (_) {}),
          ),
        ),
      );

      expect(find.byTooltip('Retirer de l’historique'), findsOneWidget);
      expect(find.text('LOC-CLOSE'), findsOneWidget);
      expect(find.text('LOC-OUVERTE'), findsOneWidget);
    });

    testWidgets('la corbeille demande confirmation avant de retirer', (
      tester,
    ) async {
      final service = AdminActivityService()
        ..injecter(
          <AdminActivityEvent>[
            _evenement(
              id: 1,
              kind: 'vente',
              reference: 'DA-CLOSE',
              titre: 'GPS livré',
              createdAt: DateTime.now(),
              demandeStatut: 'livree',
              supprimable: true,
            ),
          ],
          nonLus: <String, int>{'location': 0, 'vente': 0, 'devis': 0},
        );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminActivitySheet(service: service, onModuleSelected: (_) {}),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Retirer de l’historique'));
      await tester.pumpAndSettle();

      expect(find.text('Retirer de l’historique ?'), findsOneWidget);
      expect(find.textContaining('la fiche reste intacte'), findsOneWidget);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(find.text('Retirer de l’historique ?'), findsNothing);
      expect(service.evenements, hasLength(1));
      expect(find.text('DA-CLOSE'), findsOneWidget);
    });
  });
}
