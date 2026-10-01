import 'package:echelle_eg_39/admin_rejection_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('annuler ferme le dialogue sans erreur de cycle de vie', (
    tester,
  ) async {
    Future<String?>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                result = showAdminRejectionDialog(
                  context,
                  title: 'Rejeter la réservation',
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
    await tester.enterText(find.byType(TextField), 'Motif temporaire');
    await tester.pump();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(await result, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirmer renvoie le motif et ferme sans erreur', (
    tester,
  ) async {
    Future<String?>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                result = showAdminRejectionDialog(
                  context,
                  title: 'Rejeter la demande',
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
    await tester.enterText(find.byType(TextField), 'Motif confirmé');
    await tester.pump();
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();

    expect(await result, 'Motif confirmé');
    expect(tester.takeException(), isNull);
  });
}
