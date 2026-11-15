import 'package:echelle_eg_39/login.page.dart';
import 'package:echelle_eg_39/login_lockout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('libellé du décompte', () {
    test('affiche les heures et les minutes restantes', () {
      // 11 h 40 restantes : la forme attendue par l'écran de connexion.
      expect(
        libelleDelaiRestant(const Duration(hours: 11, minutes: 40)),
        '11 h 40',
      );
      expect(libelleDelaiRestant(const Duration(hours: 3)), '3 h');
      expect(libelleDelaiRestant(const Duration(minutes: 47)), '47 min');
      expect(
        libelleDelaiRestant(const Duration(seconds: 12)),
        'moins d’une minute',
      );
      expect(libelleDelaiRestant(Duration.zero), 'moins d’une minute');
      // Une échéance dépassée ne s'affiche jamais en négatif.
      expect(
        libelleDelaiRestant(const Duration(seconds: -30)),
        'moins d’une minute',
      );
    });

    test('la durée par défaut reste celle du serveur', () {
      expect(delaiBlocageParDefaut, const Duration(hours: 12));
    });

    test('une clé de mémoire par identifiant', () {
      expect(
        cleBlocage(' Client@Example.com '),
        'login_lock_until:client@example.com',
      );
      expect(cleBlocage('   '), isNull);
    });
  });

  group('bandeau de blocage', () {
    setUpAll(() {
      GoogleFonts.config.allowRuntimeFetching = false;
    });

    testWidgets('affiche le décompte et désactive la connexion', (
      tester,
    ) async {
      final echeance = DateTime.now().add(
        const Duration(hours: 11, minutes: 40),
      );

      SharedPreferences.setMockInitialValues({
        'saved_identifier': 'client@example.com',
        'login_lock_until:client@example.com': echeance.toIso8601String(),
      });

      await tester.pumpWidget(const MaterialApp(home: LoginPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.textContaining('Compte bloqué — réessayez dans'),
        findsOneWidget,
      );
      expect(find.textContaining('11 h 39'), findsOneWidget);
      expect(find.text('Connexion bloquée'), findsOneWidget);

      final bouton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(bouton.onPressed, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('n’affiche rien quand le blocage est terminé', (tester) async {
      SharedPreferences.setMockInitialValues({
        'saved_identifier': 'client@example.com',
        'login_lock_until:client@example.com': DateTime.now()
            .subtract(const Duration(minutes: 1))
            .toIso8601String(),
      });

      await tester.pumpWidget(const MaterialApp(home: LoginPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Compte bloqué'), findsNothing);
      expect(find.text('Se connecter'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
