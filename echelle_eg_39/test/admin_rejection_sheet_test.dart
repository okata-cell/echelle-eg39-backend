import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echelle_eg_39/admin/admin_components.dart';

void main() {
  testWidgets('annuler ferme la feuille et libère correctement le champ', (
    tester,
  ) async {
    Future<String?>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                result = showAdminRejectionSheet(
                  context,
                  entityLabel: 'la réservation #89',
                );
              },
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Motif de test');
    await tester.pump();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(await result, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirmer renvoie le motif et libère correctement le champ', (
    tester,
  ) async {
    Future<String?>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                result = showAdminRejectionSheet(
                  context,
                  entityLabel: 'la demande d’achat #42',
                );
              },
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Motif valable');
    await tester.pump();
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();

    expect(await result, 'Motif valable');
    expect(tester.takeException(), isNull);
  });
}
