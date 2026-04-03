import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // URL du backend Render - NOTE: Le suffixe "-1" est important !
  static const String baseUrl = 'https://echelle-eg39-backend-1.onrender.com/api'; // Production
  // static const String baseUrl = 'http://10.0.2.2:3000/api'; // Android emulator
  // static const String baseUrl = 'http://localhost:3000/api'; // iOS simulator / web

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  /// Méthode pour s'assurer que l'utilisateur est authentifié.
  /// Si le token est manquant mais que des identifiants sont sauvegardés,
  /// tente une reconnexion automatique.
  static Future<String?> ensureAuthenticated() async {
    // 1. Vérifier si un token existe déjà
    String? token = await getToken();
    if (token != null) {
      return token;
    }
    
    // 2. Si pas de token, vérifier si des identifiants sont sauvegardés
    final prefs = await SharedPreferences.getInstance();
    final savedIdentifier = prefs.getString('saved_identifier');
    final savedPassword = prefs.getString('saved_password');
    
    if (savedIdentifier != null && savedPassword != null) {
      // 3. Tenter une reconnexion automatique
      print('🔄 Token manquant, tentative de reconnexion automatique...');
      try {
        final result = await login(savedIdentifier, savedPassword);
        if (result['token'] != null) {
          print('✅ Reconnexion automatique réussie');
          return result['token'];
        }
      } catch (e) {
        print('❌ Échec de la reconnexion automatique: $e');
        // Ne pas throw, retourner null pour que l'utilisateur soit redirigé vers login
      }
    }
    
    // 4. Pas de token et pas d'identifiants sauvegardés
    return null;
  }

  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  static Future<Map<String, dynamic>> login(String identifier, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'identifier': identifier, 'password': password}),
      );

      print('📡 Login Status Code: ${response.statusCode}');
      print('📡 Login Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await setToken(data['token']);
        return data;
      } else {
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['error'] != null) {
            throw Exception(errorData['error']);
          }
          throw Exception('Erreur ${response.statusCode}');
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception('Erreur serveur (${response.statusCode})');
        }
      }
    } catch (e) {
      if (e is Exception) rethrow;
      print('❌ Erreur réseau login: $e');
      throw Exception('Impossible de contacter le serveur. Vérifiez votre connexion internet.');
    }
  }

  static Future<Map<String, dynamic>> register(String firstName, String lastName, String email, String phone, String password) async {
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
      );

      print('📡 Status Code: ${response.statusCode}');
      print('📡 Response Body: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        await setToken(data['token']);
        return data;
      } else {
        // Tenter de décoder la réponse pour obtenir le message d'erreur
        try {
          final errorData = jsonDecode(response.body);
          
          // Gérer le cas des erreurs de validation (tableau d'erreurs)
          if (errorData['errors'] != null && errorData['errors'] is List) {
            final errors = errorData['errors'] as List;
            final errorMessages = errors.map((e) => e['msg'] ?? e['message'] ?? 'Erreur inconnue').join(', ');
            throw Exception(errorMessages);
          }
          
          // Gérer le cas d'une erreur simple
          if (errorData['error'] != null) {
            throw Exception(errorData['error']);
          }
          
          throw Exception('Erreur ${response.statusCode}: ${response.body}');
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception('Erreur serveur (${response.statusCode})');
        }
      }
    } catch (e) {
      if (e is Exception) rethrow;
      print('❌ Erreur réseau: $e');
      throw Exception('Impossible de contacter le serveur. Vérifiez votre connexion internet.');
    }
  }

  static Future<Map<String, dynamic>> getMe() async {
    final token = await ensureAuthenticated();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['error']);
    }
  }

static Future<Map<String, dynamic>> createLocationRequest(int appareilId, String dateDebut, String dateFin, int nombreJours, int total) async {
    // DEPRECATED: redirige vers createLocation standard
    print('⚠️ createLocationRequest deprecated → createLocation');
    return await createLocation(appareilId, dateDebut.split('T')[0], dateFin.split('T')[0]);
  }

  // ============================================
  // FONCTIONS: Réinitialisation du mot de passe
  // ============================================

  /// Demander un code de réinitialisation de mot de passe
  static Future<Map<String, dynamic>> requestPasswordReset(String contact, String contactType) async {
    try {
      print('📡 Envoi requête forgot-password vers: $baseUrl/auth/forgot-password');
      print('📡 Données: contact=$contact, contactType=$contactType');
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contact': contact,
          'contactType': contactType,
        }),
      );

      print('📡 Forgot Password Status Code: ${response.statusCode}');
      print('📡 Forgot Password Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else if (response.statusCode == 404) {
        throw Exception('Route non trouvée. Vérifiez la connexion au serveur.');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Erreur lors de la demande de réinitialisation');
      }
    } catch (e) {
      if (e is Exception) {
        print('❌ Erreur forgot-password: $e');
        rethrow;
      }
      print('❌ Erreur réseau forgot-password: $e');
      throw Exception('Impossible de contacter le serveur. Vérifiez votre connexion internet.');
    }
  }

  /// Vérifier le code de réinitialisation
  static Future<Map<String, dynamic>> verifyResetCode(String code, String contact) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'code': code,
          'contact': contact,
        }),
      );

      print('📡 Verify Code Status Code: ${response.statusCode}');
      print('📡 Verify Code Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Sauvegarder le token temporaire
        if (data['tempToken'] != null) {
          await setTempToken(data['tempToken']);
        }
        return data;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Code invalide ou expiré');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      print('❌ Erreur réseau verify-code: $e');
      throw Exception('Impossible de contacter le serveur. Vérifiez votre connexion internet.');
    }
  }

  /// Réinitialiser le mot de passe
  static Future<Map<String, dynamic>> resetPassword(String newPassword) async {
    try {
      final tempToken = await getTempToken();
      if (tempToken == null) {
        throw Exception('Session de réinitialisation expirée. Veuillez recommencer.');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tempToken': tempToken,
          'newPassword': newPassword,
        }),
      );

      print('📡 Reset Password Status Code: ${response.statusCode}');
      print('📡 Reset Password Response: ${response.body}');

      if (response.statusCode == 200) {
        // Supprimer le token temporaire après utilisation
        await removeTempToken();
        final data = jsonDecode(response.body);
        return data;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Erreur lors de la réinitialisation du mot de passe');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      print('❌ Erreur réseau reset-password: $e');
      throw Exception('Impossible de contacter le serveur. Vérifiez votre connexion internet.');
    }
  }

  /// Sauvegarder le token temporaire
  static Future<void> setTempToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('temp_reset_token', token);
  }

  /// Récupérer le token temporaire
  static Future<String?> getTempToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('temp_reset_token');
  }

  /// Supprimer le token temporaire
  static Future<void> removeTempToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('temp_reset_token');
  }

  // ============================================
  // FONCTIONS: Locations et Historique
  // ============================================

  /// Récupérer toutes les locations de l'utilisateur connecté
  static Future<List<Map<String, dynamic>>> getLocations({String? statut}) async {
    final token = await ensureAuthenticated();
    if (token == null) throw Exception('Not authenticated');

    String url = '$baseUrl/locations';
    if (statut != null) {
      url += '?statut=$statut';
    }

    print('📡 API getLocations: $url');
    
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 15));

    print('📡 getLocations status: ${response.statusCode}');
    print('📡 getLocations body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['locations']);
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Erreur lors de la récupération des locations');
    }
  }

  /// Rejeter une location (admin)
  static Future<Map<String, dynamic>?> rejectLocation(int locationId, String raison) async {
    final token = await ensureAuthenticated();
    if (token == null) throw Exception('Not authenticated');

    final url = '$baseUrl/locations/$locationId/rejeter';
    print('📡 API rejectLocation: $url');

    final response = await http.patch(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'raison': raison}),
    );

    print('📡 rejectLocation status: ${response.statusCode}');
    print('📡 rejectLocation body: ${response.body}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Erreur lors du rejet de la location');
    }
  }

  /// Approuver une location (admin)
  static Future<Map<String, dynamic>?> approveLocation(int locationId) async {
    final token = await ensureAuthenticated();
    if (token == null) throw Exception('Not authenticated');

    final url = '$baseUrl/locations/$locationId/approuver';
    print('📡 API approveLocation: $url');

    final response = await http.patch(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    print('📡 approveLocation status: ${response.statusCode}');
    print('📡 approveLocation body: ${response.body}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Erreur lors de l\'approbation de la location');
    }
  }

  /// Récupérer toutes les demandes d'achat de l'utilisateur connecté
  static Future<List<Map<String, dynamic>>> getDemandesAchat({String? statut}) async {
    final token = await ensureAuthenticated();
    if (token == null) throw Exception('Not authenticated');

    String url = '$baseUrl/demandes';
    if (statut != null) {
      url += '?statut=$statut';
    }

    print('📡 API getDemandesAchat: $url');
    
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    print('📡 getDemandesAchat status: ${response.statusCode}');
    print('📡 getDemandesAchat body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['demandes']);
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Erreur lors de la récupération des demandes');
    }
  }

  /// Créer une demande d'achat
  static Future<Map<String, dynamic>> createDemandeAchat(int appareilId, int quantite) async {
    final token = await ensureAuthenticated();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/demandes'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode({
        'appareilId': appareilId,
        'quantite': quantite,
      }),
    );

    print('📡 createDemandeAchat status: ${response.statusCode}');
    print('📡 createDemandeAchat body: ${response.body}');

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Erreur lors de la création de la demande');
    }
  }

  /// Récupérer les appareils disponibles
  static Future<List<Map<String, dynamic>>> getAppareils({bool? disponible}) async {
    final token = await ensureAuthenticated();
    if (token == null) throw Exception('Not authenticated');

    String url = '$baseUrl/appareils';
    if (disponible != null) {
      url += disponible ? '?disponible=true' : '?disponible=false';
    }

    print('📡 API getAppareils: $url');
    
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    print('📡 getAppareils status: ${response.statusCode}');
    print('📡 getAppareils body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['appareils']);
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Erreur lors de la récupération des appareils');
    }
  }

  /// Créer une location
  static Future<Map<String, dynamic>> createLocation(int appareilId, String dateDebut, String dateFin) async {
    final token = await ensureAuthenticated();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/locations'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode({
        'appareilId': appareilId,
        'dateDebut': dateDebut,
        'dateFin': dateFin,
      }),
    );

    print('📡 createLocation status: ${response.statusCode}');
    print('📡 createLocation body: ${response.body}');

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Erreur lors de la création de la location');
    }
  }
}

