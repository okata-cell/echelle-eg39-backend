import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echelle_eg_39/promotion_popup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('popup responsive affiche une offre longue et permet de fermer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Accueil'))),
    );
    final context = tester.element(find.text('Accueil'));
    final shownIds = <String>{};
    final future = PromotionPopup.checkAndShowPromotion(
      context,
      sessionShownIds: shownIds,
      now: () => DateTime(2026, 10, 11, 12),
      loadPromotion: () async => {
        'id': 18,
        'titre': 'Offre du moment',
        'description': List.filled(
          40,
          'Remise spéciale sur les équipements topographiques',
        ).join(' '),
        'image_url': '',
        'date_debut': '2026-10-01',
        'date_fin': '2026-10-31',
        'frequence': 'chaque_ouverture',
      },
    );
    await tester.pumpAndSettle();

    expect(find.text('PROMOTION'), findsOneWidget);
    expect(find.text('Offre du moment'), findsOneWidget);
    expect(find.byTooltip('Fermer'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    await future;
    expect(shownIds, contains('18'));
    expect(find.text('Accueil'), findsOneWidget);
  });

  testWidgets('aucune promotion active ne déclenche pas de boîte de dialogue', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Accueil'))),
    );

    await PromotionPopup.checkAndShowPromotion(
      tester.element(find.text('Accueil')),
      loadPromotion: () async => null,
    );
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
