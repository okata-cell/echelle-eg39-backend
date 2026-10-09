import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echelle_eg_39/admin/admin_devis_approval_dialog.dart';

class _ApprovalHarness extends StatefulWidget {
  const _ApprovalHarness();

  @override
  State<_ApprovalHarness> createState() => _ApprovalHarnessState();
}

class _ApprovalHarnessState extends State<_ApprovalHarness> {
  int? _approvedAmount;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (dialogHostContext) => Column(
            children: [
              ElevatedButton(
                onPressed: () async {
                  final amount = await showAdminDevisApprovalDialog(
                    dialogHostContext,
                    devisId: 57,
                  );
                  if (mounted) setState(() => _approvedAmount = amount);
                },
                child: const Text('Ouvrir le formulaire'),
              ),
              if (_approvedAmount != null) Text('Montant: $_approvedAmount'),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('valide le montant et refuse une valeur vide ou nulle', (
    tester,
  ) async {
    await tester.pumpWidget(const _ApprovalHarness());
    await tester.tap(find.text('Ouvrir le formulaire'));
    await tester.pumpAndSettle();

    expect(find.text('Approuver le devis #57'), findsOneWidget);
    expect(find.text('Montant (FCFA)'), findsOneWidget);

    await tester.tap(find.text('Confirmer l’approbation'));
    await tester.pumpAndSettle();
    expect(
      find.text('Saisissez un montant entier supérieur à zéro.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextFormField), '0');
    await tester.tap(find.text('Confirmer l’approbation'));
    await tester.pumpAndSettle();
    expect(
      find.text('Saisissez un montant entier supérieur à zéro.'),
      findsOneWidget,
    );
  });

  testWidgets('renvoie le montant entier positif après confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(const _ApprovalHarness());
    await tester.tap(find.text('Ouvrir le formulaire'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '1250000');
    await tester.tap(find.text('Confirmer l’approbation'));
    await tester.pumpAndSettle();

    expect(find.text('Montant: 1250000'), findsOneWidget);
  });

  testWidgets('le montant soumis ne peut pas dépasser la borne entière sûre', (
    tester,
  ) async {
    await tester.pumpWidget(const _ApprovalHarness());
    await tester.tap(find.text('Ouvrir le formulaire'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '9007199254740992');
    await tester.tap(find.text('Confirmer l’approbation'));
    await tester.pumpAndSettle();

    expect(find.text('Le montant saisi est trop élevé.'), findsOneWidget);
  });
}
