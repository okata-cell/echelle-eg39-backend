import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echelle_eg_39/actualite.dart';
import 'package:echelle_eg_39/actualites_repository.dart';
import 'package:echelle_eg_39/actualites_screen.dart';
import 'package:echelle_eg_39/widgets/actualites_section.dart';

Actualite _actualite({
  required int id,
  required String titre,
  required String description,
  bool epingle = false,
}) {
  return Actualite(
    id: id,
    titre: titre,
    description: description,
    datePublication: DateTime(2026, 11, 6),
    epingle: epingle,
  );
}

void main() {
  final epinglee = _actualite(
    id: 1,
    titre: 'Nouvelle gamme de stations totales',
    description: 'Trois modèles en stock, dont la TS06.',
    epingle: true,
  );
  final formation = _actualite(
    id: 2,
    titre: 'Formation GPS RTK',
    description: 'Une journée en atelier puis sur chantier.',
  );
  final agence = _actualite(
    id: 3,
    titre: 'Nouvelle agence à Kara',
    description: 'Ouverture le 2 décembre.',
  );
  final items = <Actualite>[epinglee, formation, agence];

  testWidgets('l’actualité épinglée affiche sa description comme les autres', (
    tester,
  ) async {
    var seeAll = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ActualitesSection(
              items: items,
              isLoading: false,
              onSeeAll: () => seeAll++,
            ),
          ),
        ),
      ),
    );

    final hero = find.byType(ActualiteHeroCard);
    expect(hero, findsOneWidget);
    expect(
      find.descendant(of: hero, matching: find.text(epinglee.description)),
      findsOneWidget,
    );
    // La description du voisin reste dans sa tuile, pas dans l'affiche.
    expect(
      find.descendant(of: hero, matching: find.text(formation.description)),
      findsNothing,
    );
    expect(find.text(formation.description), findsOneWidget);
    expect(find.text(agence.description), findsOneWidget);
    // L'épinglage se lit dans la description accessible de l'affiche.
    expect(find.bySemanticsLabel(RegExp('Actualité épinglée')), findsOneWidget);

    await tester.tap(find.text('Voir tout'));
    await tester.pump();
    expect(seeAll, 1);
  });

  testWidgets(
    'dans « Toutes les actualités », l’épinglée garde sa description',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final repository = ActualitesRepository(
        fetchPublished: ({int limit = 20}) async =>
            items.map((actualite) => actualite.toCacheJson()).toList(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ActualitesScreen(repository: repository, initialItems: items),
        ),
      );
      await tester.pumpAndSettle();

      final hero = find.byType(ActualiteHeroCard);
      expect(hero, findsOneWidget);
      expect(
        find.descendant(of: hero, matching: find.text(epinglee.description)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: hero, matching: find.text(formation.description)),
        findsNothing,
      );
      expect(find.text(formation.description), findsOneWidget);
    },
  );
}
