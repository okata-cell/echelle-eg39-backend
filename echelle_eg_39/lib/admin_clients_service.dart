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
  static const _baseUrl =
      'https://echelle-eg39-backend-1.onrender.com/api';

  static Future<List<AdminClient>> loadClients() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      throw const AdminClientsException(
        message: 'Session administrateur requise.',
      );
    }

    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/users/clients'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        var message = 'Impossible de charger les clients.';
        try {
          final body = jsonDecode(response.body);
          if (body is Map<String, dynamic> && body['error'] is String) {
            message = body['error'] as String;
          }
        } on FormatException {
          // Conserve le message générique pour les réponses non JSON.
        }
        throw AdminClientsException(
          message: message,
          statusCode: response.statusCode,
        );
      }

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic> || body['clients'] is! List) {
        throw const AdminClientsException(
          message: 'Réponse de la liste clients invalide.',
        );
      }

      return (body['clients'] as List<dynamic>)
          .whereType<Map>()
          .map((client) => AdminClient.fromJson(Map<String, dynamic>.from(client)))
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
}
