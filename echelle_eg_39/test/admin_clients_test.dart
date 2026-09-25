import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echelle_eg_39/admin.client.page.dart';
import 'package:echelle_eg_39/models_admin_client.dart';

void main() {
  const serverClient = AdminClient(
    id: '42',
    firstName: 'Afi',
    lastName: 'Koffi',
    email: 'afi@example.com',
    phone: '+22890000000',
    role: 'client',
    createdAt: '2026-09-25T10:00:00.000Z',
  );
  const localClient = AdminClient(
    id: 'local',
    firstName: 'Kodjo',
    lastName: 'Mensah',
    email: 'kodjo@example.com',
    phone: '+22891111111',
    role: 'client',
    isLocalRegistration: true,
  );

  test('les inscriptions locales ne conservent pas le mot de passe', () {
    final client = AdminClient.tryParseLocalRegistration(
      'afi@example.com|+22890000000|secret|user|Afi|Koffi',
    );

    expect(client, isNotNull);
    expect(client!.role, 'client');
    expect(client.fullName, 'Afi Koffi');
    expect(client.isLocalRegistration, isTrue);
    expect(client.toString(), isNot(contains('secret')));
    expect(
      AdminClient.tryParseLocalRegistration(
        'admin@example.com|+22890000001|secret|admin|Admin|EG39',
      ),
      isNull,
    );
  });

  test('la fusion préfère la base et dédoublonne par e-mail ou téléphone', () {
    final merged = mergeAdminClients(
      serverClients: const [serverClient],
      localClients: [
        localClient,
        const AdminClient(
          id: 'local',
          firstName: 'Afi',
          lastName: 'Koffi',
          email: 'AFI@example.com',
          phone: '+228 90000000',
          role: 'client',
          isLocalRegistration: true,
        ),
      ],
    );

    expect(merged, hasLength(2));
    expect(merged.first.isLocalRegistration, isFalse);
  });

  testWidgets('affiche les clients du serveur et les inscriptions locales', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminClientsPage(
            loadClients: () async => const [serverClient],
            loadLocalClients: () async => const [localClient],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gestion des clients'), findsOneWidget);
    expect(find.text('Afi Koffi'), findsOneWidget);
    expect(find.text('Kodjo Mensah'), findsOneWidget);
    expect(find.text('À synchroniser'), findsOneWidget);
    expect(find.text('2 clients'), findsOneWidget);
  });
}
