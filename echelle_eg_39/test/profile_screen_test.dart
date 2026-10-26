import 'dart:async';
import 'dart:convert';

import 'package:echelle_eg_39/profile.dart';
import 'package:echelle_eg_39/profile_api.dart';
import 'package:echelle_eg_39/profile_avatar_image.dart';
import 'package:flutter/material.dart';
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
    await tester.enterText(
      find.byKey(const ValueKey('profile-first-name')),
      'Ama',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    expect(savedUpdates.single['firstName'], 'Ama');
    expect(find.text('Ama Koffi'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('token'), 'renewed');
    expect(prefs.getString('userName'), 'Ama Koffi');
  });

  testWidgets('enregistre l’adresse de l’entreprise sans erreur de dialogue', (
    tester,
  ) async {
    final profile = _profile();
    final savedUpdates = <Map<String, dynamic>>[];
    final api = _fakeProfileApi(profile: profile, savedUpdates: savedUpdates);
    addTearDown(api.dispose);

    await tester.pumpWidget(MaterialApp(home: ProfilScreen(profileApi: api)));
    await tester.pumpAndSettle();
    await _openProfileMenu(tester, 'Adresse de l’entreprise');
    await tester.enterText(
      find.byKey(const ValueKey('profile-company-address')),
      '12 rue du Port',
    );
    await tester.enterText(find.byKey(const ValueKey('profile-city')), 'Lomé');
    await tester.enterText(
      find.byKey(const ValueKey('profile-country')),
      'Togo',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    expect(savedUpdates.single['address'], '12 rue du Port');
    expect(find.text('Adresse enregistrée.'), findsOneWidget);
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
      await tester.tap(find.text('Voir sur Google Maps'));
      await tester.pumpAndSettle();

      expect(openedUrls, hasLength(1));
      expect(
        openedUrls.single.toString(),
        'https://maps.app.goo.gl/BtGKf2gwjaLpKFQN7?g_st=iw',
      );
    },
  );

  testWidgets('retire les entrées supprimées et garde l’adresse en dernier', (
    tester,
  ) async {
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
    ]) {
      expect(find.byKey(ValueKey('profile-menu-$removed')), findsNothing);
    }

    final addressItem = find.byKey(
      const ValueKey('profile-menu-Adresse de l’entreprise'),
    );
    final passwordItem = find.byKey(
      const ValueKey('profile-menu-Mot de passe'),
    );
    final supportItem = find.byKey(const ValueKey('profile-menu-Chat Support'));
    expect(addressItem, findsOneWidget);
    expect(
      tester.getTopLeft(addressItem).dy,
      greaterThan(tester.getTopLeft(passwordItem).dy),
    );
    expect(
      tester.getTopLeft(addressItem).dy,
      lessThan(tester.getTopLeft(supportItem).dy),
    );
  });

  testWidgets('« Nous localiser » déplie la carte sous le bouton', (
    tester,
  ) async {
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
          companyLocationCardBuilder: (_) =>
              const SizedBox(key: ValueKey('inline-company-map'), height: 180),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final locationItem = find.byKey(
      const ValueKey('profile-menu-Nous localiser'),
    );
    await tester.ensureVisible(locationItem);
    await tester.pumpAndSettle();
    expect(inlineMap, findsNothing);

    await tester.tap(locationItem);
    await tester.pumpAndSettle();

    // La carte est visible dans le profil, juste sous son bouton.
    expect(inlineMap, findsOneWidget);
    expect(find.text('Afi Koffi'), findsOneWidget);
    expect(
      tester.getTopLeft(inlineMap).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(locationItem).dy - 0.5),
    );

    await tester.tap(locationItem);
    await tester.pumpAndSettle();
    expect(inlineMap, findsNothing);
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

  testWidgets('la carte dépliée tient sur un petit écran sans déborder', (
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
    await tester.tap(locationItem);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('company-location-inline')), findsOneWidget);
  });
}
