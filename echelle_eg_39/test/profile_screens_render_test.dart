// Vérifie que chaque feuille de détail du Profil se rend sur un écran de
// téléphone étroit, sans débordement ni contenu manquant.

import 'package:echelle_eg_39/company_contact.dart';
import 'package:echelle_eg_39/team.dart';
import 'package:echelle_eg_39/widgets/company_info_screen.dart';
import 'package:echelle_eg_39/widgets/credits_screen.dart';
import 'package:echelle_eg_39/widgets/direct_contact_screen.dart';
import 'package:echelle_eg_39/widgets/faq_screen.dart';
import 'package:echelle_eg_39/widgets/glossary_screen.dart';
import 'package:echelle_eg_39/widgets/partners_screen.dart';
import 'package:echelle_eg_39/widgets/privacy_policy_screen.dart';
import 'package:echelle_eg_39/widgets/services_screen.dart';
import 'package:echelle_eg_39/widgets/team_screen.dart';
import 'package:echelle_eg_39/widgets/terms_of_use_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpPhone(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('FAQ répond à la première question dépliée', (tester) async {
    await _pumpPhone(tester, const FaqScreen());

    expect(tester.takeException(), isNull);
    expect(find.text('Comment calibrer un GPS de précision ?'), findsOneWidget);
    expect(
      find.textContaining('placez-vous en zone dégagée'),
      findsOneWidget,
    );
    expect(find.text('Comment réserver un équipement ?'), findsOneWidget);
  });

  testWidgets('Glossaire cherche et filtre les termes', (tester) async {
    await _pumpPhone(tester, const GlossaryScreen());

    expect(tester.takeException(), isNull);
    expect(find.text('Altimétrie'), findsOneWidget);
    expect(find.text('Station totale'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('glossary-search')),
      'borna',
    );
    await tester.pumpAndSettle();

    expect(find.text('Bornage'), findsOneWidget);
    expect(find.text('Altimétrie'), findsNothing);
  });

  testWidgets('Glossaire annonce l’absence de résultat', (tester) async {
    await _pumpPhone(tester, const GlossaryScreen());

    await tester.enterText(
      find.byKey(const ValueKey('glossary-search')),
      'introuvable',
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucun terme trouvé.'), findsOneWidget);
    expect(find.text('Effacer la recherche'), findsOneWidget);
  });

  testWidgets('Contact direct rend les trois canaux et les horaires', (
    tester,
  ) async {
    await _pumpPhone(tester, DirectContactScreen(launchUri: (_) async => true));

    expect(tester.takeException(), isNull);
    expect(find.text('Téléphone'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text(CompanyContact.email), findsOneWidget);
    expect(find.textContaining('Lundi–vendredi'), findsOneWidget);
  });

  testWidgets('Entreprise garde l’itinéraire dans sa barre d’actions', (
    tester,
  ) async {
    await _pumpPhone(tester, CompanyInfoScreen(launchMaps: (_) async => true));

    expect(tester.takeException(), isNull);
    expect(find.text('Histoire'), findsOneWidget);
    expect(find.text('Zone d’intervention'), findsOneWidget);
    expect(find.text('Itinéraire'), findsOneWidget);
  });

  testWidgets('Équipe affiche les quatre membres partagés', (tester) async {
    await _pumpPhone(tester, const TeamScreen());

    expect(tester.takeException(), isNull);
    for (final member in kTeamMembers) {
      expect(
        find.byKey(ValueKey('team-member-${member.firstName}')),
        findsOneWidget,
      );
    }
  });

  testWidgets('Partenaires, Services, Confidentialité, Conditions, Crédits', (
    tester,
  ) async {
    await _pumpPhone(tester, const PartnersScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('Leica'), findsOneWidget);
    expect(find.text('e-survey'), findsOneWidget);

    await _pumpPhone(tester, const ServicesScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('Vente'), findsOneWidget);
    expect(find.text('Support technique'), findsOneWidget);

    await _pumpPhone(tester, const PrivacyPolicyScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('Données collectées'), findsOneWidget);
    expect(find.text('Vos droits'), findsOneWidget);

    await _pumpPhone(tester, const TermsOfUseScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('Responsabilité'), findsOneWidget);

    await _pumpPhone(tester, const CreditsScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('Flutter'), findsOneWidget);
    expect(find.text('1.0.0 — Mars 2024'), findsOneWidget);
  });
}
