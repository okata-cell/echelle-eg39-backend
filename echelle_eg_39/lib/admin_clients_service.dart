import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models_admin_client.dart';

class AdminClientsException implements Exception {
  const AdminClientsException({required this.message, this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AdminClientsService {
  static const _baseUrl = 'https://echelle-eg39-backend-1.onrender.com/api';

  static Future<List<AdminClient>> loadClients() async {
    final token = await _requireToken();
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/users/clients'), headers: _headers(token))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw _exceptionFromResponse(response);
      }

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic> || body['clients'] is! List) {
        throw const AdminClientsException(
          message: 'Réponse de la liste clients invalide.',
        );
      }

      return (body['clients'] as List<dynamic>)
          .whereType<Map>()
          .map(
            (client) => AdminClient.fromJson(Map<String, dynamic>.from(client)),
          )
          .where((client) => client.id.isNotEmpty && client.role != 'admin')
          .toList(growable: false);
    } on AdminClientsException {
      rethrow;
    } on TimeoutException {
      throw const AdminClientsException(
        message: 'Le serveur ne répond pas pour le moment. Réessaie plus tard.',
      );
    } catch (_) {
      throw const AdminClientsException(
        message: 'Impossible de contacter le serveur. Vérifie ta connexion.',
      );
    }
  }

  static Future<AdminClient> updateClient({
    required String id,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
  }) {
    return _patchClient(id, {
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
    });
  }

  static Future<AdminClient> setClientActive({
    required String id,
    required bool isActive,
  }) {
    return _patchClient(id, {'isActive': isActive}, status: true);
  }

  static Map<String, String> _headers(String token) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  static Future<String> _requireToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      throw const AdminClientsException(
        message: 'Session administrateur requise.',
        statusCode: 401,
      );
    }
    return token;
  }

  static Future<AdminClient> _patchClient(
    String id,
    Map<String, Object> payload, {
    bool status = false,
  }) async {
    final token = await _requireToken();
    final suffix = status ? '/status' : '';
    final uri = Uri.parse(
      '$_baseUrl/users/clients/${Uri.encodeComponent(id)}$suffix',
    );

    late final http.Response response;
    try {
      response = await http
          .patch(uri, headers: _headers(token), body: jsonEncode(payload))
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const AdminClientsException(
        message: 'Le serveur ne répond pas pour le moment. Réessaie plus tard.',
      );
    } catch (_) {
      throw const AdminClientsException(
        message: 'Impossible de contacter le serveur. Vérifie ta connexion.',
      );
    }

    if (response.statusCode != 200) {
      throw _exceptionFromResponse(response);
    }

    try {
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic> || body['client'] is! Map) {
        throw const AdminClientsException(
          message: 'Réponse de mise à jour du client invalide.',
        );
      }
      return AdminClient.fromJson(
        Map<String, dynamic>.from(body['client'] as Map),
      );
    } on AdminClientsException {
      rethrow;
    } on FormatException {
      throw const AdminClientsException(
        message: 'Réponse de mise à jour du client invalide.',
      );
    }
  }

  static AdminClientsException _exceptionFromResponse(http.Response response) {
    var message = 'Impossible de modifier le client.';
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic> && body['error'] is String) {
        message = body['error'] as String;
      }
    } on FormatException {
      // Garde le message générique pour une réponse non JSON.
    }
    return AdminClientsException(
      message: message,
      statusCode: response.statusCode,
    );
  }
}
