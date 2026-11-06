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
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('explique à l’ouverture que le compte a été supprimé', (
    tester,
  ) async {
    const notice =
        'Votre compte a été supprimé. Vous pouvez en créer un nouveau.';

    await tester.pumpWidget(
      const MaterialApp(home: LoginPage(noticeMessage: notice)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text(notice), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('n’affiche aucune alerte quand la session est valide', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(SnackBar), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
