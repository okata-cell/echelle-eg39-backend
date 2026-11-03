import 'dart:async';
import 'dart:convert';

import 'package:echelle_eg_39/company_location.dart';
import 'package:echelle_eg_39/profile.dart';
import 'package:echelle_eg_39/profile_api.dart';
import 'package:echelle_eg_39/team.dart';
import 'package:echelle_eg_39/profile_avatar_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _profile({
  String firstName = 'Afi',
  String company = 'EG39',
  String address = 'Aflao Gagli',
  String city = 'Lomé',
  String country = 'Togo',
}) => {
  'id': 7,
  'firstName': firstName,
  'lastName': 'Koffi',
  'email': 'afi@example.com',
  'phone': '+22890000000',
  'company': company,
  'address': address,
  'city': city,
  'country': country,
  'role': 'client',
};

http.Response _json(Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

ProfileApi _fakeProfileApi({
  required Map<String, dynamic> profile,
  required List<Map<String, dynamic>> savedUpdates,
  List<Map<String, dynamic>>? savedAvatars,
  Completer<void>? avatarSaved,
}) {
  final client = MockClient((request) async {
    if (request.method == 'GET' && request.url.path.endsWith('/profile/me')) {
      return _json({'profile': profile});
    }
    if (request.method == 'PATCH' && request.url.path.endsWith('/profile/me')) {
      final update = jsonDecode(request.body) as Map<String, dynamic>;
      savedUpdates.add(update);
      profile.addAll(update);
      return _json({'profile': profile, 'token': 'renewed'});
    }
    if (request.method == 'PUT' &&
        request.url.path.endsWith('/profile/me/avatar')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final avatar = Map<String, dynamic>.from(body['image'] as Map);
      savedAvatars?.add(avatar);
      if (avatarSaved != null && !avatarSaved.isCompleted) {
        avatarSaved.complete();
      }
      profile
        ..['avatarData'] = avatar['data']
        ..['avatarMimeType'] = avatar['mimeType'];
      return _json({'profile': profile});
    }
    return http.Response('{}', 404);
  });
  return ProfileApi(client: client, baseUrl: 'https://api.test/api');
}

Future<void> _openProfileMenu(WidgetTester tester, String title) async {
  final menuItem = find.byKey(ValueKey('profile-menu-$title'));
  await tester.ensureVisible(menuItem);
  await tester.tap(menuItem);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'token': 'client-token'});
  });

  testWidgets('charge le profil et enregistre les modifications via API', (
    tester,
  ) async {
    final profile = _profile();
    final savedUpdates = <Map<String, dynamic>>[];
    final api = _fakeProfileApi(profile: profile, savedUpdates: savedUpdates);
    addTearDown(api.dispose);

    await tester.pumpWidget(MaterialApp(home: ProfilScreen(profileApi: api)));
    await tester.pumpAndSettle();
    expect(find.text('Afi Koffi'), findsOneWidget);

    await _openProfileMenu(tester, 'Informations personnelles');

    // Le formulaire s’ouvre sur les coordonnées : l’identité est un onglet.
    await tester.tap(find.text('Identité'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('profile-first-name')),
      'Ama',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    expect(savedUpdates.single['firstName'], 'Ama');

    // Les champs facultatifs traversent le formulaire sans être perdus.
    expect(savedUpdates.single['company'], 'EG39');
    expect(savedUpdates.single['address'], 'Aflao Gagli');
    expect(savedUpdates.single['city'], 'Lomé');
    expect(savedUpdates.single['country'], 'Togo');
    expect(find.text('Ama Koffi'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('token'), 'renewed');
    expect(prefs.getString('userName'), 'Ama Koffi');
  });

  testWidgets('normalise une image au nom inconnu avant envoi de l’avatar', (
    tester,
  ) async {
    final profile = _profile();
    final savedUpdates = <Map<String, dynamic>>[];
    final savedAvatars = <Map<String, dynamic>>[];
    final avatarPicked = Completer<void>();
    final avatarSaved = Completer<void>();
    ImageSource? pickedSource;
    final api = _fakeProfileApi(
      profile: profile,
      savedUpdates: savedUpdates,
      savedAvatars: savedAvatars,
      avatarSaved: avatarSaved,
    );
    addTearDown(api.dispose);
    final png = image_lib.encodePng(image_lib.Image(width: 12, height: 12));

    await tester.pumpWidget(
      MaterialApp(
        home: ProfilScreen(
          profileApi: api,
          pickAvatarImage: (source) async {
            pickedSource = source;
            if (!avatarPicked.isCompleted) avatarPicked.complete();
            return XFile.fromData(
              png,
              name: 'photo.format-inconnu',
              mimeType: 'application/octet-stream',
            );
          },
          normalizeAvatarImage: (bytes) async {
            expect(bytes, png);
            return NormalizedProfileAvatar(
              bytes: image_lib.encodeJpg(image_lib.Image(width: 8, height: 8)),
              mimeType: 'image/jpeg',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Galerie'));
    await tester.pump();
    await tester.runAsync(
      () => avatarPicked.future.timeout(const Duration(seconds: 2)),
    );
    expect(pickedSource, ImageSource.gallery);
    await tester.runAsync(
      () => avatarSaved.future.timeout(const Duration(seconds: 10)),
    );
    await tester.pumpAndSettle();

    expect(savedAvatars, hasLength(1));
    expect(savedAvatars.single['mimeType'], 'image/jpeg');
    final uploadedBytes = base64Decode(savedAvatars.single['data'] as String);
    expect(uploadedBytes.take(3), [0xff, 0xd8, 0xff]);
    expect(find.text('Photo de profil enregistrée.'), findsOneWidget);
  });

  testWidgets(
    'recherche l’entreprise par nom et localisation dans Google Maps',
    (tester) async {
      final profile = _profile();
      final savedUpdates = <Map<String, dynamic>>[];
      final api = _fakeProfileApi(profile: profile, savedUpdates: savedUpdates);
      addTearDown(api.dispose);
      final openedUrls = <Uri>[];

      await tester.pumpWidget(
        MaterialApp(
          home: ProfilScreen(
            profileApi: api,
            launchGoogleMaps: (uri) async {
              openedUrls.add(uri);
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final aboutMenuItem = find.byKey(const ValueKey('profile-menu-À propos'));
      await tester.ensureVisible(aboutMenuItem);
      await tester.tap(aboutMenuItem);
      await tester.pumpAndSettle();
      final companyInfoItem = find.text("Informations sur l'entreprise");
      await tester.ensureVisible(companyInfoItem);
      await tester.tap(companyInfoItem);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Itinéraire'));
      await tester.pumpAndSettle();

      expect(openedUrls, hasLength(1));
      expect(
        openedUrls.single.toString(),
        'https://maps.app.goo.gl/BtGKf2gwjaLpKFQN7?g_st=iw',
      );
    },
  );

  testWidgets('retire les entrées supprimées du menu', (tester) async {
    final profile = _profile();
    final savedUpdates = <Map<String, dynamic>>[];
    final api = _fakeProfileApi(profile: profile, savedUpdates: savedUpdates);
    addTearDown(api.dispose);

    await tester.pumpWidget(MaterialApp(home: ProfilScreen(profileApi: api)));
    await tester.pumpAndSettle();

    for (final removed in [
      'Paramètres',
      'Préférences de contact',
      'Entreprise',
      'Adresse de l’entreprise',
    ]) {
      expect(find.byKey(ValueKey('profile-menu-$removed')), findsNothing);
    }

    expect(
      find.byKey(const ValueKey('profile-menu-Mot de passe')),
      findsOneWidget,
    );
  });

  testWidgets(
    'la carte de l’agence s’affiche sans clic sous « Nous localiser »',
    (tester) async {
      final api = _fakeProfileApi(
        profile: _profile(),
        savedUpdates: <Map<String, dynamic>>[],
      );
      addTearDown(api.dispose);
      final inlineMap = find.byKey(const ValueKey('inline-company-map'));

      await tester.pumpWidget(
        MaterialApp(
          home: ProfilScreen(
            profileApi: api,
            companyLocationCardBuilder: (_) => const SizedBox(
              key: ValueKey('inline-company-map'),
              height: 180,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final locationItem = find.byKey(
        const ValueKey('profile-menu-Nous localiser'),
      );
      await tester.ensureVisible(locationItem);
      await tester.pumpAndSettle();

      // Aucun clic : la carte est déjà là, juste sous son intitulé.
      expect(inlineMap, findsOneWidget);
      expect(find.text('Afi Koffi'), findsOneWidget);
      expect(
        tester.getTopLeft(inlineMap).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(locationItem).dy - 0.5),
      );

      // Plus aucun libellé de repli ni chevron sur cette entrée.
      expect(find.text('Réduire'), findsNothing);
      expect(find.text('Carte'), findsNothing);
      expect(
        find.descendant(
          of: locationItem,
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsNothing,
      );

      // L'entrée n'est plus un bouton : toucher ne masque pas la carte.
      await tester.tap(locationItem);
      await tester.pumpAndSettle();
      expect(inlineMap, findsOneWidget);
    },
  );

  testWidgets('le centre d’aide ne garde que les rubriques actives', (
    tester,
  ) async {
    final api = _fakeProfileApi(
      profile: _profile(),
      savedUpdates: <Map<String, dynamic>>[],
    );
    addTearDown(api.dispose);

    await tester.pumpWidget(MaterialApp(home: ProfilScreen(profileApi: api)));
    await tester.pumpAndSettle();

    final helpItem = find.byKey(const ValueKey('profile-menu-Centre d\'aide'));
    await tester.ensureVisible(helpItem);
    await tester.tap(helpItem);
    await tester.pumpAndSettle();

    for (final kept in ['FAQ dynamique', 'Glossaire', 'Contact direct']) {
      expect(find.text(kept), findsOneWidget, reason: '$kept doit rester');
    }
    for (final removed in [
      'Tutoriels vidéo',
      'Base de connaissances',
      'Centre de formation',
      'Signaler un problème',
    ]) {
      expect(find.text(removed), findsNothing, reason: '$removed est supprimé');
    }
  });

  testWidgets('Contact direct ouvre tel/mailto et copie en cas d’absence', (
    tester,
  ) async {
    final api = _fakeProfileApi(
      profile: _profile(),
      savedUpdates: <Map<String, dynamic>>[],
    );
    addTearDown(api.dispose);
    final opened = <Uri>[];
    final clipboard = <String>[];
    var canOpen = true;
    final messenger = TestDefaultBinaryMessengerBinding.instance;
    messenger.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final payload = call.arguments as Map<Object?, Object?>;
          clipboard.add(payload['text'] as String? ?? '');
        }
        return null;
      },
    );
    addTearDown(
      () => messenger.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ProfilScreen(
          profileApi: api,
          launchContactUri: (uri) async {
            opened.add(uri);
            return canOpen;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final helpItem = find.byKey(const ValueKey('profile-menu-Centre d\'aide'));
    await tester.ensureVisible(helpItem);
    await tester.tap(helpItem);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Contact direct'));
    await tester.pumpAndSettle();

    // L’adresse affichée est celle exploitée par l’entreprise.
    expect(find.text('admin@echelle-eg39.com'), findsOneWidget);
    expect(find.textContaining('contact@echelle-eg39.com'), findsNothing);

    await tester.tap(find.text('Téléphone'));
    await tester.pumpAndSettle();
    expect(opened.last.scheme, 'tel');
    expect(opened.last.path, '+22890014329');

    canOpen = false;
    await tester.tap(find.text('E-mail'));
    await tester.pumpAndSettle();
    expect(opened.last.scheme, 'mailto');
    expect(opened.last.path, 'admin@echelle-eg39.com');
    expect(find.textContaining('Adresse copiée'), findsOneWidget);
    expect(clipboard, contains('admin@echelle-eg39.com'));

    final copiesBeforeWhatsApp = clipboard.length;
    canOpen = true;
    await tester.tap(find.text('WhatsApp'));
    await tester.pumpAndSettle();
    expect(opened.last.host, 'wa.me');
    expect(opened.last.path, '/22890014329');
    expect(clipboard.length, copiesBeforeWhatsApp);
  });

  testWidgets('le partage écrit à l’adresse exploitée par l’entreprise', (
    tester,
  ) async {
    final api = _fakeProfileApi(
      profile: _profile(),
      savedUpdates: <Map<String, dynamic>>[],
    );
    addTearDown(api.dispose);
    final opened = <Uri>[];

    await tester.pumpWidget(
      MaterialApp(
        home: ProfilScreen(
          profileApi: api,
          launchContactUri: (uri) async {
            opened.add(uri);
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _openProfileMenu(tester, 'À propos');
    await tester.scrollUntilVisible(
      find.text('Partager nos coordonnées'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Partager nos coordonnées'));
    await tester.pumpAndSettle();

    final emailRow = find.byKey(const ValueKey('share-network-email'));
    await tester.ensureVisible(emailRow);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-network-email')));
    await tester.pumpAndSettle();

    expect(opened.last.scheme, 'mailto');
    expect(opened.last.path, 'admin@echelle-eg39.com');
    expect(opened.last.queryParameters['subject'], contains('ÉCHELLE EG39'));
    expect(
      opened.last.queryParameters['body'],
      contains('admin@echelle-eg39.com'),
    );
    expect(opened.last.queryParameters['body'], isNot(contains('contact@')));
  });

  testWidgets('le partage propose les réseaux sociaux avec leurs marques', (
    tester,
  ) async {
    final api = _fakeProfileApi(
      profile: _profile(),
      savedUpdates: <Map<String, dynamic>>[],
    );
    addTearDown(api.dispose);
    final opened = <Uri>[];

    await tester.pumpWidget(
      MaterialApp(
        home: ProfilScreen(
          profileApi: api,
          launchContactUri: (uri) async {
            opened.add(uri);
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _openProfileMenu(tester, 'À propos');
    await tester.scrollUntilVisible(
      find.text('Partager nos coordonnées'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Partager nos coordonnées'));
    await tester.pumpAndSettle();

    for (final network in [
      'whatsapp',
      'facebook',
      'instagram',
      'telegram',
      'x',
      'linkedin',
      'email',
    ]) {
      expect(
        find.byKey(ValueKey('share-network-$network')),
        findsOneWidget,
        reason: '$network doit être proposé',
      );
    }
    expect(find.byKey(const ValueKey('share-action-system')), findsOneWidget);

    final facebookRow = find.byKey(const ValueKey('share-network-facebook'));
    await tester.ensureVisible(facebookRow);
    await tester.pumpAndSettle();
    await tester.tap(facebookRow);
    await tester.pumpAndSettle();

    expect(opened.last.host, 'www.facebook.com');
    expect(opened.last.queryParameters['u'], CompanyLocation.mapsUrl);
  });

  testWidgets('le menu À propos ne garde plus Évaluation ni Certifications', (
    tester,
  ) async {
    final api = _fakeProfileApi(
      profile: _profile(),
      savedUpdates: <Map<String, dynamic>>[],
    );
    addTearDown(api.dispose);

    await tester.pumpWidget(MaterialApp(home: ProfilScreen(profileApi: api)));
    await tester.pumpAndSettle();

    await _openProfileMenu(tester, 'À propos');

    for (final removed in ['Évaluation', 'Certifications']) {
      expect(
        find.text(removed),
        findsNothing,
        reason: '$removed est supprimé du menu',
      );
    }
    expect(find.text('Partager nos coordonnées'), findsOneWidget);
  });

  testWidgets('nos partenaires ne garde que Leica et e-survey', (tester) async {
    final api = _fakeProfileApi(
      profile: _profile(),
      savedUpdates: <Map<String, dynamic>>[],
    );
    addTearDown(api.dispose);

    await tester.pumpWidget(MaterialApp(home: ProfilScreen(profileApi: api)));
    await tester.pumpAndSettle();

    await _openProfileMenu(tester, 'À propos');
    await tester.tap(find.text('Nos partenaires'));
    await tester.pumpAndSettle();

    expect(find.text('Leica'), findsOneWidget);
    expect(find.text('e-survey'), findsOneWidget);
    for (final removed in ['Stonex', 'Trimble', 'Sokkia']) {
      expect(
        find.text(removed),
        findsNothing,
        reason: '$removed est supprimé des partenaires',
      );
    }
  });

  testWidgets('« Notre équipe » lit la liste partagée dans team.dart', (
    tester,
  ) async {
    final api = _fakeProfileApi(
      profile: _profile(),
      savedUpdates: <Map<String, dynamic>>[],
    );
    addTearDown(api.dispose);

    await tester.pumpWidget(MaterialApp(home: ProfilScreen(profileApi: api)));
    await tester.pumpAndSettle();

    await _openProfileMenu(tester, 'À propos');
    await tester.tap(find.text('Notre équipe'));
    await tester.pumpAndSettle();

    for (final member in kTeamMembers) {
      expect(
        find.byKey(ValueKey('team-member-${member.firstName}')),
        findsOneWidget,
        reason: '${member.firstName} doit venir de team.dart',
      );
    }
  });

  testWidgets('« Inviter à installer » annonce l’attente de publication', (
    tester,
  ) async {
    final api = _fakeProfileApi(
      profile: _profile(),
      savedUpdates: <Map<String, dynamic>>[],
    );
    addTearDown(api.dispose);

    await tester.pumpWidget(MaterialApp(home: ProfilScreen(profileApi: api)));
    await tester.pumpAndSettle();

    await _openProfileMenu(tester, 'À propos');
    await tester.scrollUntilVisible(
      find.text('Inviter à installer'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Bientôt sur Google Play et l’App Store'), findsOneWidget);

    await tester.tap(find.text('Inviter à installer'));
    await tester.pumpAndSettle();

    expect(find.text('Application bientôt disponible'), findsOneWidget);
    expect(find.textContaining('n’est pas encore publiée'), findsOneWidget);
  });

  testWidgets('« Nous localiser » est la dernière entrée, après le support', (
    tester,
  ) async {
    final api = _fakeProfileApi(
      profile: _profile(),
      savedUpdates: <Map<String, dynamic>>[],
    );
    addTearDown(api.dispose);

    await tester.pumpWidget(MaterialApp(home: ProfilScreen(profileApi: api)));
    await tester.pumpAndSettle();

    final locationItem = find.byKey(
      const ValueKey('profile-menu-Nous localiser'),
    );
    await tester.ensureVisible(locationItem);
    await tester.pumpAndSettle();

    final locationTop = tester.getTopLeft(locationItem).dy;
    for (final above in ['Chat Support', 'Centre d\'aide', 'À propos']) {
      expect(
        locationTop,
        greaterThan(
          tester.getTopLeft(find.byKey(ValueKey('profile-menu-$above'))).dy,
        ),
        reason: '« $above » doit précéder « Nous localiser »',
      );
    }
  });

  testWidgets('la carte affichée d’emblée tient sur un petit écran', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _fakeProfileApi(
      profile: _profile(),
      savedUpdates: <Map<String, dynamic>>[],
    );
    addTearDown(api.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ProfilScreen(
          profileApi: api,
          companyLocationCardBuilder: (_) =>
              const SizedBox(key: ValueKey('inline-company-map'), height: 320),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final locationItem = find.byKey(
      const ValueKey('profile-menu-Nous localiser'),
    );
    await tester.ensureVisible(locationItem);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('company-location-inline')),
      findsOneWidget,
    );
  });
}
