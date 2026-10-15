import 'dart:math';

import 'package:echelle_eg_39/offline_registration_store.dart';
import 'package:echelle_eg_39/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemorySecureStore implements SecureValueStore {
  final Map<String, String> values = {};
  bool failWrites = false;

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('secure store unavailable');
    values[key] = value;
  }
}

void main() {
  late _MemorySecureStore secureStore;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    secureStore = _MemorySecureStore();
  });

  OfflineRegistrationStore storeFor() => OfflineRegistrationStore(
    secureValues: secureStore,
    random: Random(13),
    now: () => DateTime.utc(2026, 10, 15),
  );

  test('migre les listes historiques et retire les secrets du cache', () async {
    SharedPreferences.setMockInitialValues({
      'registered_users': [
        'afi@example.com|+22890000000|1234AZER|user|Afi|Koffi',
      ],
      'pending_sync_users': [
        'afi@example.com|+22890000000|1234AZER|user|Afi|Koffi',
        'kodjo@example.com|+22891111111|9999TEST|user|Kodjo|Mensah',
      ],
    });
    final prefs = await SharedPreferences.getInstance();
    final store = storeFor();

    expect(await store.migrateLegacyRecords(), 2);
    expect(await store.migrateLegacyRecords(), 0);
    expect(prefs.getStringList('registered_users'), isNull);
    expect(prefs.getStringList('pending_sync_users'), isNull);

    final accounts = await store.localAccounts();
    expect(accounts.map((entry) => entry.email), [
      'afi@example.com',
      'kodjo@example.com',
    ]);
    expect(secureStore.values.values, containsAll(['1234AZER', '9999TEST']));

    final preferenceSnapshot = prefs
        .getKeys()
        .map((key) => prefs.get(key).toString())
        .join('|');
    expect(preferenceSnapshot, isNot(contains('1234AZER')));
    expect(preferenceSnapshot, isNot(contains('9999TEST')));
  });

  test(
    'conserve la liste legacy si le coffre sécurisé ne répond pas',
    () async {
      SharedPreferences.setMockInitialValues({
        'registered_users': [
          'afi@example.com|+22890000000|1234AZER|user|Afi|Koffi',
        ],
      });
      secureStore.failWrites = true;
      final prefs = await SharedPreferences.getInstance();

      await storeFor().migrateLegacyRecords();

      expect(prefs.getStringList('registered_users'), hasLength(1));
      expect(await storeFor().localAccounts(), isEmpty);
    },
  );

  test(
    'accepte les barres dans les noms et garde les mots de passe chiffrés',
    () async {
      final store = storeFor();
      final saved = await store.save(
        const OfflineRegistrationDraft(
          firstName: 'Afi|Adjovi',
          lastName: 'Koffi|Mensah',
          email: 'afi@example.com',
          phone: '+22890000000',
          password: '1234AZER',
        ),
      );

      expect(saved, isTrue);
      expect((await store.localAccounts()).single.firstName, 'Afi|Adjovi');
      expect((await store.pendingCredentials()).single.password, '1234AZER');
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('offline_registration_metadata_v2'),
        isNot(contains('1234AZER')),
      );
    },
  );

  test('supprime le mot de passe sécurisé après synchronisation', () async {
    final store = storeFor();
    await store.save(
      const OfflineRegistrationDraft(
        firstName: 'Afi',
        lastName: 'Koffi',
        email: 'afi@example.com',
        phone: '+22890000000',
        password: '1234AZER',
      ),
    );
    final entry = (await store.localAccounts()).single;

    await store.markCompleted(entry.id);

    expect(await store.pendingCredentials(), isEmpty);
    expect(await store.localAccounts(), isEmpty);
    expect(secureStore.values, isEmpty);
  });

  test('termine la file lorsque le serveur accepte le compte', () async {
    final store = storeFor();
    await store.save(
      const OfflineRegistrationDraft(
        firstName: 'Afi',
        lastName: 'Koffi',
        email: 'afi@example.com',
        phone: '+22890000000',
        password: '1234AZER',
      ),
    );
    String? sentPassword;

    final result = await SyncService.syncPendingUsersWith(
      store: store,
      sendRegistration: (registration) async {
        sentPassword = registration.password;
        return OfflineSyncOutcome.completed;
      },
    );

    expect(result.success, isTrue);
    expect(result.syncedCount, 1);
    expect(sentPassword, '1234AZER');
    expect(await store.pendingCredentials(), isEmpty);
    expect(secureStore.values, isEmpty);
  });

  test('conserve la demande en attente après un échec réseau', () async {
    final store = storeFor();
    await store.save(
      const OfflineRegistrationDraft(
        firstName: 'Afi',
        lastName: 'Koffi',
        email: 'afi@example.com',
        phone: '+22890000000',
        password: '1234AZER',
      ),
    );

    final result = await SyncService.syncPendingUsersWith(
      store: store,
      sendRegistration: (_) async => OfflineSyncOutcome.retry,
    );

    expect(result.success, isFalse);
    expect((await store.pendingCredentials()).single.password, '1234AZER');
    expect((await store.localAccounts()).single.status, 'pending');
  });
}
