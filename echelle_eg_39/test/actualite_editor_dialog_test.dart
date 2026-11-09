import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echelle_eg_39/actualite.dart';
import 'package:echelle_eg_39/admin/actualite_editor_dialog.dart';

void main() {
  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openSheet(WidgetTester tester, Widget sheet) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(body: sheet),
                  ),
                ),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('renvoie le titre, la description et les deux interrupteurs', (
    tester,
  ) async {
    ActualiteDraft? submitted;

    await openSheet(
      tester,
      ActualiteEditorSheet(onSubmit: (draft) async => submitted = draft),
    );

    expect(find.text('Nouvelle actualité'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('actualite-editor-titre')),
      'Nouvelle gamme de stations totales E800',
    );
    await tester.enterText(
      find.byKey(const ValueKey('actualite-editor-description')),
      'Trois modèles en stock à l’agence.',
    );
    await tapKey(tester, 'actualite-editor-pin');
    // La publication est active par défaut pour une nouvelle actualité.
    await tapKey(tester, 'actualite-editor-submit');

    expect(submitted, isNotNull);
    expect(submitted!.titre, 'Nouvelle gamme de stations totales E800');
    expect(submitted!.description, 'Trois modèles en stock à l’agence.');
    expect(submitted!.epingle, isTrue);
    expect(submitted!.publiee, isTrue);
    expect(submitted!.image, isNull);
    // Trente jours de diffusion par défaut, modifiables par l'administrateur.
    expect(
      submitted!.dateFin.difference(submitted!.datePublication).inDays,
      30,
    );
  });

  testWidgets('refuse un formulaire vide et affiche une erreur', (
    tester,
  ) async {
    var submitted = false;

    await openSheet(
      tester,
      ActualiteEditorSheet(onSubmit: (draft) async => submitted = true),
    );

    await tapKey(tester, 'actualite-editor-submit');

    expect(submitted, isFalse);
    expect(
      find.text('Le titre et la description sont requis.'),
      findsOneWidget,
    );
  });

  testWidgets('préremplit et supprime une actualité existante', (tester) async {
    var deleted = false;
    final actualite = Actualite(
      id: 42,
      titre: 'Formation GPS RTK',
      description: 'Une journée en atelier puis sur chantier.',
      datePublication: DateTime(2026, 11, 4),
      imageUrl: null,
      epingle: true,
      publiee: true,
    );

    await openSheet(
      tester,
      ActualiteEditorSheet(
        initial: actualite,
        onSubmit: (draft) async {},
        onDelete: () async => deleted = true,
      ),
    );

    expect(find.text('Modifier l’actualité'), findsOneWidget);
    expect(find.text('ACT-42'), findsOneWidget);
    // Le titre apparaît dans l'aperçu et dans le champ de saisie.
    expect(find.text('Formation GPS RTK'), findsWidgets);

    await tapKey(tester, 'actualite-editor-delete');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Supprimer'));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
  });
}
