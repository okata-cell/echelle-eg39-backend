// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

// Garde-fou de la coquille admin. Deux défauts corrigés sont verrouillés ici :
//   * Android, taille d'affichage au maximum (~320 dp) : la barre du haut
//     débordait de 17 px vers le bas, car sa hauteur était figée à 74 px alors
//     qu'elle doit contenir l'encoche du système en plus de son contenu.
//   * iPhone, taille de texte au maximum : le titre « ÉCHELLE EG39 / ADMIN »
//     se repliait et venait se superposer au nom du module.
//
// ATTENTION : le MediaQuery doit être posé SOUS MaterialApp. Placé au-dessus,
// il est remplacé par celui de la vue et les surcharges d'encoche et de police
// sont silencieusement perdues — le test passerait sans rien vérifier.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echelle_eg_39/admin/admin_activity_service.dart';
import 'package:echelle_eg_39/admin/admin_shell.dart';

/// Le nom du module apparaît deux fois dans l'écran : dans la barre du haut
/// (titre, 16 px) et dans l'onglet du bas (10 px). Seul le premier compte ici.
Finder _moduleDansLaBarre(String label) => find.byWidgetPredicate(
  (Widget w) => w is Text && w.data == label && (w.style?.fontSize ?? 0) > 12,
  description: 'nom du module dans la barre du haut',
);

/// Coquille montée avec des pages factices : ce sont les barres, pas les
/// écrans, qui sont sous surveillance.
Widget _coquille() {
  return AdminShell(
    currentIndex: 0,
    pages: List<Widget>.generate(7, (int i) => Center(child: Text('Page $i'))),
    onIndexChanged: (_) {},
    onLogout: () {},
    activity: AdminActivityService(),
  );
}

Widget _monter({required Size taille, required double facteurTexte}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: taille,
          // Encoche simulée : Android ~24-33 dp, iPhone ~59 dp. On prend le pire.
          padding: const EdgeInsets.only(top: 59),
          textScaler: TextScaler.linear(facteurTexte),
        ),
        child: _coquille(),
      ),
    ),
  );
}

void main() {
  final cas = <({String nom, Size taille, double texte})>[
    (
      nom: 'Android 320 dp, police 100 %',
      taille: const Size(320, 640),
      texte: 1.0,
    ),
    (
      nom: 'Android 320 dp, police 200 %',
      taille: const Size(320, 640),
      texte: 2.0,
    ),
    (
      nom: 'iPhone 430 dp, police 135 %',
      taille: const Size(430, 932),
      texte: 1.35,
    ),
    (
      nom: 'Android 360 dp, police 130 %',
      taille: const Size(360, 780),
      texte: 1.3,
    ),
  ];

  for (final c in cas) {
    testWidgets('Coquille admin sans débordement — ${c.nom}', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = c.taille;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_monter(taille: c.taille, facteurTexte: c.texte));
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: 'Un RenderFlex a débordé sur ${c.nom}',
      );

      // La marque, le séparateur et le rôle sont trois textes distincts : une
      // seule chaîne repliable ne peut plus produire la superposition.
      final marque = tester.getRect(find.text('ÉCHELLE EG39'));
      final separateur = tester.getRect(find.text('/'));
      final role = tester.getRect(find.text('ADMIN'));
      final module = tester.getRect(_moduleDansLaBarre('Clients'));

      expect(
        separateur.left,
        greaterThanOrEqualTo(marque.right),
        reason: 'Le séparateur doit suivre la marque sur la même ligne',
      );
      expect(
        role.left,
        greaterThanOrEqualTo(separateur.right),
        reason: '« ADMIN » doit rester après le séparateur',
      );

      // Symptôme iPhone : le nom du module recouvrait le titre.
      expect(
        module.top,
        greaterThanOrEqualTo(marque.bottom),
        reason: 'Le nom du module ne doit pas recouvrir le titre',
      );

      // La barre reste sous l'encoche : rien ne se dessine dans la zone système.
      expect(
        marque.top,
        greaterThanOrEqualTo(59),
        reason: 'Le titre doit commencer sous l’encoche',
      );

      // ── La page et les onglets doivent rester visibles ────────────────────
      // Régression du 15/11 : une barre d'onglets sans hauteur maximale a pris
      // tout l'écran, poussant le corps (donc le titre et la page) à zéro.
      final page = tester.getRect(find.text('Page 0'));
      expect(
        page.center.dy,
        greaterThan(marque.bottom),
        reason: 'La page doit s’afficher sous la barre du haut',
      );
      expect(
        page.center.dy,
        lessThan(c.taille.height - 100),
        reason: 'La page ne doit pas être poussée hors de l’écran',
      );

      final onglet = tester.getRect(
        find.byWidgetPredicate(
          (Widget w) =>
              w is Text && w.data == 'Clients' && (w.style?.fontSize ?? 0) <= 12,
          description: 'libellé de l’onglet Clients',
        ),
      );
      expect(
        onglet.center.dy,
        greaterThan(c.taille.height - 120),
        reason: 'Les onglets doivent rester collés en bas de l’écran',
      );
    });
  }
}
