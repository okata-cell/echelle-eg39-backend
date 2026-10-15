import 'package:echelle_eg_39/offline_registration_banner.dart';
import 'package:echelle_eg_39/offline_registration_store.dart';
import 'package:echelle_eg_39/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

OfflineRegistrationEntry _pendingEntry({String status = 'pending'}) {
  return OfflineRegistrationEntry(
    id: 'offline-1',
    firstName: 'Afi',
    lastName: 'Koffi',
    email: 'afi@example.com',
    phone: '+22890000000',
    role: 'client',
    status: status,
    createdAt: '2026-10-15T00:00:00.000Z',
  );
}

void main() {
  testWidgets(
    'affiche une invitation à réessayer si le compte reste en attente',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineRegistrationBanner(
              loadRegistrations: () async => [_pendingEntry()],
              syncRegistrations: () async => const SyncResult(
                success: false,
                syncedCount: 0,
                message: '1 inscription en attente',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Inscription en attente de synchronisation'),
        findsOneWidget,
      );
      expect(find.text('Réessayer'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(
        find.text('Vérifiez votre connexion et réessayez.'),
        findsOneWidget,
      );
      expect(
        find.text('Inscription en attente de synchronisation'),
        findsOneWidget,
      );
    },
  );

  testWidgets('masque le bandeau dès que la synchronisation a réussi', (
    tester,
  ) async {
    var loadCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfflineRegistrationBanner(
            loadRegistrations: () async {
              loadCount++;
              return loadCount == 1 ? [_pendingEntry()] : const [];
            },
            syncRegistrations: () async => const SyncResult(
              success: true,
              syncedCount: 1,
              message: '1 utilisateur synchronisé',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Inscription en attente de synchronisation'),
      findsOneWidget,
    );

    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(
      find.text('Inscription en attente de synchronisation'),
      findsNothing,
    );
  });

  testWidgets('signale à part un compte à vérifier', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfflineRegistrationBanner(
            loadRegistrations: () async => [
              _pendingEntry(status: 'needs_review'),
            ],
            syncRegistrations: () async => const SyncResult(
              success: false,
              syncedCount: 0,
              message: '1 inscription à vérifier',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Inscription à vérifier'), findsOneWidget);
    expect(
      find.text('1 inscription(s) nécessitent une vérification.'),
      findsOneWidget,
    );
  });
}
