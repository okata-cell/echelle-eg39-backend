import 'package:echelle_eg_39/change_temporary_password.page.dart';
import 'package:echelle_eg_39/widgets/temporary_password_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  ValueNotifier<String?> captureClipboard() {
    final copied = ValueNotifier<String?>(null);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.value = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    return copied;
  }

  Future<void> openDialog(
    WidgetTester tester, {
    required Duration duration,
    required ValueNotifier<TemporaryPasswordAction?> result,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result.value = await showTemporaryPasswordDialog(
                    context,
                    password: '4821KLMN',
                    duration: duration,
                  );
                },
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('affiche le mot de passe temporaire, le copie et se ferme', (
    tester,
  ) async {
    final clipboard = captureClipboard();
    final result = ValueNotifier<TemporaryPasswordAction?>(null);

    await openDialog(
      tester,
      duration: const Duration(seconds: 120),
      result: result,
    );

    expect(find.byType(TemporaryPasswordDialog), findsOneWidget);
    expect(find.text('4821KLMN'), findsOneWidget);
    expect(find.text('Votre accès est rétabli'), findsOneWidget);
    expect(find.textContaining('Se ferme dans 2:00'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('temporary-password-copy-close')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(TemporaryPasswordDialog), findsNothing);
    expect(result.value, TemporaryPasswordAction.close);
    expect(clipboard.value, '4821KLMN');
  });

  testWidgets('se ferme toute seule à la fin du compte à rebours', (
    tester,
  ) async {
    final result = ValueNotifier<TemporaryPasswordAction?>(null);

    await openDialog(
      tester,
      duration: const Duration(seconds: 3),
      result: result,
    );

    expect(find.byType(TemporaryPasswordDialog), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.byType(TemporaryPasswordDialog), findsNothing);
    expect(result.value, TemporaryPasswordAction.close);
  });

  testWidgets('propose de choisir soi-même son mot de passe', (tester) async {
    final result = ValueNotifier<TemporaryPasswordAction?>(null);

    await openDialog(
      tester,
      duration: const Duration(seconds: 120),
      result: result,
    );

    await tester.tap(
      find.byKey(const ValueKey('temporary-password-choose-own')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(result.value, TemporaryPasswordAction.chooseOwn);
  });


  testWidgets('l’écran imposé enregistre le mot de passe choisi', (
    tester,
  ) async {
    String? saved;

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeTemporaryPasswordPage(
          changePassword: (value) async {
            saved = value;
          },
          homeBuilder: () => const Scaffold(body: Text('accueil')),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Choisissez votre mot de passe'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('temporary-new-password')),
      'Chantier#2026',
    );
    await tester.enterText(
      find.byKey(const ValueKey('temporary-confirm-password')),
      'Chantier#2026',
    );
    await tester.tap(find.byKey(const ValueKey('temporary-password-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(saved, 'Chantier#2026');
    expect(find.text('accueil'), findsOneWidget);
  });

  testWidgets('refuse un mot de passe hors format ou mal confirmé', (
    tester,
  ) async {
    String? saved;

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeTemporaryPasswordPage(
          changePassword: (value) async {
            saved = value;
          },
          homeBuilder: () => const Scaffold(body: Text('accueil')),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('temporary-new-password')),
      'abc123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('temporary-confirm-password')),
      '1234AZER',
    );
    await tester.tap(find.byKey(const ValueKey('temporary-password-save')));
    await tester.pump();

    expect(
      find.text('Le mot de passe doit contenir au moins 10 caractères.'),
      findsOneWidget,
    );
    expect(saved, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('temporary-new-password')),
      'Chantier#2026',
    );
    await tester.enterText(
      find.byKey(const ValueKey('temporary-confirm-password')),
      'Chantier#2027',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('temporary-password-save')));
    await tester.pump();

    expect(find.text('Les deux mots de passe ne correspondent pas.'), findsOneWidget);
    expect(saved, isNull);
  });
}
