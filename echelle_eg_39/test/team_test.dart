import 'package:echelle_eg_39/team.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('l’équipe expose les membres avec leur initiale et leur fonction', () {
    expect(kTeamMembers, hasLength(5));
    expect(kTeamMembers.first.firstName, 'Maurice');
    expect(kTeamMembers.first.initial, 'M');
    expect(
      kTeamMembers.first.subtitle,
      'Directeur Général\nExpert en topographie',
    );
    expect(
      kTeamMembers.map((member) => member.firstName),
      containsAll(['Maurice', 'Akossiwa', 'Koffi', 'Yao', 'Abigail']),
    );
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
