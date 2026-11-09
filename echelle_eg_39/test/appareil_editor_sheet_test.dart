import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'package:echelle_eg_39/admin/appareil_editor_sheet.dart';
import 'package:echelle_eg_39/data_manager.dart';

void main() {
  Future<void> openSheet(WidgetTester tester, AppareilEditorSheet sheet) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: sheet)));
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String key, String value) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.enterText(finder, value);
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Petite image réellement décodable, gardée en mémoire : dans l'environnement
  /// de test, une lecture disque réelle ne se résout jamais.
  XFile photoFile() {
    final bytes = img.encodePng(img.Image(width: 4, height: 4));
    return XFile.fromData(
      Uint8List.fromList(bytes),
      name: 'station.png',
      mimeType: 'image/png',
    );
  }

  testWidgets('prépare un appareil avec les champs attendus par l’API', (
    tester,
  ) async {
    AppareilDraft? submitted;

    await openSheet(
      tester,
      AppareilEditorSheet(onSubmit: (draft) async => submitted = draft),
    );

    expect(find.text('Nouvel appareil'), findsOneWidget);
    expect(find.text('Sur le catalogue'), findsOneWidget);

    await enter(tester, 'appareil-editor-nom', 'Station totale Leica TS06');
    await enter(tester, 'appareil-editor-type', 'Station totale');
    await enter(tester, 'appareil-editor-prix-location', '25000');
    await enter(tester, 'appareil-editor-prix-vente', '2500000');

    // L'aperçu reprend le nom, le type et les tarifs saisis.
    expect(find.text('Station totale Leica TS06'), findsWidgets);
    expect(find.text('25\u202F000 FCFA / j'), findsOneWidget);

    await tapKey(tester, 'appareil-editor-submit');

    expect(submitted, isNotNull);
    expect(submitted!.nom, 'Station totale Leica TS06');
    expect(submitted!.type, 'Station totale');
    expect(submitted!.prixLocation, 25000);
    expect(submitted!.prixVente, 2500000);
    // Sans photo, l'URL reste nulle : le visuel du type s'applique.
    expect(submitted!.imageUrl, isNull);
  });

  testWidgets('garde les règles de saisie des prix du formulaire précédent', (
    tester,
  ) async {
    var submitted = 0;

    await openSheet(
      tester,
      AppareilEditorSheet(onSubmit: (draft) async => submitted++),
    );

    await enter(tester, 'appareil-editor-nom', 'GPS e-survey E600');
    await enter(tester, 'appareil-editor-type', 'GPS');
    await enter(tester, 'appareil-editor-prix-location', 'abc');
    await tapKey(tester, 'appareil-editor-submit');

    expect(submitted, 0);
    expect(
      find.text('Le prix de location doit contenir uniquement des chiffres'),
      findsOneWidget,
    );
    expect(find.text('Le prix de vente est requis'), findsOneWidget);

    await enter(tester, 'appareil-editor-prix-location', '0');
    await enter(tester, 'appareil-editor-prix-vente', '1200000');
    await tapKey(tester, 'appareil-editor-submit');

    expect(submitted, 0);
    expect(
      find.text('Le prix de location doit être supérieur à 0'),
      findsOneWidget,
    );
  });

  testWidgets('la photo vient de l’appareil photo ou de la galerie', (
    tester,
  ) async {
    AppareilDraft? submitted;
    final sources = <ImageSource>[];
    final uploads = <String>[];

    await openSheet(
      tester,
      AppareilEditorSheet(
        onSubmit: (draft) async => submitted = draft,
        pickImage: (source) async {
          sources.add(source);
          return photoFile();
        },
        uploadImage: (image) async {
          uploads.add(image.name);
          return 'https://res.cloudinary.com/eg39/appareils/station.png';
        },
      ),
    );

    // Les deux choix sont proposés, comme dans la feuille des actualités.
    expect(
      find.byKey(const ValueKey('appareil-editor-photo-camera')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('appareil-editor-photo-galerie')),
      findsOneWidget,
    );

    await tapKey(tester, 'appareil-editor-photo-galerie');
    expect(sources.single, ImageSource.gallery);
    expect(uploads, hasLength(1));

    await tapKey(tester, 'appareil-editor-photo-camera');
    expect(sources.last, ImageSource.camera);
    expect(uploads, hasLength(2));

    await enter(tester, 'appareil-editor-nom', 'Niveau automatique NA720');
    await enter(tester, 'appareil-editor-type', 'Niveau');
    await enter(tester, 'appareil-editor-prix-location', '15000');
    await enter(tester, 'appareil-editor-prix-vente', '900000');
    await tapKey(tester, 'appareil-editor-submit');

    // L'URL téléversée part dans le champ `imageUrl`, comme avant.
    expect(
      submitted!.imageUrl,
      'https://res.cloudinary.com/eg39/appareils/station.png',
    );
  });

  testWidgets('préremplit un appareil existant pour la modification', (
    tester,
  ) async {
    AppareilDraft? submitted;
    final appareil = Appareil(
      id: 'APP-1791080812757',
      dbId: 2650,
      nom: 'Batterie Station Total Leica',
      type: 'Batterie',
      imageUrl: 'https://example.com/batterie.jpg',
      prixLocation: 10000,
      prixVente: 40000,
    );

    await openSheet(
      tester,
      AppareilEditorSheet(
        initial: appareil,
        onSubmit: (draft) async => submitted = draft,
      ),
    );

    expect(find.text('Modifier l’appareil'), findsOneWidget);
    expect(find.text('APP-1791080812757'), findsWidgets);
    expect(find.text('Batterie Station Total Leica'), findsWidgets);

    await tapKey(tester, 'appareil-editor-submit');

    expect(submitted!.nom, 'Batterie Station Total Leica');
    expect(submitted!.type, 'Batterie');
    expect(submitted!.prixLocation, 10000);
    expect(submitted!.prixVente, 40000);
    // La photo en place est conservée si rien n'est changé.
    expect(submitted!.imageUrl, 'https://example.com/batterie.jpg');
  });
}
