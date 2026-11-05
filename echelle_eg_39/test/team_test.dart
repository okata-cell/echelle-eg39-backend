import 'package:echelle_eg_39/team.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('l’équipe expose les membres avec leur initiale et leur fonction', () {
    expect(kTeamMembers, hasLength(7));
    expect(kTeamMembers.first.firstName, 'BADJO Gregoire');
    expect(kTeamMembers.first.initial, 'B');
    expect(kTeamMembers.first.role, 'Directeur Général');
    // Le libellé affiché est exactement « fonction » puis « spécialité » :
    // la casse du texte est libre, la structure ne l’est pas.
    expect(
      kTeamMembers.first.subtitle,
      '${kTeamMembers.first.role}\n${kTeamMembers.first.specialty}',
    );
    expect(kTeamMembers.first.specialty.toLowerCase(), contains('topographie'));
    expect(kTeamMembers.map((member) => member.firstName), [
      'BADJO Gregoire',
      'Valentin Koko',
      'Marcel',
      'Maurice',
      'Moufid',
      'Martial',
      'David',
    ]);
  });

  test('chaque membre a une initiale et une fonction renseignées', () {
    for (final member in kTeamMembers) {
      expect(member.firstName.trim(), member.firstName);
      expect(member.initial, hasLength(1));
      expect(member.role, isNotEmpty);
      expect(member.specialty, isNotEmpty);
      expect(member.subtitle, contains('\n'));
    }
  });

  testWidgets('l’écran Notre équipe rend la liste partagée', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              for (final member in kTeamMembers)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: member.color,
                    child: Text(member.initial),
                  ),
                  title: Text(member.firstName),
                  subtitle: Text(member.subtitle),
                ),
            ],
          ),
        ),
      ),
    );

    for (final member in kTeamMembers) {
      expect(find.text(member.firstName), findsOneWidget);
    }
  });
}
