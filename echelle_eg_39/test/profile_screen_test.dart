import 'dart:convert';

import 'package:echelle_eg_39/profile.dart';
import 'package:echelle_eg_39/profile_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
    await tester.enterText(find.byKey(const ValueKey('profile-first-name')), 'Ama');
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
    await tester.enterText(find.byKey(const ValueKey('profile-country')), 'Togo');
    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    expect(savedUpdates.single['address'], '12 rue du Port');
    expect(find.text('Adresse enregistrée.'), findsOneWidget);
  });

  testWidgets('enregistre le nom de l’entreprise sans erreur de dialogue', (
    tester,
  ) async {
    final profile = _profile();
    final savedUpdates = <Map<String, dynamic>>[];
    final api = _fakeProfileApi(profile: profile, savedUpdates: savedUpdates);
    addTearDown(api.dispose);

    await tester.pumpWidget(MaterialApp(home: ProfilScreen(profileApi: api)));
    await tester.pumpAndSettle();
    await _openProfileMenu(tester, 'Entreprise');
    await tester.enterText(find.byKey(const ValueKey('profile-company')), 'Topo EG39');
    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    expect(savedUpdates.single['company'], 'Topo EG39');
    expect(find.text('Entreprise enregistrée.'), findsOneWidget);
  });
}
