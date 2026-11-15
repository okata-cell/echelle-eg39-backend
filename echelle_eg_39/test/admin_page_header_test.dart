// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

// Garde-fou de l'en-tête des pages admin (`AdminPageHeader`).
//
// Constat du 15/11 sur l'iPhone, police au maximum : le titre suivait la
// police système et s'étalait sur cinq lignes (420 px de haut mesurés),
// illisible et lu comme un empilement. Correctif attendu :
//   * titre sur UNE ligne, abrégé par « … » s'il ne rentre pas ;
//   * le titre ne grossit plus au-delà de 140 % ;
//   * au-delà de 160 %, les boutons d'action descendent sous le texte pour
//     rendre au titre toute la largeur utile.
//
// MediaQuery doit rester SOUS MaterialApp, sinon les surcharges de police
// sont ignorées et le test passe sans rien vérifier.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echelle_eg_39/admin/admin_components.dart';

Widget _entete({List<Widget> actions = const <Widget>[]}) {
  return AdminPageHeader(
    title: 'Gestion des clients',
    subtitle: 'Retrouvez les comptes inscrits et leurs coordonnées.',
    icon: Icons.people_alt_outlined,
    actions: actions,
  );
}

Widget _monter({
  required Size taille,
  required double facteurTexte,
  bool avecActions = true,
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) {
        final page = SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _entete(
                actions: avecActions
                    ? [
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.refresh),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.add),
                        ),
                      ]
                    : const <Widget>[],
              ),
            ],
          ),
        );
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(size: taille, textScaler: TextScaler.linear(facteurTexte)),
          child: Scaffold(body: page),
        );
      },
    ),
  );
}

void main() {
  final cas = <({String nom, Size taille, double texte, bool actions})>[
    (
      nom: '430 dp, police 100 %',
      taille: const Size(430, 932),
      texte: 1.0,
      actions: true,
    ),
    (
      nom: '430 dp, police 200 %',
      taille: const Size(430, 932),
      texte: 2.0,
      actions: true,
    ),
    (
      nom: '430 dp, police 310 %',
      taille: const Size(430, 932),
      texte: 3.1,
      actions: true,
    ),
    (
      nom: '320 dp, police 200 %',
      taille: const Size(320, 640),
      texte: 2.0,
      actions: true,
    ),
    (
      nom: '430 dp, police 310 %, sans action',
      taille: const Size(430, 932),
      texte: 3.1,
      actions: false,
    ),
  ];

  for (final c in cas) {
    testWidgets('En-tête admin lisible — ${c.nom}', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = c.taille;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _monter(
          taille: c.taille,
          facteurTexte: c.texte,
          avecActions: c.actions,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: 'Débordement sur ${c.nom}',
      );

      final titre = tester.getRect(find.text('Gestion des clients'));
      final sousTitre = tester.getRect(
        find.text('Retrouvez les comptes inscrits et leurs coordonnées.'),
      );

      // Une seule ligne : à 140 % de 22 px, une ligne mesure ~39 px.
      expect(
        titre.height,
        lessThan(60),
        reason: 'Le titre doit tenir sur une seule ligne (${c.nom})',
      );

      // Le texte ne sort jamais de la page.
      expect(titre.right, lessThanOrEqualTo(c.taille.width - 15));
      expect(sousTitre.right, lessThanOrEqualTo(c.taille.width - 15));

      // Le sous-titre reste sous le titre, sans recouvrement.
      expect(
        sousTitre.top,
        greaterThanOrEqualTo(titre.bottom),
        reason: 'Le sous-titre ne doit pas recouvrir le titre (${c.nom})',
      );

      if (c.actions) {
        final action = tester.getRect(find.byIcon(Icons.refresh));
        if (c.texte >= 1.6) {
          expect(
            action.top,
            greaterThanOrEqualTo(titre.bottom),
            reason:
                'À partir de 160 %, les actions passent sous le titre (${c.nom})',
          );
        } else {
          expect(
            action.left,
            greaterThanOrEqualTo(titre.right),
            reason: 'À taille normale, les actions restent à droite (${c.nom})',
          );
        }
      }
    });
  }
}
