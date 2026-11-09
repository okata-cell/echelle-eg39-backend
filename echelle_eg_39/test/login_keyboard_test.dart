import 'package:echelle_eg_39/login.page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('l’action principale reste au-dessus du clavier', (tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.pump();

    // Clavier ouvert sur le mot de passe : 300 points logiques sur 932.
    await tester.tap(find.byType(TextField).last);
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pumpAndSettle();

    const hauteurUtile = 2796 / 3 - 900 / 3;
    final bouton = tester.getRect(
      find.widgetWithText(FilledButton, 'Se connecter'),
    );

    expect(bouton.bottom, lessThanOrEqualTo(hauteurUtile));
    expect(bouton.top, greaterThan(0));
    // Le bouton garde sa taille : il n'est ni écrasé, ni hors écran.
    expect(bouton.height, 54);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('sans clavier, le bouton reste en bas de l’écran', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.pump();

    final bouton = tester.getRect(
      find.widgetWithText(FilledButton, 'Se connecter'),
    );

    expect(bouton.bottom, lessThanOrEqualTo(2796 / 3));
    expect(bouton.bottom, greaterThan(2796 / 3 - 80));

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
