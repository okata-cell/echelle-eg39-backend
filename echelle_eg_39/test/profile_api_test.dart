import 'dart:convert';
import 'dart:typed_data';

import 'package:echelle_eg_39/profile_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingClient extends http.BaseClient {
  _RecordingClient(this.responses);

  final List<http.Response> responses;
  final List<http.Request> requests = [];
  final List<String> requestBodies = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = utf8.decode(await request.finalize().toBytes());
    requests.add(request as http.Request);
    requestBodies.add(body);
    final response = responses.removeAt(0);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }
}

Map<String, dynamic> _profile({String firstName = 'Afi'}) => {
  'id': 42,
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

http.Response _json(int status, Map<String, dynamic> body) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'token': 'session-token'});
  });

  test('GET /profile/me utilise le token de session et mappe le profil', () async {
    final client = _RecordingClient([
      _json(200, {'profile': _profile()}),
    ]);
    final api = ProfileApi(client: client, baseUrl: 'https://api.test/api');
    addTearDown(api.dispose);

    final profile = await api.loadProfile();

    expect(profile.fullName, 'Afi Koffi');
    expect(client.requests.single.method, 'GET');
    expect(client.requests.single.url.path, '/api/profile/me');
    expect(client.requests.single.headers['authorization'], 'Bearer session-token');
  });

  test('PATCH /profile/me envoie les champs et conserve le jeton renouvelé', () async {
    final client = _RecordingClient([
      _json(200, {'profile': _profile(firstName: 'Ama'), 'token': 'renewed-token'}),
    ]);
    final api = ProfileApi(client: client, baseUrl: 'https://api.test/api');
    addTearDown(api.dispose);

    final profile = await api.updateProfile(
      firstName: ' Ama ',
      lastName: 'Koffi',
      email: 'afi@example.com',
      phone: '+22890000000',
      company: 'EG39',
      address: 'Aflao Gagli',
      city: 'Lomé',
      country: 'Togo',
    );

    expect(profile.firstName, 'Ama');
    expect(client.requests.single.method, 'PATCH');
    expect(jsonDecode(client.requestBodies.single)['firstName'], 'Ama');
    expect(
      await SharedPreferences.getInstance().then((prefs) => prefs.getString('token')),
      'renewed-token',
    );
  });

  test('PUT /profile/me/avatar transmet une image imbriquée en base64', () async {
    final client = _RecordingClient([
      _json(200, {'profile': {..._profile(), 'avatarData': 'iVBORw==', 'avatarMimeType': 'image/png'}}),
    ]);
    final api = ProfileApi(client: client, baseUrl: 'https://api.test/api');
    addTearDown(api.dispose);

    await api.updateAvatar(
      bytes: Uint8List.fromList([1, 2, 3]),
      mimeType: 'image/png',
    );

    final payload = jsonDecode(client.requestBodies.single) as Map<String, dynamic>;
    expect(client.requests.single.method, 'PUT');
    expect(payload['image'], {'mimeType': 'image/png', 'data': 'AQID'});
  });

  test('les pièces jointes dépassant les limites sont rejetées sans requête', () async {
    final client = _RecordingClient([]);
    final api = ProfileApi(client: client, baseUrl: 'https://api.test/api');
    addTearDown(api.dispose);

    await expectLater(
      api.submitSupportMessage(
        message: 'Incident',
        attachments: List.generate(
          ProfileApi.maxSupportAttachmentCount + 1,
          (_) => ProfileImageAttachment(
            bytes: Uint8List.fromList([1]),
            mimeType: 'image/png',
          ),
        ),
      ),
      throwsA(isA<ProfileApiException>()),
    );
    expect(client.requests, isEmpty);
  });

  test('une réponse serveur invalide n’est pas traitée comme succès', () async {
    final client = _RecordingClient([http.Response('not-json', 200)]);
    final api = ProfileApi(client: client, baseUrl: 'https://api.test/api');
    addTearDown(api.dispose);

    await expectLater(
      api.loadProfile(),
      throwsA(isA<ProfileApiException>()),
    );
  });
}
