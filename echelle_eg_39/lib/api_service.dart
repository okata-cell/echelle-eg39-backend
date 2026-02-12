import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://echelle-eg39-backend.onrender.com/api';

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
}