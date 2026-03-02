import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service de synchronisation pour gérer la connexion entre le stockage local et l'API
class SyncService {
  static const String baseUrl = 'https://echelle-eg39-backend.onrender.com/api';
  
  /// Vérifie si l'API est disponible
  static Future<bool> isApiAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      // Si on reçoit une réponse (même 401), l'API est disponible
      return response.statusCode != 0;
    } catch (e) {
      print('❌ API non disponible: $e');
      return false;
    }
  }

  /// Synchronise tous les utilisateurs locaux vers l'API
  static Future<SyncResult> syncLocalUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final registeredUsers = prefs.getStringList('registered_users') ?? [];
    
    if (registeredUsers.isEmpty) {
      return SyncResult(success: true, syncedCount: 0, message: 'Aucun utilisateur local à synchroniser');
    }

    int syncedCount = 0;
    List<String> failedUsers = [];
    
    for (String userData in registeredUsers) {
      final parts = userData.split('|');
      if (parts.length >= 4) {
        final email = parts[0];
        final phone = parts[1];
        final password = parts[2];
        final role = parts[3];
        final firstName = parts.length > 4 ? parts[4] : 'Utilisateur';
        final lastName = parts.length > 5 ? parts[5] : 'EG39';
        
        try {
          // Tenter d'inscrire l'utilisateur sur l'API
          final result = await _registerUserOnApi(
            firstName, 
            lastName, 
            email, 
            phone, 
            password
          );
          
          if (result['success']) {
            syncedCount++;
            print('✅ Utilisateur synchronisé: $email');
          } else {
            // Si l'utilisateur existe déjà sur l'API, c'est OK
            if (result['error']?.contains('déjà utilisé') ?? false) {
              syncedCount++;
              print('⚠️ Utilisateur existe déjà sur API: $email');
            } else {
              failedUsers.add(email);
              print('❌ Échec synchronisation: $email - ${result['error']}');
            }
          }
        } catch (e) {
          failedUsers.add(email);
          print('❌ Exception lors de la synchronisation: $email - $e');
        }
      }
    }
    
    // Marquer les utilisateurs comme synchronisés
    if (syncedCount > 0) {
      await prefs.setBool('users_synced', true);
      await prefs.setInt('last_sync_timestamp', DateTime.now().millisecondsSinceEpoch);
    }
    
    return SyncResult(
      success: failedUsers.isEmpty,
      syncedCount: syncedCount,
      failedUsers: failedUsers,
      message: failedUsers.isEmpty 
        ? '$syncedCount utilisateur(s) synchronisé(s)' 
        : '$syncedCount synchronisé(s), ${failedUsers.length} échoué(s)'
    );
  }

  /// Tente d'inscrire un utilisateur sur l'API
  static Future<Map<String, dynamic>> _registerUserOnApi(
    String firstName, 
    String lastName, 
    String email, 
    String phone, 
    String password
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'phone': phone,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'error': errorData['error'] ?? 'Erreur inconnue',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Synchronise les données utilisateur lors de la connexion
  static Future<void> syncOnLogin() async {
    // Vérifier d'abord si l'API est disponible
    final apiAvailable = await isApiAvailable();
    
    if (!apiAvailable) {
      print('⚠️ API non disponible, pas de synchronisation');
      return;
    }
    
    // Vérifier si les utilisateurs locaux ont été synchronisés
    final prefs = await SharedPreferences.getInstance();
    final usersSynced = prefs.getBool('users_synced') ?? false;
    
    if (!usersSynced) {
      print('🔄 Tentative de synchronisation des utilisateurs locaux...');
      final result = await syncLocalUsers();
      
      if (result.success) {
        print('✅ Synchronisation réussie: ${result.syncedCount} utilisateurs');
      } else {
        print('⚠️ Synchronisation partielle: ${result.message}');
      }
    } else {
      print('✅ Utilisateurs déjà synchronisés précédemment');
    }
  }

  /// Sauvegarde un utilisateur en attente de synchronisation
  static Future<void> saveUserForLaterSync(String userData) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingSync = prefs.getStringList('pending_sync_users') ?? [];
    pendingSync.add(userData);
    await prefs.setStringList('pending_sync_users', pendingSync);
    print('✅ Utilisateur sauvegardé pour synchronisation ultérieure');
  }

  /// Synchronise les utilisateurs en attente
  static Future<SyncResult> syncPendingUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingSync = prefs.getStringList('pending_sync_users') ?? [];
    
    if (pendingSync.isEmpty) {
      return SyncResult(success: true, syncedCount: 0, message: 'Aucun utilisateur en attente');
    }
    
    int syncedCount = 0;
    List<String> failedUsers = [];
    
    for (String userData in pendingSync) {
      final parts = userData.split('|');
      if (parts.length >= 4) {
        final result = await _registerUserOnApi(
          parts.length > 4 ? parts[4] : 'Utilisateur',
          parts.length > 5 ? parts[5] : 'EG39',
          parts[0],
          parts[1],
          parts[2]
        );
        
        if (result['success']) {
          syncedCount++;
        } else {
          failedUsers.add(parts[0]);
        }
      }
    }
    
    // Supprimer les utilisateurs synchronisés avec succès
    if (syncedCount > 0) {
      final remaining = pendingSync.length - syncedCount;
      if (remaining > 0) {
        await prefs.setStringList('pending_sync_users', failedUsers);
      } else {
        await prefs.remove('pending_sync_users');
      }
    }
    
    return SyncResult(
      success: failedUsers.isEmpty,
      syncedCount: syncedCount,
      failedUsers: failedUsers,
      message: '$syncedCount utilisateur(s) synchronisé(s)'
    );
  }

  /// Vérifie et signale le statut de synchronisation
  static Future<SyncStatus> getSyncStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final usersSynced = prefs.getBool('users_synced') ?? false;
    final lastSync = prefs.getInt('last_sync_timestamp');
    final pendingCount = (prefs.getStringList('pending_sync_users') ?? []).length;
    final localUsersCount = (prefs.getStringList('registered_users') ?? []).length;
    
    return SyncStatus(
      isSynced: usersSynced,
      lastSyncTimestamp: lastSync,
      pendingCount: pendingCount,
      localUsersCount: localUsersCount,
    );
  }
}

/// Résultat d'une synchronisation
class SyncResult {
  final bool success;
  final int syncedCount;
  final List<String> failedUsers;
  final String message;

  SyncResult({
    required this.success,
    required this.syncedCount,
    this.failedUsers = const [],
    required this.message,
  });
}

/// Statut de synchronisation
class SyncStatus {
  final bool isSynced;
  final int? lastSyncTimestamp;
  final int pendingCount;
  final int localUsersCount;

  SyncStatus({
    required this.isSynced,
    this.lastSyncTimestamp,
    required this.pendingCount,
    required this.localUsersCount,
  });
}

