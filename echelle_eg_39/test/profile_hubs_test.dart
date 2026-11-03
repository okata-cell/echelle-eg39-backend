import 'package:echelle_eg_39/profile_api.dart';
import 'package:echelle_eg_39/team.dart';
import 'package:echelle_eg_39/widgets/about_hub_screen.dart';
import 'package:echelle_eg_39/widgets/help_center_screen.dart';
import 'package:echelle_eg_39/widgets/personal_info_screen.dart';
import 'package:echelle_eg_39/widgets/team_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ProfileRecord _record({
  String city = 'Lomé',
  String country = 'Togo',
  String company = 'ÉCHELLE EG39',
  String address = '55PH+CR6 Lomé, Togo',
}) => ProfileRecord(
  id: 7,
  firstName: 'Silva',
  lastName: 'Okata',
  email: 'silvaokata@gmail.com',
  phone: '+22890000000',
  company: company,
  address: address,
  city: city,
  country: country,
  role: 'client',
);

/// Ouvre une feuille depuis un écran d’accueil : le retour a une pile réelle.
Future<void> _pushSheet(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const ValueKey('open-sheet'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => screen),
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-sheet')));
  await tester.pumpAndSettle();
}

void main() {
  group('Sommaire À propos', () {
    testWidgets('quatre tuiles d’entreprise, trois documents, actions à part', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: AboutHubScreen()));
      await tester.pumpAndSettle();

      for (final tile in [
        'about-tile-company',
        'about-tile-services',
        'about-tile-team',
        'about-tile-partners',
      ]) {
        expect(find.byKey(ValueKey(tile)), findsOneWidget, reason: tile);
      }

      // Les sept destinations documentaires restent accessibles.
      for (final destination in [
        "Informations sur l'entreprise",
        'Nos services',
        'Notre équipe',
        'Nos partenaires',
        'Politique de confidentialité',
        'Conditions d’utilisation',
        'Crédits',
      ]) {
        expect(find.text(destination), findsOneWidget, reason: destination);
      }

      expect(find.text('Actions'), findsOneWidget);
      expect(find.byKey(const ValueKey('about-action-invite')), findsOneWidget);
      expect(find.byKey(const ValueKey('about-action-share')), findsOneWidget);
      expect(find.text('Bientôt sur Google Play et l’App Store'), findsOneWidget);
    });

    testWidgets('les tuiles forment une grille de deux colonnes', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: AboutHubScreen()));
      await tester.pumpAndSettle();

      final company = tester.getTopLeft(
        find.byKey(const ValueKey('about-tile-company')),
      );
      final services = tester.getTopLeft(
        find.byKey(const ValueKey('about-tile-services')),
      );
      final team = tester.getTopLeft(
        find.byKey(const ValueKey('about-tile-team')),
      );

      expect(services.dy, company.dy);
      expect(services.dx, greaterThan(company.dx));
      expect(team.dy, greaterThan(company.dy));
      expect(team.dx, company.dx);
    });

    testWidgets('une tuile ouvre sa feuille et le retour ramène au sommaire', (
      tester,
    ) async {
      await _pushSheet(tester, const AboutHubScreen());

      await tester.tap(find.byKey(const ValueKey('about-tile-team')));
      await tester.pumpAndSettle();
      expect(find.byType(TeamScreen), findsOneWidget);
      expect(
        find.byKey(ValueKey('team-member-${kTeamMembers.first.firstName}')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('profile-sheet-back')));
      await tester.pumpAndSettle();
      expect(find.byType(AboutHubScreen), findsOneWidget);
    });
  });

  group('Sommaire Centre d’aide', () {
    testWidgets('deux tuiles documentaires puis la carte contact', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: HelpCenterScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('help-tile-faq')), findsOneWidget);
      expect(find.byKey(const ValueKey('help-tile-glossary')), findsOneWidget);
      expect(find.byKey(const ValueKey('help-contact-card')), findsOneWidget);
      expect(find.text('FAQ dynamique'), findsOneWidget);
      expect(find.text('Glossaire'), findsOneWidget);
      expect(find.text('Contact direct'), findsOneWidget);
      expect(find.text('+228 90 01 43 29'), findsOneWidget);
      expect(find.text('admin@echelle-eg39.com'), findsOneWidget);

      // Les tuiles sont côte à côte, la carte contact occupe la ligne suivante.
      final faq = tester.getTopLeft(
        find.byKey(const ValueKey('help-tile-faq')),
      );
      final glossary = tester.getTopLeft(
        find.byKey(const ValueKey('help-tile-glossary')),
      );
      final contact = tester.getTopLeft(
        find.byKey(const ValueKey('help-contact-card')),
      );
      expect(glossary.dy, faq.dy);
      expect(glossary.dx, greaterThan(faq.dx));
      expect(contact.dy, greaterThan(faq.dy));
    });

    testWidgets('une tuile ouvre la FAQ', (tester) async {
      await _pushSheet(tester, const HelpCenterScreen());

      await tester.tap(find.byKey(const ValueKey('help-tile-faq')));
      await tester.pumpAndSettle();
      expect(
        find.text('Comment calibrer un GPS de précision ?'),
        findsOneWidget,
      );
    });
  });

  group('Informations personnelles', () {
    testWidgets('les champs ville et pays sont proposés en coordonnées', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PersonalInfoScreen(
            profile: _record(),
            onSubmit: (_) async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final field in ['Ville', 'Pays', 'Entreprise', 'Adresse']) {
        expect(find.text(field), findsOneWidget, reason: field);
      }
      expect(find.text('Facultatif'), findsNWidgets(4));
      expect(find.byKey(const ValueKey('profile-city')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-country')), findsOneWidget);
      expect(find.text('Lomé'), findsOneWidget);
      expect(find.text('Togo'), findsOneWidget);
    });

    testWidgets('changer d’onglet ne perd pas la saisie en cours', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PersonalInfoScreen(
            profile: _record(),
            onSubmit: (_) async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('profile-city')),
        'Kara',
      );
      await tester.tap(find.text('Identité'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coordonnées'));
      await tester.pumpAndSettle();

      expect(find.text('Kara'), findsOneWidget);
    });

    testWidgets('enregistrer envoie les quatre champs facultatifs', (
      tester,
    ) async {
      PersonalInfoDraft? sent;
      await _pushSheet(
        tester,
        PersonalInfoScreen(
          profile: _record(company: '', address: '', city: '', country: ''),
          onSubmit: (draft) async {
            sent = draft;
            return true;
          },
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('profile-city')),
        'Atakpamé',
      );
      await tester.enterText(
        find.byKey(const ValueKey('profile-country')),
        'Togo',
      );
      await tester.enterText(
        find.byKey(const ValueKey('profile-company')),
        'Cabinet Géo',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
      await tester.pumpAndSettle();

      expect(sent, isNotNull);
      expect(sent!.city, 'Atakpamé');
      expect(sent!.country, 'Togo');
      expect(sent!.company, 'Cabinet Géo');
      expect(sent!.firstName, 'Silva');
      expect(find.byType(PersonalInfoScreen), findsNothing);
    });

    testWidgets('un profil sans ville ni pays reste enregistrable', (
      tester,
    ) async {
      var submitted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: PersonalInfoScreen(
            profile: _record(city: '', country: ''),
            onSubmit: (_) async {
              submitted = true;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
      await tester.pumpAndSettle();

      expect(submitted, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('un prénom vide renvoie sur l’onglet identité', (tester) async {
      var submitted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: PersonalInfoScreen(
            profile: _record(),
            onSubmit: (_) async {
              submitted = true;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Identité'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('profile-first-name')),
        '',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
      await tester.pumpAndSettle();

      expect(submitted, isFalse);
      expect(find.text('Saisissez votre prénom.'), findsOneWidget);
    });

    testWidgets('changer l’e-mail exige le mot de passe actuel', (
      tester,
    ) async {
      var submitted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: PersonalInfoScreen(
            profile: _record(),
            onSubmit: (_) async {
              submitted = true;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('E-mail'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('profile-email')),
        'nouvelle@echelle-eg39.com',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
      await tester.pumpAndSettle();

      expect(submitted, isFalse);
      expect(
        find.text('Saisissez votre mot de passe actuel pour changer l’e-mail.'),
        findsOneWidget,
      );
    });
  });
}
