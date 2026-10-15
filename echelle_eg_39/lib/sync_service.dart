import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';
import 'offline_registration_store.dart';

enum OfflineSyncOutcome { completed, retry, needsReview }

typedef OfflineRegistrationSender =
    Future<OfflineSyncOutcome> Function(
      PendingOfflineRegistration registration,
    );

/// Sync coordinator that allows only one pass at a time and never puts a
/// password into SharedPreferences or diagnostics.
class OfflineRegistrationSynchronizer {
  OfflineRegistrationSynchronizer({
    required this.store,
    required this.sendRegistration,
  });

  final OfflineRegistrationStore store;
  final OfflineRegistrationSender sendRegistration;
  Future<SyncResult>? _inFlight;

  Future<SyncResult> syncPendingUsers() {
    final ongoing = _inFlight;
    if (ongoing != null) return ongoing;

    final run = _runSync();
    _inFlight = run;
    return run.whenComplete(() {
      if (identical(_inFlight, run)) _inFlight = null;
    });
  }

  Future<SyncResult> _runSync() async {
    final pending = await store.pendingCredentials();
    var syncedCount = 0;
    final failedIds = <String>[];

    for (final registration in pending) {
      OfflineSyncOutcome outcome;
      try {
        outcome = await sendRegistration(registration);
      } catch (_) {
        outcome = OfflineSyncOutcome.retry;
      }

      try {
        switch (outcome) {
          case OfflineSyncOutcome.completed:
            await store.markCompleted(registration.entry.id);
            syncedCount++;
          case OfflineSyncOutcome.retry:
            failedIds.add(registration.entry.id);
          case OfflineSyncOutcome.needsReview:
            await store.markNeedsReview(registration.entry.id);
            failedIds.add(registration.entry.id);
        }
      } catch (_) {
        // Leave the entry intact so the next pass can retry safely.
        failedIds.add(registration.entry.id);
      }
    }

    return SyncResult(
      success: failedIds.isEmpty,
      syncedCount: syncedCount,
      failedUsers: List.unmodifiable(failedIds),
      message: failedIds.isEmpty
          ? '$syncedCount utilisateur(s) synchronisé(s)'
          : '$syncedCount synchronisé(s), ${failedIds.length} à vérifier',
    );
  }
}

class SyncService {
  static const String baseUrl = ApiService.baseUrl;
  static final OfflineRegistrationStore _store =
      OfflineRegistrationStore.instance;
  static final OfflineRegistrationSynchronizer _synchronizer =
      OfflineRegistrationSynchronizer(
        store: _store,
        sendRegistration: _sendRegistration,
      );

  /// A valid unauthenticated response means the API can be reached.
  static Future<bool> isApiAvailable() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/auth/me'))
          .timeout(const Duration(seconds: 4));
      return response.statusCode > 0;
    } on TimeoutException {
      return false;
    } on http.ClientException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Compatibility entry point: migrate legacy passwords even while offline,
  /// then skip the network queue when the API is unreachable.
  static Future<SyncResult> syncPendingUsers() async {
    await _store.migrateLegacyRecords();
    if (!await isApiAvailable()) {
      final pendingCount = await _store.getPendingCount();
      return SyncResult(
        success: false,
        syncedCount: 0,
        failedUsers: const [],
        message: '$pendingCount inscription(s) en attente',
      );
    }
    return _synchronizer.syncPendingUsers();
  }

  /// Legacy callers delegate to the same queue; no parallel plaintext list is
  /// processed.
  static Future<SyncResult> syncLocalUsers() => syncPendingUsers();

  static Future<void> syncOnLogin() async {
    await syncPendingUsers();
  }

  static Future<bool> saveUserForLaterSync(OfflineRegistrationDraft draft) =>
      _store.save(draft);

  static Future<SyncResult> syncPendingUsersWith({
    required OfflineRegistrationStore store,
    required OfflineRegistrationSender sendRegistration,
  }) {
    return OfflineRegistrationSynchronizer(
      store: store,
      sendRegistration: sendRegistration,
    ).syncPendingUsers();
  }

  static Future<SyncResult> syncPendingUsersWithDefaultStore({
    required OfflineRegistrationSender sendRegistration,
  }) {
    return syncPendingUsersWith(
      store: _store,
      sendRegistration: sendRegistration,
    );
  }

  static Future<OfflineSyncOutcome> _sendRegistration(
    PendingOfflineRegistration registration,
  ) async {
    final entry = registration.entry;
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'firstName': entry.firstName,
              'lastName': entry.lastName,
              'email': entry.email,
              'phone': entry.phone,
              'password': registration.password,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 201) return OfflineSyncOutcome.completed;

      final decoded = ApiService.decodeObject(response.body);
      final error = decoded?['error']?.toString() ?? '';
      if (response.statusCode == 400 &&
          error.toLowerCase().contains('déjà utilisé')) {
        return await _verifyExistingAccountOwner(
          entry.email,
          registration.password,
        );
      }
      if (response.statusCode == 408 ||
          response.statusCode == 429 ||
          response.statusCode >= 500) {
        return OfflineSyncOutcome.retry;
      }
      return OfflineSyncOutcome.needsReview;
    } on TimeoutException {
      return OfflineSyncOutcome.retry;
    } on http.ClientException {
      return OfflineSyncOutcome.retry;
    } catch (_) {
      return OfflineSyncOutcome.retry;
    }
  }

  static Future<OfflineSyncOutcome> _verifyExistingAccountOwner(
    String email,
    String password,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'identifier': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) return OfflineSyncOutcome.completed;
      if (response.statusCode >= 500 ||
          response.statusCode == 408 ||
          response.statusCode == 429) {
        return OfflineSyncOutcome.retry;
      }
      return OfflineSyncOutcome.needsReview;
    } on TimeoutException {
      return OfflineSyncOutcome.retry;
    } on http.ClientException {
      return OfflineSyncOutcome.retry;
    } catch (_) {
      return OfflineSyncOutcome.retry;
    }
  }

  static Future<SyncStatus> getSyncStatus() async {
    final accounts = await _store.localAccounts();
    final pendingCount = await _store.getPendingCount();
    return SyncStatus(
      isSynced: pendingCount == 0,
      lastSyncTimestamp: null,
      pendingCount: pendingCount,
      localUsersCount: accounts.length,
    );
  }
}

class SyncResult {
  const SyncResult({
    required this.success,
    required this.syncedCount,
    this.failedUsers = const [],
    required this.message,
  });

  final bool success;
  final int syncedCount;
  final List<String> failedUsers;
  final String message;
}

class SyncStatus {
  const SyncStatus({
    required this.isSynced,
    this.lastSyncTimestamp,
    required this.pendingCount,
    required this.localUsersCount,
  });

  final bool isSynced;
  final int? lastSyncTimestamp;
  final int pendingCount;
  final int localUsersCount;
}
