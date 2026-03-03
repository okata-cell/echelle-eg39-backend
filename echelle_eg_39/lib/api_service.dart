import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Utiliser localhost pour les tests en développement
  // static const String baseUrl = 'https://echelle-eg39-backend.onrender.com/api'; // Production
  static const String baseUrl = 'http://10.0.2.2:3000/api'; // Android emulator
  // static const String baseUrl = 'http://localhost:3000/api'; // iOS simulator / web

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
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
    final token = await getToken();
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
    final token = await getToken();
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
        'nombreJours': nombreJours,
        'total': total,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['error']);
    }
  }

  // ============================================
  // FONCTIONS: Réinitialisation du mot de passe
  // ============================================

  /// Demander un code de réinitialisation de mot de passe
  static Future<Map<String, dynamic>> requestPasswordReset(String contact, String contactType) async {
    try {
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
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Erreur lors de la demande de réinitialisation');
      }
    } catch (e) {
      if (e is Exception) rethrow;
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
}
