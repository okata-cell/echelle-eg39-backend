import 'package:echelle_eg_39/company_contact.dart';
import 'package:echelle_eg_39/company_location.dart';
import 'package:echelle_eg_39/company_share.dart';
import 'package:echelle_eg_39/widgets/share_company_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

Future<void> _tapRow(WidgetTester tester, String key) async {
  final row = find.byKey(ValueKey(key));
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('la feuille affiche les réseaux et la fiche à envoyer', (
    tester,
  ) async {
    await _open(tester, const ShareCompanyDialog());

    for (final label in [
      'WhatsApp',
      'Facebook',
      'Instagram',
      'Telegram',
      'X',
      'LinkedIn',
      'E-mail',
    ]) {
      expect(find.text(label), findsOneWidget, reason: '$label manquant');
    }
    expect(find.text('Autres applications'), findsOneWidget);
    expect(find.text('Copier le message'), findsOneWidget);
    expect(find.text(CompanyContact.phoneDisplay), findsOneWidget);
    expect(find.text(CompanyContact.email), findsOneWidget);
    expect(find.byKey(const ValueKey('share-message-preview')), findsOneWidget);
  });

  testWidgets('WhatsApp ouvre le composeur avec le message complet', (
    tester,
  ) async {
    final opened = <Uri>[];
    await _open(
      tester,
      ShareCompanyDialog(
        openUri: (uri) async {
          opened.add(uri);
          return true;
        },
      ),
    );

    await _tapRow(tester, 'share-network-whatsapp');

    expect(opened.single.host, 'wa.me');
    expect(
      opened.single.queryParameters['text'],
      contains(CompanyLocation.mapsUrl),
    );
    expect(find.byType(ShareCompanyDialog), findsNothing);
  });

  testWidgets('Instagram copie le message puis ouvre l’application', (
    tester,
  ) async {
    final opened = <Uri>[];
    final copied = <String>[];
    await _open(
      tester,
      ShareCompanyDialog(
        openUri: (uri) async {
          opened.add(uri);
          return true;
        },
        copyText: (text) async => copied.add(text),
      ),
    );

    await _tapRow(tester, 'share-network-instagram');

    expect(copied.single, CompanyShare.fullMessage);
    expect(opened.single.scheme, 'instagram');
  });

  testWidgets('un réseau absent copie le message au lieu d’échouer', (
    tester,
  ) async {
    final copied = <String>[];
    await _open(
      tester,
      ShareCompanyDialog(
        openUri: (_) async => false,
        copyText: (text) async => copied.add(text),
      ),
    );

    await _tapRow(tester, 'share-network-telegram');

    expect(copied.single, CompanyShare.fullMessage);
    expect(
      find.text('Réseau indisponible. Message copié dans le presse-papiers.'),
      findsOneWidget,
    );
  });

  testWidgets('la copie confirme puis referme la feuille', (tester) async {
    final copied = <String>[];
    await _open(
      tester,
      ShareCompanyDialog(copyText: (text) async => copied.add(text)),
    );

    final copyRow = find.byKey(const ValueKey('share-action-copy'));
    await tester.ensureVisible(copyRow);
    await tester.pumpAndSettle();
    await tester.tap(copyRow);
    await tester.pump();

    expect(copied.single, CompanyShare.fullMessage);
    expect(find.text('Copié'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(ShareCompanyDialog), findsNothing);
  });

  testWidgets('« Autres applications » lance la feuille du système', (
    tester,
  ) async {
    final shared = <String>[];
    await _open(
      tester,
      ShareCompanyDialog(
        openSystemShare: (text, subject) async => shared.add(text),
      ),
    );

    await _tapRow(tester, 'share-action-system');

    expect(shared.single, CompanyShare.fullMessage);
  });

  testWidgets('la feuille tient sur un écran de 320 px', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _open(tester, const ShareCompanyDialog());

    expect(tester.takeException(), isNull);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.byKey(const ValueKey('share-message-toggle')), findsOneWidget);
  });
}
