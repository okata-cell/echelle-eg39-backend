import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _offlineMetadataKey = 'offline_registration_metadata_v2';
const String _legacyRegisteredUsersKey = 'registered_users';
const String _legacyPendingUsersKey = 'pending_sync_users';
const String _passwordKeyPrefix = 'offline_registration_password_';
const String _legacyPayloadKeyPrefix = 'offline_registration_legacy_payload_';

abstract interface class SecureValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureValueStore implements SecureValueStore {
  FlutterSecureValueStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          FlutterSecureStorage(
            aOptions: AndroidOptions(migrateWithBackup: true),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class OfflineRegistrationDraft {
  const OfflineRegistrationDraft({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.password,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String password;
}

class OfflineRegistrationEntry {
  const OfflineRegistrationEntry({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.role,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String role;
  final String status;
  final String createdAt;

  bool get canSync => status == 'pending';

  Map<String, dynamic> toMetadata() => {
    'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'phone': phone,
    'role': role,
    'status': status,
    'createdAt': createdAt,
  };

  factory OfflineRegistrationEntry.fromMetadata(Map<String, dynamic> json) {
    return OfflineRegistrationEntry(
      id: json['id']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      role: json['role']?.toString() ?? 'client',
      status: json['status']?.toString() ?? 'pending',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class PendingOfflineRegistration {
  const PendingOfflineRegistration({
    required this.entry,
    required this.password,
  });

  final OfflineRegistrationEntry entry;
  final String password;
}

/// Keeps account display metadata in SharedPreferences and passwords only in
/// iOS Keychain / Android Keystore-backed secure storage.
class OfflineRegistrationStore {
  OfflineRegistrationStore({
    SecureValueStore? secureValues,
    Future<SharedPreferences> Function()? preferencesLoader,
    Random? random,
    DateTime Function()? now,
  }) : _secureValues = secureValues ?? FlutterSecureValueStore(),
       _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance,
       _random = random ?? Random.secure(),
       _now = now ?? DateTime.now;

  static final OfflineRegistrationStore instance = OfflineRegistrationStore();

  final SecureValueStore _secureValues;
  final Future<SharedPreferences> Function() _preferencesLoader;
  final Random _random;
  final DateTime Function() _now;
  Future<void> _operationTail = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() operation) async {
    final previous = _operationTail;
    final release = Completer<void>();
    _operationTail = release.future;
    await previous;
    try {
      return await operation();
    } finally {
      release.complete();
    }
  }

  String _newId() =>
      '${_now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}';

  String _passwordKey(String id) => '$_passwordKeyPrefix$id';
  String _legacyPayloadKey(String id) => '$_legacyPayloadKeyPrefix$id';

  List<OfflineRegistrationEntry> _readMetadata(SharedPreferences prefs) {
    final raw = prefs.getString(_offlineMetadataKey);
    if (raw == null || raw.isEmpty) return <OfflineRegistrationEntry>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <OfflineRegistrationEntry>[];
      return decoded
          .whereType<Map>()
          .map(
            (entry) => OfflineRegistrationEntry.fromMetadata(
              Map<String, dynamic>.from(entry),
            ),
          )
          .where((entry) => entry.id.isNotEmpty)
          .toList(growable: true);
    } on FormatException {
      return <OfflineRegistrationEntry>[];
    }
  }

  Future<void> _writeMetadata(
    SharedPreferences prefs,
    List<OfflineRegistrationEntry> entries,
  ) async {
    final saved = await prefs.setString(
      _offlineMetadataKey,
      jsonEncode(entries.map((entry) => entry.toMetadata()).toList()),
    );
    if (!saved) {
      throw StateError('Impossible de sauvegarder les comptes locaux.');
    }
  }

  bool _matchesExisting(
    OfflineRegistrationEntry entry,
    String email,
    String phone,
  ) {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPhone = phone.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    return entry.status != 'completed' &&
        ((normalizedEmail.isNotEmpty &&
                entry.email.trim().toLowerCase() == normalizedEmail) ||
            (normalizedPhone.isNotEmpty &&
                entry.phone.replaceAll(RegExp(r'[^0-9+]'), '') ==
                    normalizedPhone));
  }

  Future<void> _migrateLegacyLocked(SharedPreferences prefs) async {
    final registered = prefs.getStringList(_legacyRegisteredUsersKey) ?? [];
    final pending = prefs.getStringList(_legacyPendingUsersKey) ?? [];
    if (registered.isEmpty && pending.isEmpty) return;

    final entries = _readMetadata(prefs);
    final newlySecuredKeys = <String>[];
    var migrationComplete = true;
    final sources = <List<String>>[registered, pending];

    for (final records in sources) {
      for (var index = 0; index < records.length; index++) {
        final raw = records[index];
        final parts = raw.split('|');
        final email = parts.isNotEmpty ? parts[0].trim() : '';
        final phone = parts.length > 1 ? parts[1].trim() : '';
        final existingIndex = entries.indexWhere(
          (entry) => _matchesExisting(entry, email, phone),
        );
        final hasPassword = parts.length > 2 && parts[2].isNotEmpty;
        if (existingIndex >= 0) {
          final existing = entries[existingIndex];
          if (existing.status == 'pending' && hasPassword) {
            final storedPassword = await _secureValues.read(
              _passwordKey(existing.id),
            );
            if (storedPassword == null || storedPassword.isEmpty) {
              try {
                final key = _passwordKey(existing.id);
                await _secureValues.write(key, parts[2]);
                newlySecuredKeys.add(key);
              } catch (_) {
                migrationComplete = false;
              }
            }
          }
          continue;
        }

        final roleValue = parts.length > 3
            ? parts[3].trim().toLowerCase()
            : 'user';
        final role = roleValue == 'admin' ? 'admin' : 'client';
        final entry = OfflineRegistrationEntry(
          id: _newId(),
          firstName: parts.length > 4 && parts[4].trim().isNotEmpty
              ? parts[4].trim()
              : 'Utilisateur',
          lastName:
              parts.length > 5 && parts.sublist(5).join('|').trim().isNotEmpty
              ? parts.sublist(5).join('|').trim()
              : 'EG39',
          email: email,
          phone: phone,
          role: role,
          status: hasPassword && role == 'client' ? 'pending' : 'needs_review',
          createdAt: _now().toIso8601String(),
        );

        if (hasPassword) {
          try {
            final key = _passwordKey(entry.id);
            await _secureValues.write(key, parts[2]);
            newlySecuredKeys.add(key);
          } catch (_) {
            // Keep the original source intact if the device secure store is
            // unavailable; do not erase the only recoverable credential.
            migrationComplete = false;
            continue;
          }
        }
        entries.add(entry);
      }
    }

    // Write all successfully migrated metadata before removing the legacy
    // records. If either operation fails, keep the old list for a safe retry.
    try {
      await _writeMetadata(prefs, entries);
    } catch (_) {
      for (final key in newlySecuredKeys) {
        try {
          await _secureValues.delete(key);
        } catch (_) {}
      }
      rethrow;
    }
    if (!migrationComplete) return;

    await prefs.remove(_legacyRegisteredUsersKey);
    await prefs.remove(_legacyPendingUsersKey);
  }

  Future<int> migrateLegacyRecords() => _serialized(() async {
    final prefs = await _preferencesLoader();
    final before = _readMetadata(prefs).length;
    await _migrateLegacyLocked(prefs);
    return _readMetadata(prefs).length - before;
  });

  Future<bool> save(OfflineRegistrationDraft draft) => _serialized(() async {
    final prefs = await _preferencesLoader();
    await _migrateLegacyLocked(prefs);
    final entries = _readMetadata(prefs);
    if (entries.any(
      (entry) => _matchesExisting(entry, draft.email, draft.phone),
    )) {
      return false;
    }

    final entry = OfflineRegistrationEntry(
      id: _newId(),
      firstName: draft.firstName.trim(),
      lastName: draft.lastName.trim(),
      email: draft.email.trim(),
      phone: draft.phone.trim(),
      role: 'client',
      status: 'pending',
      createdAt: _now().toIso8601String(),
    );

    await _secureValues.write(_passwordKey(entry.id), draft.password);
    try {
      entries.add(entry);
      await _writeMetadata(prefs, entries);
    } catch (_) {
      await _secureValues.delete(_passwordKey(entry.id));
      rethrow;
    }
    return true;
  });

  Future<List<OfflineRegistrationEntry>> localAccounts() =>
      _serialized(() async {
        final prefs = await _preferencesLoader();
        await _migrateLegacyLocked(prefs);
        return _readMetadata(prefs)
            .where(
              (entry) => entry.status != 'completed' && entry.role != 'admin',
            )
            .toList(growable: false);
      });

  Future<List<PendingOfflineRegistration>> pendingCredentials() =>
      _serialized(() async {
        final prefs = await _preferencesLoader();
        await _migrateLegacyLocked(prefs);
        final entries = _readMetadata(prefs);
        final pending = <PendingOfflineRegistration>[];
        var changed = false;

        for (var index = 0; index < entries.length; index++) {
          final entry = entries[index];
          if (!entry.canSync) continue;
          final password = await _secureValues.read(_passwordKey(entry.id));
          if (password == null || password.isEmpty) {
            entries[index] = _copyWithStatus(entry, 'needs_review');
            changed = true;
            continue;
          }
          pending.add(
            PendingOfflineRegistration(entry: entry, password: password),
          );
        }

        if (changed) await _writeMetadata(prefs, entries);
        return pending;
      });

  Future<void> markCompleted(String id) => _serialized(() async {
    final prefs = await _preferencesLoader();
    final entries = _readMetadata(prefs);
    final index = entries.indexWhere((entry) => entry.id == id);
    if (index < 0) return;

    // Remove the secret first; if secure deletion fails, keep the pending
    // metadata so a retry can verify the account and retry cleanup.
    await _secureValues.delete(_passwordKey(id));
    await _secureValues.delete(_legacyPayloadKey(id));
    entries.removeAt(index);
    await _writeMetadata(prefs, entries);
  });

  Future<void> markNeedsReview(String id) => _serialized(() async {
    final prefs = await _preferencesLoader();
    final entries = _readMetadata(prefs);
    final index = entries.indexWhere((entry) => entry.id == id);
    if (index < 0) return;
    entries[index] = _copyWithStatus(entries[index], 'needs_review');
    await _writeMetadata(prefs, entries);
  });

  Future<int> getPendingCount() => _serialized(() async {
    final prefs = await _preferencesLoader();
    await _migrateLegacyLocked(prefs);
    return _readMetadata(
      prefs,
    ).where((entry) => entry.status != 'completed').length;
  });

  OfflineRegistrationEntry _copyWithStatus(
    OfflineRegistrationEntry entry,
    String status,
  ) {
    return OfflineRegistrationEntry(
      id: entry.id,
      firstName: entry.firstName,
      lastName: entry.lastName,
      email: entry.email,
      phone: entry.phone,
      role: entry.role,
      status: status,
      createdAt: entry.createdAt,
    );
  }
}
