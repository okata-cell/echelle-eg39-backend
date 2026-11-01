import 'package:echelle_eg_39/app_links.dart';
import 'package:echelle_eg_39/widgets/invite_app_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _androidUrl =
    'https://play.google.com/store/apps/details?id=com.okata.echelleeg39';
const _iosUrl = 'https://apps.apple.com/app/id1234567890';

Widget _host(Widget dialog) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () =>
                showDialog<void>(context: context, builder: (_) => dialog),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester, Widget dialog) async {
  await tester.pumpWidget(_host(dialog));
  await tester.tap(find.text('Ouvrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('avant publication, l’écran annonce honnêtement l’attente', (
    tester,
  ) async {
    await _open(tester, const InviteAppDialog());

    expect(find.text('Application bientôt disponible'), findsOneWidget);
    expect(find.byKey(const ValueKey('invite-unavailable')), findsOneWidget);
    expect(find.textContaining('n’est pas encore publiée'), findsOneWidget);

    // Aucun lien de store n’est proposé tant qu’il n’existe pas.
    expect(find.byKey(const ValueKey('invite-store-android')), findsNothing);
    expect(find.byKey(const ValueKey('invite-store-ios')), findsNothing);
    expect(find.byKey(const ValueKey('invite-share')), findsNothing);
  });

  testWidgets('après publication, les deux stores sont proposés', (
    tester,
  ) async {
    final opened = <Uri>[];
    await _open(
      tester,
      InviteAppDialog(
        androidUrl: _androidUrl,
        iosUrl: _iosUrl,
        openUri: (uri) async {
          opened.add(uri);
          return true;
        },
      ),
    );

    expect(find.text('Inviter à installer'), findsOneWidget);
    expect(find.text('Google Play'), findsOneWidget);
    expect(find.text('App Store'), findsOneWidget);
    expect(find.textContaining('n’est pas encore publiée'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('invite-store-ios')));
    await tester.pumpAndSettle();

    expect(opened.single.toString(), _iosUrl);
  });

  testWidgets('l’invitation se partage avec les deux liens', (tester) async {
    final shared = <String>[];
    await _open(
      tester,
      InviteAppDialog(
        androidUrl: _androidUrl,
        iosUrl: _iosUrl,
        openSystemShare: (text, subject) async => shared.add(text),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('invite-share')));
    await tester.pumpAndSettle();

    expect(shared.single, contains(_androidUrl));
    expect(shared.single, contains(_iosUrl));
    expect(shared.single, contains(AppLinks.androidPackageId));
  });

  testWidgets('le message d’invitation peut être copié', (tester) async {
    final copied = <String>[];
    await _open(
      tester,
      InviteAppDialog(
        androidUrl: _androidUrl,
        copyText: (text) async => copied.add(text),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('invite-copy')));
    await tester.pump();

    expect(copied.single, contains(_androidUrl));
    expect(find.text('Copié'), findsOneWidget);
  });

  testWidgets('l’écran tient sur un petit écran', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _open(
      tester,
      const InviteAppDialog(androidUrl: _androidUrl, iosUrl: _iosUrl),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Google Play'), findsOneWidget);
  });
}
