import 'dart:convert';

import 'package:echelle_eg_39/profile.dart';
import 'package:echelle_eg_39/profile_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _profile({String firstName = 'Afi'}) => {
  'id': 7,
  'firstName': firstName,
  'lastName': 'Koffi',
  'email': 'afi@example.com',
  'phone': '+22890000000',
  'company': 'EG39',
  'address': 'Aflao Gagli',
  'city': 'Lomé',
  'country': 'Togo',
  'role': 'client',
};

http.Response _json(Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('charge le profil et enregistre les modifications via API', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'token': 'client-token'});
    Map<String, dynamic>? savedPayload;
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path.endsWith('/profile/me')) {
        return _json({'profile': _profile()});
      }
      if (request.method == 'PATCH' && request.url.path.endsWith('/profile/me')) {
        savedPayload = jsonDecode(request.body) as Map<String, dynamic>;
        return _json({'profile': _profile(firstName: 'Ama'), 'token': 'renewed'});
      }
      return http.Response('{}', 404);
    });
    final api = ProfileApi(client: client, baseUrl: 'https://api.test/api');
    addTearDown(api.dispose);

    await tester.pumpWidget(MaterialApp(home: ProfilScreen(profileApi: api)));
    await tester.pumpAndSettle();
    expect(find.text('Afi Koffi'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-menu-Informations personnelles')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('profile-first-name')), 'Ama');
    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    expect(savedPayload?['firstName'], 'Ama');
    expect(find.text('Ama Koffi'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('token'), 'renewed');
    expect(prefs.getString('userName'), 'Ama Koffi');
  });
}
