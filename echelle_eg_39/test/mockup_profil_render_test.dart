// Outil de maquette : rend l'écran Profil et enregistre des captures PNG.
//
// Le moteur de test ne charge aucune police : les glyphes sortent d'abord en
// rectangles. On charge donc Poppins depuis assets/fonts sous le nom exact
// que GoogleFonts réclame (« Poppins-SemiBold », etc.).
//
// Lancer : flutter test test/mockup_profil_render_test.dart
// Sortie  : mockups/option_b_profil_01.png … 04.png

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echelle_eg_39/profile.dart';
import 'package:echelle_eg_39/profile_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _deviceWidth = 390.0;
const _deviceHeight = 844.0;

Map<String, dynamic> _demoProfile() => {
  'id': 7,
  'firstName': 'Maurice',
  'lastName': 'Adjonou',
  'email': 'maurice.adjonou@echelle-eg39.com',
  'phone': '+228 90 01 43 29',
  'company': 'EG39',
  'address': 'Aflao Gagli',
  'city': 'Lomé',
  'country': 'Togo',
  'role': 'client',
};

ProfileApi _demoApi() {
  final profile = _demoProfile();
  final client = MockClient((request) async {
    if (request.method == 'GET' && request.url.path.endsWith('/profile/me')) {
      return http.Response(
        jsonEncode({'profile': profile}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('{}', 404);
  });
  return ProfileApi(client: client, baseUrl: 'https://api.test/api');
}

/// Charge chaque graisse sous le nom de famille attendu par GoogleFonts.
Future<void> _loadFonts() async {
  for (final weight in [
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
    'ExtraBold',
  ]) {
    final bytes = await File(
      'assets/fonts/Poppins-$weight.ttf',
    ).readAsBytes();
    final loader = FontLoader('Poppins-$weight')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
  // Les icônes Material viennent du SDK : sans elles, chaque icône sort en
  // carré plein dans la capture.
  final iconFile = File('/tmp/icons.ttf');
  if (iconFile.existsSync()) {
    final bytes = await iconFile.readAsBytes();
    final icons = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await icons.load();
  }
  GoogleFonts.config.allowRuntimeFetching = false;
}

Future<void> _capture(GlobalKey key, String path) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('rendu de la maquette du profil (option B)', (tester) async {
    await tester.runAsync(_loadFonts);
    SharedPreferences.setMockInitialValues({'token': 'demo-token'});

    tester.view.physicalSize = const Size(_deviceWidth, _deviceHeight) * 2.0;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final api = _demoApi();
    addTearDown(api.dispose);
    final captureKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: captureKey,
          child: ProfilScreen(
            profileApi: api,
            // La carte OpenStreetMap dépend du plugin path_provider, absent en
            // test : un bloc neutre la remplace le temps de la capture.
            companyLocationCardBuilder: (_) => Container(
              height: 210,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8EEF7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text(
                  'Carte de l’agence',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Le profil arrive par le MockClient : plusieurs frames avant le rendu
    // final, puis une frame hors du temps simulé pour rasteriser les glyphes.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    Directory('mockups').createSync(recursive: true);
    final position = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(SingleChildScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;

    // Quatre vues successives de la page, du haut vers le bas.
    const labels = ['01', '02', '03', '04'];
    for (var i = 0; i < labels.length; i++) {
      position.jumpTo(position.maxScrollExtent / (labels.length - 1) * i);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      await tester.runAsync(
        () => _capture(captureKey, 'mockups/option_b_profil_${labels[i]}.png'),
      );
    }

    expect(find.text('Maurice Adjonou'), findsOneWidget);
  });
}