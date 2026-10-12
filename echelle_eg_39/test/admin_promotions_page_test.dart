import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:echelle_eg_39/admin_promotions.page.dart';

void main() {
  testWidgets('formulaire sans titre envoie le titre fixe et garde les options', (
    tester,
  ) async {
    final submitted = <Map<String, dynamic>>[];
    final image = XFile.fromData(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j2ioAAAAASUVORK5CYII=',
      ),
      name: 'offre.png',
      mimeType: 'image/png',
    );
    final pickedSources = <ImageSource>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminPromotionsPage(
            loadPromotions: () async => [],
            pickImage: (source) async {
              pickedSources.add(source);
              return image;
            },
            uploadImage: (file) async => {
              'imageUrl': 'https://storage.example.com/offre.png',
              'storagePath': 'promotions/offre.png',
            },
            createPromotion: (data) async {
              submitted.add(data);
              return {
                'promotion': {'id': 4},
              };
            },
            deletePromotionImage: (path) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Créer une promotion'));
    await tester.pumpAndSettle();

    expect(find.text('Titre'), findsNothing);
    expect(find.text('OFFRE DU MOMENT'), findsOneWidget);
    expect(find.text('Afficher automatiquement'), findsOneWidget);
    expect(find.text('À chaque ouverture'), findsOneWidget);
    expect(find.text('Une fois par jour'), findsOneWidget);
    expect(find.text('Une seule fois'), findsOneWidget);
    final dailyOption = find.widgetWithText(
      RadioListTile<String>,
      'Une fois par jour',
    );
    await tester.ensureVisible(dailyOption);
    await tester.tap(dailyOption);
    final automaticSwitch = find.widgetWithText(
      SwitchListTile,
      'Afficher automatiquement',
    );
    await tester.ensureVisible(automaticSwitch);
    await tester.tap(automaticSwitch);
    await tester.pumpAndSettle();

    final addPhotoButton = find.widgetWithText(
      OutlinedButton,
      'Ajouter une photo',
    );
    await tester.ensureVisible(addPhotoButton);
    await tester.tap(addPhotoButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prendre une photo'));
    await tester.pumpAndSettle();
    expect(pickedSources, [ImageSource.camera]);
    expect(find.text('Remplacer'), findsOneWidget);

    await tester.tap(find.text('Remplacer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choisir dans la galerie'));
    await tester.pumpAndSettle();
    expect(pickedSources, [ImageSource.camera, ImageSource.gallery]);

    await tester.enterText(
      find.byType(TextField),
      'Remise spéciale sur les GPS de précision.',
    );
    await tester.tap(find.text('Début de l’offre'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fin de l’offre'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer la promotion'));
    await tester.pumpAndSettle();

    expect(submitted, hasLength(1));
    expect(submitted.single['titre'], 'Offre du moment');
    expect(submitted.single['frequence'], 'une_fois_par_jour');
    expect(submitted.single['actif'], isFalse);
    expect(submitted.single['image_storage_path'], 'promotions/offre.png');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
