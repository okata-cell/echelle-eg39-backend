import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echelle_eg_39/admin_users_page.dart';
import 'package:echelle_eg_39/models_anonymized_user.dart';

void main() {
  const users = [
    AnonymizedUser(
      id: '12',
      role: 'client',
      maskedEmail: 'j••••••@example.com',
    ),
    AnonymizedUser(id: '13', role: 'admin', maskedEmail: 'a••••@example.com'),
  ];

  test('le modèle ne conserve que les champs anonymisés', () {
    final user = AnonymizedUser.fromJson({
      'id': 12,
      'role': 'client',
      'maskedEmail': 'j••••••@example.com',
      'email': 'jean.dupont@example.com',
      'phone': '+22890000000',
      'password_hash': 'secret',
    });

    expect(user.id, '12');
    expect(user.role, 'client');
    expect(user.maskedEmail, 'j••••••@example.com');
    expect(formatAnonymizedResultCount(1), '1 résultat');
    expect(formatAnonymizedResultCount(2), '2 résultats');
    expect(user.maskedEmail, isNot(contains('jean.dupont')));
  });

  testWidgets('affiche uniquement le répertoire anonymisé et filtre par rôle', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminUsersPage(loadUsers: () async => users)),
      ),
    );
    await tester.pump();

    expect(find.text('Répertoire anonymisé'), findsOneWidget);
    expect(find.text('j••••••@example.com'), findsOneWidget);
    expect(find.text('jean.dupont@example.com'), findsNothing);
    expect(find.text('2 résultats'), findsOneWidget);

    await tester.tap(find.text('admin').first);
    await tester.pump();

    expect(find.text('1 résultat'), findsOneWidget);
    expect(find.text('a••••@example.com'), findsOneWidget);
    expect(find.text('j••••••@example.com'), findsNothing);
  });
}
