import 'package:echelle_eg_39/login.page.dart';
import 'package:echelle_eg_39/widgets/clipboard_paste_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simule le presse-papiers du système pour la durée d'un test.
void simulerPressePapiers(String? texte) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    switch (call.method) {
      case 'Clipboard.hasStrings':
        return <String, dynamic>{'value': texte != null && texte.isNotEmpty};
      case 'Clipboard.getData':
        return <String, dynamic>{'text': texte};
    }
    return null;
  });

  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
}

Widget _champIsole(
  TextEditingController controller,
  FocusNode focusNode, {
  bool trim = true,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: 'champ',
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (controller.text.isEmpty)
                  ClipboardPasteAction(
                    controller: controller,
                    focusNode: focusNode,
                    trim: trim,
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('le champ vide propose « Coller » et le remplit', (tester) async {
    simulerPressePapiers('+22890000000');
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);

    await tester.pumpWidget(_champIsole(controller, focus));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Coller'), findsOneWidget);

    await tester.tap(find.byTooltip('Coller'));
    await tester.pumpAndSettle();

    expect(controller.text, '+22890000000');
    // Le champ est rempli : la place revient à l'action de l'écran.
    expect(find.byTooltip('Coller'), findsNothing);
  });

  testWidgets('les espaces et retours à la ligne sont retirés', (tester) async {
    simulerPressePapiers('  okataolaniyi@gmail.com \n');
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);

    await tester.pumpWidget(_champIsole(controller, focus));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Coller'));
    await tester.pumpAndSettle();

    expect(controller.text, 'okataolaniyi@gmail.com');
  });

  testWidgets('le mot de passe est collé tel quel', (tester) async {
    simulerPressePapiers(' 1234AZER ');
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);

    await tester.pumpWidget(_champIsole(controller, focus, trim: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Coller'));
    await tester.pumpAndSettle();

    expect(controller.text, ' 1234AZER ');
  });

  testWidgets('presse-papiers vide : aucune action affichée', (tester) async {
    simulerPressePapiers('');
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);

    await tester.pumpWidget(_champIsole(controller, focus));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Coller'), findsNothing);
  });

  testWidgets('un texte copié pendant l’absence affiche l’action au retour', (
    tester,
  ) async {
    simulerPressePapiers('');
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);

    await tester.pumpWidget(_champIsole(controller, focus));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Coller'), findsNothing);

    // Le client quitte l'app, copie un numéro ailleurs, puis revient. Le cycle
    // de vie impose de passer par chaque état avant de revenir au premier plan.
    simulerPressePapiers('+22890000000');
    final binding = tester.binding;
    for (final etat in <AppLifecycleState>[
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      binding.handleAppLifecycleStateChanged(etat);
    }
    await tester.pump();

    for (final etat in <AppLifecycleState>[
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      binding.handleAppLifecycleStateChanged(etat);
    }
    await tester.pumpAndSettle();

    expect(find.byTooltip('Coller'), findsOneWidget);
  });

  testWidgets('écran de connexion : les deux champs offrent le collage', (
    tester,
  ) async {
    simulerPressePapiers('+22890000000');
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.pumpAndSettle();

    // Email ou téléphone, puis mot de passe.
    expect(find.byTooltip('Coller'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Coller').first);
    await tester.pumpAndSettle();

    final champs = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(champs.first.controller?.text, '+22890000000');
    // Une fois rempli, seul le champ mot de passe propose encore le collage.
    expect(find.byTooltip('Coller'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
