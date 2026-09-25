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
    expect(find.byTooltip('Actions pour Afi Koffi'), findsOneWidget);
    expect(find.byTooltip('Actions pour Kodjo Mensah'), findsNothing);
  });

  testWidgets('un admin peut modifier les coordonnées d’un client serveur', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminClientsPage(
            loadClients: () async => const [serverClient],
            loadLocalClients: () async => const [],
            updateClient:
                ({
                  required id,
                  required firstName,
                  required lastName,
                  required email,
                  required phone,
                }) async => serverClient.copyWith(email: email, phone: phone),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Actions pour Afi Koffi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifier').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(2),
      'afi.updated@example.com',
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('afi.updated@example.com'), findsOneWidget);
    expect(
      find.text('Les coordonnées du client ont été mises à jour.'),
      findsOneWidget,
    );
  });

  testWidgets('la désactivation affiche un badge et permet la réactivation', (
    tester,
  ) async {
    var savedStatus = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminClientsPage(
            loadClients: () async => [
              serverClient.copyWith(isActive: savedStatus),
            ],
            loadLocalClients: () async => const [],
            updateClientStatus: ({required id, required isActive}) async {
              savedStatus = isActive;
              return serverClient.copyWith(isActive: isActive);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Actions pour Afi Koffi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Désactiver').last);
    await tester.pumpAndSettle();
    expect(find.text('Désactiver ce compte ?'), findsOneWidget);
    await tester.tap(find.text('Désactiver').last);
    await tester.pumpAndSettle();

    expect(savedStatus, isFalse);
    expect(find.text('Compte désactivé'), findsOneWidget);

    await tester.tap(find.byTooltip('Actions pour Afi Koffi'));
    await tester.pumpAndSettle();
    expect(find.text('Réactiver'), findsOneWidget);
  });

  testWidgets('le formulaire reste utilisable sur un petit écran', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminClientsPage(
            loadClients: () async => const [serverClient],
            loadLocalClients: () async => const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Actions pour Afi Koffi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifier').last);
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });
}
