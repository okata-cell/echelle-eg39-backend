import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echelle_eg_39/admin_actualites.page.dart';

Map<String, dynamic> _actualite({
  required int id,
  required String titre,
  required String statut,
  bool epingle = false,
  String date = '2026-11-06',
  String? dateFin,
}) {
  return <String, dynamic>{
    'id': id,
    'titre': titre,
    'description': 'Description de $titre.',
    'date_publication': date,
    'date_fin': dateFin,
    'statut': statut,
    'epingle': epingle,
    'image_url': null,
    'image_storage_path': null,
  };
}

void main() {
  testWidgets('affiche les statuts et publie un brouillon', (tester) async {
    final statutCalls = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminActualitesPage(
            loadActualites: () async => [
              _actualite(
                id: 12,
                titre: 'Nouvelle gamme de stations totales E800',
                statut: 'publiee',
                epingle: true,
              ),
              _actualite(
                id: 11,
                titre: 'Tarifs de location au 1er décembre',
                statut: 'brouillon',
              ),
            ],
            setStatut: (id, statut) async {
              statutCalls.add('$id:$statut');
              return <String, dynamic>{};
            },
            pickImage: (source) async => null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Nouvelle gamme de stations totales E800'),
      findsOneWidget,
    );
    expect(find.text('PUBLIÉE'), findsOneWidget);
    expect(find.text('BROUILLON'), findsOneWidget);

    final publishSwitch = find.byKey(const ValueKey('actualite-publish-11'));
    await tester.ensureVisible(publishSwitch);
    await tester.pumpAndSettle();
    await tester.tap(publishSwitch);
    await tester.pumpAndSettle();

    expect(statutCalls, ['11:publiee']);
  });

  testWidgets('crée une actualité depuis le bouton de l’en-tête', (
    tester,
  ) async {
    final created = <Map<String, dynamic>>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminActualitesPage(
            loadActualites: () async => [],
            createActualite: (payload) async {
              created.add(payload);
              return <String, dynamic>{};
            },
            pickImage: (source) async => null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucune actualité'), findsOneWidget);

    await tester.tap(find.byTooltip('Créer une actualité'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('actualite-editor-titre')),
      'Douze niveaux automatiques livrés',
    );
    await tester.enterText(
      find.byKey(const ValueKey('actualite-editor-description')),
      'Commande contrôlée le 3 novembre.',
    );
    // La publication est active par défaut : l'actualité doit apparaître
    // sur l'accueil dès l'enregistrement.
    final submitButton = find.byKey(const ValueKey('actualite-editor-submit'));
    await tester.ensureVisible(submitButton);
    await tester.pumpAndSettle();
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(created, hasLength(1));
    expect(created.single['titre'], 'Douze niveaux automatiques livrés');
    expect(created.single['statut'], 'publiee');
    expect(created.single['epingle'], isFalse);
    // La fenêtre de publication part avec les deux bornes.
    expect(created.single['date_publication'], isNotNull);
    expect(created.single['date_fin'], isNotNull);
  });
}
