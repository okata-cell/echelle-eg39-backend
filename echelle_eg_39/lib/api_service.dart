import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models_admin_client.dart';
import 'models_anonymized_user.dart';

enum ApiErrorType {
  invalidIdentifier,
  invalidPassword,
  invalidCredentials,
  serverUnavailable,
  network,
  request,
}

class ApiException implements Exception {
  const ApiException({
    required this.type,
    required this.message,
    this.statusCode,
  });

  final ApiErrorType type;
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  // URL du backend Render - NOTE: Le suffixe "-1" est important !
  static const String baseUrl =
      'https://echelle-eg39-backend-1.onrender.com/api'; // Production
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

    // 2. Pas de token : on ne stocke plus le mot de passe en local,
    //    donc pas de reconnexion automatique. L'utilisateur doit se reconnecter manuellement.
    print(
      '🔄 Token manquant, reconnexion manuelle requise (aucun mot de passe local).',
    );
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

  static Future<Map<String, dynamic>> login(
    String identifier,
    String password,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'identifier': identifier, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      print('📡 Login Status Code: ${response.statusCode}');
      print('📡 Login Response: ${response.body}');

      Map<String, dynamic> responseData = <String, dynamic>{};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          responseData = decoded;
        }
      } on FormatException {
        // Le message générique ci-dessous sera utilisé pour une réponse invalide.
      }

      if (response.statusCode == 200) {
        final token = responseData['token'];
        if (token is! String || token.isEmpty) {
          throw const ApiException(
            type: ApiErrorType.request,
            message: 'Réponse de connexion invalide.',
          );
        }

        await setToken(token);
        return responseData;
      }

      final serverCode = responseData['code']?.toString();
      if (response.statusCode == 401) {
        if (serverCode == 'INVALID_PASSWORD') {
          throw const ApiException(
            type: ApiErrorType.invalidPassword,
            message: 'Mot de passe incorrect. Vérifiez votre mot de passe.',
            statusCode: 401,
          );
        }
        if (serverCode == 'IDENTIFIER_NOT_FOUND') {
          throw const ApiException(
            type: ApiErrorType.invalidIdentifier,
            message:
                'Email ou téléphone introuvable. Vérifiez votre identifiant.',
            statusCode: 401,
          );
        }
        throw const ApiException(
          type: ApiErrorType.invalidCredentials,
          message: 'Email, téléphone ou mot de passe incorrect.',
          statusCode: 401,
        );
      }

      if (response.statusCode >= 500) {
        throw ApiException(
          type: ApiErrorType.serverUnavailable,
          message:
              'Le serveur ne répond pas pour le moment. Veuillez réessayer plus tard.',
          statusCode: response.statusCode,
        );
      }

      throw ApiException(
        type: ApiErrorType.request,
        message:
            responseData['error']?.toString() ??
            'Impossible de se connecter (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } on TimeoutException catch (error) {
      print('❌ Timeout login: $error');
      throw const ApiException(
        type: ApiErrorType.serverUnavailable,
        message:
            'Le serveur ne répond pas pour le moment. Veuillez réessayer plus tard.',
      );
    } catch (error) {
      print('❌ Erreur réseau login: $error');
      throw const ApiException(
        type: ApiErrorType.network,
        message:
            'Impossible de contacter le serveur. Vérifiez votre connexion internet.',
      );
    }
  }

  static Future<Map<String, dynamic>> register(
    String firstName,
    String lastName,
    String email,
    String phone,
    String password,
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
            final errorMessages = errors
                .map((e) => e['msg'] ?? e['message'] ?? 'Erreur inconnue')
                .join(', ');
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
      throw Exception(
        'Impossible de contacter le serveur. Vérifiez votre connexion internet.',
      );
    }
  }

  static Future<Map<String, dynamic>> getMe() async {
    final token = await ensureAuthenticated();
    if (token == null)
      throw const ApiException(
        type: ApiErrorType.request,
        message: 'Session requise. Veuillez vous reconnecter.',
      );

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

  /// Récupérer les comptes clients et leurs coordonnées (admin uniquement).
  /// Le mot de passe et son hash ne sont jamais renvoyés par cette route.
  static Future<List<AdminClient>> getAdminClients() async {
    final token = await ensureAuthenticated();
    if (token == null) {
      throw const ApiException(
        type: ApiErrorType.request,
        message: 'Session administrateur requise.',
      );
    }

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/users/clients'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic> || decoded['clients'] is! List) {
          throw const ApiException(
            type: ApiErrorType.request,
            message: 'Réponse de la liste clients invalide.',
          );
        }

        return (decoded['clients'] as List<dynamic>)
            .whereType<Map>()
            .map(
              (item) => AdminClient.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((client) => client.id.isNotEmpty && client.role != 'admin')
            .toList(growable: false);
      }

      Map<String, dynamic> errorBody = <String, dynamic>{};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) errorBody = decoded;
      } on FormatException {
        // Le message générique est utilisé pour les réponses non JSON.
      }

      throw ApiException(
        type: response.statusCode >= 500
            ? ApiErrorType.serverUnavailable
            : ApiErrorType.request,
        message:
            errorBody['error']?.toString() ??
            'Impossible de charger les clients.',
        statusCode: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        type: ApiErrorType.serverUnavailable,
        message:
            'Le serveur ne répond pas pour le moment. Réessayez plus tard.',
      );
    } catch (_) {
      throw const ApiException(
        type: ApiErrorType.network,
        message:
            'Impossible de contacter le serveur. Vérifiez votre connexion internet.',
      );
    }
  }

  /// Récupérer le répertoire minimal et anonymisé (admin uniquement).
  ///
  /// Le backend ne renvoie jamais l'e-mail brut, le téléphone, les noms ou le
  /// hash du mot de passe. Ne pas journaliser le corps de cette réponse.
  static Future<List<AnonymizedUser>> getAnonymizedUsers() async {
    final token = await ensureAuthenticated();
    if (token == null) {
      print('❌ [getAnonymizedUsers] Token manquant');
      throw const ApiException(
        type: ApiErrorType.request,
        message: 'Session administrateur requise.',
      );
    }

    print('📡 [getAnonymizedUsers] URL: $baseUrl/users');
    print(
      '📡 [getAnonymizedUsers] Token: ${token.substring(0, token.length > 10 ? 10 : token.length)}...',
    );

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/users'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      print('📡 [getAnonymizedUsers] Status: ${response.statusCode}');
      print(
        '📡 [getAnonymizedUsers] Body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}',
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic> || decoded['users'] is! List) {
          throw const ApiException(
            type: ApiErrorType.request,
            message: 'Réponse du répertoire invalide.',
          );
        }

        final users = (decoded['users'] as List<dynamic>)
            .whereType<Map>()
            .map(
              (item) =>
                  AnonymizedUser.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((user) => user.id.isNotEmpty)
            .toList(growable: false);

        return users;
      }

      Map<String, dynamic> errorBody = <String, dynamic>{};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) errorBody = decoded;
      } on FormatException {
        // Le message générique est utilisé pour les réponses non JSON.
      }

      throw ApiException(
        type: response.statusCode >= 500
            ? ApiErrorType.serverUnavailable
            : ApiErrorType.request,
        message:
            errorBody['error']?.toString() ??
            'Impossible de charger le répertoire anonymisé.',
        statusCode: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } on TimeoutException catch (e) {
      print('❌ [getAnonymizedUsers] Timeout: $e');
      throw const ApiException(
        type: ApiErrorType.serverUnavailable,
        message:
            'Le serveur ne répond pas pour le moment. Veuillez réessayer plus tard.',
      );
    } catch (e) {
      print('❌ [getAnonymizedUsers] Network/catch error: $e');
      throw const ApiException(
        type: ApiErrorType.network,
        message:
            'Impossible de contacter le serveur. Vérifiez votre connexion internet.',
      );
    }
  }

  static Future<Map<String, dynamic>> createLocationRequest(
    int appareilId,
    String dateDebut,
    String dateFin,
    int nombreJours,
    int total,
  ) async {
    // DEPRECATED: redirige vers createLocation standard
    print('⚠️ createLocationRequest deprecated → createLocation');
    return await createLocation(
      appareilId,
      dateDebut.split('T')[0],
      dateFin.split('T')[0],
    );
  }

  // ============================================
  // FONCTIONS: Réinitialisation du mot de passe
  // ============================================

  /// Demander un code de réinitialisation de mot de passe
  static Future<Map<String, dynamic>> requestPasswordReset(
    String contact,
    String contactType,
  ) async {
    try {
      print(
        '📡 Envoi requête forgot-password vers: $baseUrl/auth/forgot-password',
      );
      print('📡 Données: contact=$contact, contactType=$contactType');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'contact': contact, 'contactType': contactType}),
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
        throw Exception(
          errorData['error'] ?? 'Erreur lors de la demande de réinitialisation',
        );
      }
    } catch (e) {
      if (e is Exception) {
        print('❌ Erreur forgot-password: $e');
        rethrow;
      }
      print('❌ Erreur réseau forgot-password: $e');
      throw Exception(
        'Impossible de contacter le serveur. Vérifiez votre connexion internet.',
      );
    }
  }

  /// Vérifier le code de réinitialisation
  static Future<Map<String, dynamic>> verifyResetCode(
    String code,
    String contact,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code, 'contact': contact}),
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
      throw Exception(
        'Impossible de contacter le serveur. Vérifiez votre connexion internet.',
      );
    }
  }

  /// Réinitialiser le mot de passe
  static Future<Map<String, dynamic>> resetPassword(String newPassword) async {
    try {
      final tempToken = await getTempToken();
      if (tempToken == null) {
        throw Exception(
          'Session de réinitialisation expirée. Veuillez recommencer.',
        );
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'tempToken': tempToken, 'newPassword': newPassword}),
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
        throw Exception(
          errorData['error'] ??
              'Erreur lors de la réinitialisation du mot de passe',
        );
      }
    } catch (e) {
      if (e is Exception) rethrow;
      print('❌ Erreur réseau reset-password: $e');
      throw Exception(
        'Impossible de contacter le serveur. Vérifiez votre connexion internet.',
      );
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
  static Future<List<Map<String, dynamic>>> getLocations({
    String? statut,
  }) async {
    final token = await ensureAuthenticated();
    if (token == null)
      throw const ApiException(
        type: ApiErrorType.request,
        message: 'Session requise. Veuillez vous reconnecter.',
      );

    String url = '$baseUrl/locations';
    if (statut != null) {
      url += '?statut=$statut';
    }

    print('📡 API getLocations: $url');

    final response = await http
        .get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 15));

    print('📡 getLocations status: ${response.statusCode}');
    print('📡 getLocations body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final locations = List<Map<String, dynamic>>.from(data['locations']);

      // Mapping des champs pour compatibilite backend/frontend
      for (var loc in locations) {
        loc['clientNom'] = loc['clientNom'] ?? loc['client'] ?? 'Inconnu';
        loc['appareilNom'] =
            loc['appareilNom'] ?? loc['appareil'] ?? 'Appareil inconnu';
        loc['clientTelephone'] =
            loc['clientTelephone'] ?? loc['clientPhone'] ?? '';
        loc['imageUrl'] = loc['imageUrl'] ?? loc['appareilImage'] ?? '';
      }

      print('📦 Locations parsées: ${locations.length} éléments');
      for (var i = 0; i < locations.length; i++) {
        final loc = locations[i];
        print(
          '  [$i] id=${loc['id']} statut=${loc['statut']} client=${loc['clientNom']} appareil=${loc['appareilNom']}',
        );
      }
      return locations;
    } else {
      throw Exception(
        jsonDecode(response.body)['error'] ??
            'Erreur lors de la récupération des locations',
      );
    }
  }

  /// Expirer les locations arrivées à leur terme (admin uniquement).
  static Future<void> checkExpiredLocations() async {
    final token = await ensureAuthenticated();
    if (token == null) {
      throw const ApiException(
        type: ApiErrorType.request,
        message: 'Session administrateur requise.',
      );
    }

    final response = await http
        .get(
          Uri.parse('$baseUrl/locations/check-expired'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      throw ApiException(
        type: ApiErrorType.request,
        message: 'Impossible de vérifier les locations arrivées à terme.',
        statusCode: response.statusCode,
      );
    }
  }

  /// Récupérer tout le registre des locations (admin uniquement).
  static Future<List<Map<String, dynamic>>> getAdminLocations() async {
    final token = await ensureAuthenticated();
    if (token == null) {
      throw const ApiException(
        type: ApiErrorType.request,
        message: 'Session administrateur requise.',
      );
    }

    final response = await http
        .get(
          Uri.parse('$baseUrl/locations/admin'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));

    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200 &&
        decoded is Map<String, dynamic> &&
        decoded['locations'] is List) {
      return List<Map<String, dynamic>>.from(decoded['locations']);
    }

    final message = decoded is Map<String, dynamic>
        ? decoded['error']?.toString()
        : null;
    throw ApiException(
      type: response.statusCode >= 500
          ? ApiErrorType.serverUnavailable
          : ApiErrorType.request,
      message: message ?? 'Impossible de charger les locations.',
      statusCode: response.statusCode,
    );
  }

  /// Terminer une location et libérer son appareil (admin).
  static Future<Map<String, dynamic>?> terminateLocation(int locationId) async {
    final token = await ensureAuthenticated();
    if (token == null) {
      throw const ApiException(
        type: ApiErrorType.request,
        message: 'Session administrateur requise.',
      );
    }

    final response = await http
        .patch(
          Uri.parse('$baseUrl/locations/$locationId/terminer'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));

    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
      return decoded;
    }

    final message = decoded is Map<String, dynamic>
        ? decoded['error']?.toString()
        : null;
    throw ApiException(
      type: response.statusCode >= 500
          ? ApiErrorType.serverUnavailable
          : ApiErrorType.request,
      message: message ?? 'Impossible de terminer cette location.',
      statusCode: response.statusCode,
    );
  }

  /// Rejeter une location (admin)
  static Future<Map<String, dynamic>?> rejectLocation(
    int locationId,
    String raison,
  ) async {
    final token = await ensureAuthenticated();
    if (token == null)
      throw const ApiException(
        type: ApiErrorType.request,
        message: 'Session requise. Veuillez vous reconnecter.',
      );

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
      throw Exception(
        jsonDecode(response.body)['error'] ??
            'Erreur lors du rejet de la location',
      );
    }
  }

  /// Approuver une location (admin)
  static Future<Map<String, dynamic>?> approveLocation(int locationId) async {
    final token = await ensureAuthenticated();
    if (token == null)
      throw const ApiException(
        type: ApiErrorType.request,
        message: 'Session requise. Veuillez vous reconnecter.',
      );

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
      throw Exception(
        jsonDecode(response.body)['error'] ??
            'Erreur lors de l\'approbation de la location',
      );
    }
  }

  /// Récupérer toutes les demandes d'achat de l'utilisateur connecté
  static Future<List<Map<String, dynamic>>> getDemandesAchat({
    String? statut,
  }) async {
    final token = await ensureAuthenticated();
    if (token == null)
      throw const ApiException(
        type: ApiErrorType.request,
        message: 'Session requise. Veuillez vous reconnecter.',
      );

    String url = '$baseUrl/demandes';
    if (statut != null) {
      url += '?statut=$statut';
    }

    print('📡 API getDemandesAchat: $url');

    try {
      final response = await http
          .get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));

      print('📡 getDemandesAchat status: ${response.statusCode}');
      print('📡 getDemandesAchat body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['demandes']);
      } else {
        throw Exception(
          jsonDecode(response.body)['error'] ??
              'Erreur lors de la récupération des demandes',
        );
      }
    } on TimeoutException {
      throw const ApiException(
        type: ApiErrorType.serverUnavailable,
        message:
            'Le serveur ne répond pas pour le moment. Veuillez réessayer plus tard.',
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        type: ApiErrorType.network,
        message:
            'Impossible de contacter le serveur. Vérifiez votre connexion internet.',
      );
    }
  }

  /// Créer une demande d'achat
  static Future<Map<String, dynamic>> createDemandeAchat(
    int appareilId,
    int quantite,
  ) async {
    final token = await ensureAuthenticated();
    if (token == null)
      throw const ApiException(
        type: ApiErrorType.request,
        message: 'Session requise. Veuillez vous reconnecter.',
      );

    final response = await http.post(
      Uri.parse('$baseUrl/demandes'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'appareilId': appareilId, 'quantite': quantite}),
    );

    print('📡 createDemandeAchat status: ${response.statusCode}');
    print('📡 createDemandeAchat body: ${response.body}');

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        jsonDecode(response.body)['error'] ??
            'Erreur lors de la création de la demande',
      );
    }
  }

  /// Modifier le statut d'une demande d'achat (admin)
  static Future<Map<String, dynamic>> updateDemandeAchatStatut(
    int demandeId,
    String statut, {
    String? commentaire,
  }) async {
    final token = await ensureAuthenticated();
    if (token == null)
      throw const ApiException(
        type: ApiErrorType.request,
        message: 'Session requise. Veuillez vous reconnecter.',
      );

    final response = await http.patch(
      Uri.parse('$baseUrl/demandes/$demandeId/statut'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'statut': statut,
        if (commentaire != null && commentaire.trim().isNotEmpty)
          'commentaire': commentaire.trim(),
      }),
    );

    print('📡 updateDemandeAchatStatut status: ${response.statusCode}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    final errorBody = jsonDecode(response.body);
    throw Exception(
      errorBody['error'] ?? 'Erreur lors de la mise à jour de la demande',
    );
  }

  /// Récupérer les appareils disponibles
  static Future<List<Map<String, dynamic>>> getAppareils({
    bool? disponible,
  }) async {
    final token = await ensureAuthenticated();
    if (token == null)
      throw const ApiException(
        type: ApiErrorType.request,
        message: 'Session requise. Veuillez vous reconnecter.',
      );

    String url = '$baseUrl/appareils';
    if (disponible != null) {
      url += disponible ? '?disponible=true' : '?disponible=false';
    }

    print('📡 API getAppareils: $url');

    try {
      final response = await http
          .get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));

      print('📡 getAppareils status: ${response.statusCode}');
      print('📡 getAppareils body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['appareils']);
      } else {
        throw Exception(
          jsonDecode(response.body)['error'] ??
              'Erreur lors de la récupération des appareils',
        );
      }
    } on TimeoutException {
      throw const ApiException(
        type: ApiErrorType.serverUnavailable,
        message:
            'Le serveur ne répond pas pour le moment. Veuillez réessayer plus tard.',
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        type: ApiErrorType.network,
        message:
            'Impossible de contacter le serveur. Vérifiez votre connexion internet.',
      );
    }
  }

  /// Créer une location
  static Future<Map<String, dynamic>> createLocation(
    int appareilId,
    String dateDebut,
    String dateFin,
  ) async {
    final token = await ensureAuthenticated();
    if (token == null)
      throw Exception('Not authenticated - Veuillez vous reconnecter');

    print('📡 API createLocation called with:');
    print('   - appareilId: $appareilId (type: ${appareilId.runtimeType})');
    print('   - dateDebut: $dateDebut');
    print('   - dateFin: $dateFin');

    final response = await http.post(
      Uri.parse('$baseUrl/locations'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
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
      final result = jsonDecode(response.body);
      print('✅ Location created successfully: ${result['location']?['code']}');
      return result;
    } else {
      final errorBody = jsonDecode(response.body);
      final errorMsg =
          errorBody['error'] ?? errorBody['message'] ?? 'Erreur inconnue';
      print('❌ createLocation failed: $errorMsg');
      throw Exception(errorMsg);
    }
  }

  /// Supprimer une location terminée ou rejétée
  static Future<void> deleteLocation(int locationId) async {
    final token = await ensureAuthenticated();
    final response = await http.delete(
      Uri.parse('$baseUrl/locations/$locationId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print('📡 deleteLocation status: ${response.statusCode}');

    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    } else {
      final errorBody = jsonDecode(response.body);
      final errorMsg =
          errorBody['error'] ?? errorBody['message'] ?? 'Erreur inconnue';
      print('❌ deleteLocation failed: $errorMsg');
      throw Exception(errorMsg);
    }
  }

  /// Supprimer une demande d'achat terminée ou rejétée
  static Future<void> deleteDemande(int demandeId) async {
    final token = await ensureAuthenticated();
    final response = await http.delete(
      Uri.parse('$baseUrl/demandes/$demandeId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print('📡 deleteDemande status: ${response.statusCode}');

    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    } else {
      final errorBody = jsonDecode(response.body);
      final errorMsg =
          errorBody['error'] ?? errorBody['message'] ?? 'Erreur inconnue';
      print('❌ deleteDemande failed: $errorMsg');
      throw Exception(errorMsg);
    }
  }

  /// Créer un nouvel appareil (admin only)
  static Future<Map<String, dynamic>> createAppareil({
    required String nom,
    required String type,
    required int prixLocation,
    required int prixVente,
    String? imageUrl,
  }) async {
    final token = await ensureAuthenticated();
    if (token == null)
      throw Exception('Not authenticated - Veuillez vous reconnecter');

    print('📡 API createAppareil called with:');
    print('   - nom: $nom');
    print('   - type: $type');
    print('   - prixLocation: $prixLocation');
    print('   - prixVente: $prixVente');

    final response = await http.post(
      Uri.parse('$baseUrl/appareils'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'nom': nom,
        'type': type,
        'prixLocation': prixLocation,
        'prixVente': prixVente,
        'imageUrl': imageUrl,
      }),
    );

    print('📡 createAppareil status: ${response.statusCode}');
    print('📡 createAppareil body: ${response.body}');

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      print('✅ Appareil créé: ${data['appareil']?['code']}');
      return data;
    } else {
      final errorBody = jsonDecode(response.body);
      final errorMsg =
          errorBody['error'] ?? errorBody['message'] ?? 'Erreur inconnue';
      print('❌ createAppareil failed: $errorMsg');
      throw Exception(errorMsg);
    }
  }

  /// Soumettre une demande de devis.
  /// La route est publique : le jeton est envoyé s'il existe, afin que le devis
  /// soit rattaché au compte connecté. Sans jeton, la demande reste anonyme.
  static Future<Map<String, dynamic>> createDevis({
    required String serviceId,
    required String serviceName,
    required String description,
    required String nom,
    required String telephone,
    String? email,
  }) async {
    try {
      print('📡 API createDevis called with:');
      print('   - serviceId: $serviceId');
      print('   - serviceName: $serviceName');
      print('   - nom: $nom');

      final payload = <String, dynamic>{
        'serviceId': serviceId,
        'serviceName': serviceName,
        'description': description,
        'nom': nom,
        'telephone': telephone,
      };
      final normalizedEmail = email?.trim();
      if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
        payload['email'] = normalizedEmail;
      }

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.post(
        Uri.parse('$baseUrl/devis'),
        headers: headers,
        body: jsonEncode(payload),
      );

      print('📡 createDevis status: ${response.statusCode}');
      print('📡 createDevis body: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print(
          '✅ Devis créé: ${data['devis']?['id']} '
          '(lié au compte: ${data['lieAuCompte'] == true})',
        );
        return data;
      } else {
        final errorBody = jsonDecode(response.body);
        final errorMsg =
            errorBody['error'] ?? errorBody['message'] ?? 'Erreur inconnue';
        print('❌ createDevis failed: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (e is Exception) rethrow;
      print('❌ Erreur réseau createDevis: $e');
      throw Exception(
        'Impossible de contacter le serveur. Vérifiez votre connexion internet.',
      );
    }
  }

  /// Approuver une demande de devis (admin)
  static Future<Map<String, dynamic>> approveDevis(int devisId) async {
    final token = await ensureAuthenticated();
    if (token == null)
      throw const ApiException(
        type: ApiErrorType.request,
        message: 'Session requise. Veuillez vous reconnecter.',
      );

    final response = await http.patch(
      Uri.parse('$baseUrl/devis/$devisId/approuver'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print('📡 approveDevis status: ${response.statusCode}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    final errorBody = jsonDecode(response.body);
    throw Exception(
      errorBody['error'] ?? 'Erreur lors de l\'approbation du devis',
    );
  }

  /// Rejeter une demande de devis (admin)
  static Future<Map<String, dynamic>> rejectDevis(
    int devisId,
    String raison,
  ) async {
    final token = await ensureAuthenticated();
    if (token == null)
      throw const ApiException(
        type: ApiErrorType.request,
        message: 'Session requise. Veuillez vous reconnecter.',
      );

    final response = await http.patch(
      Uri.parse('$baseUrl/devis/$devisId/rejeter'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'raison': raison.trim()}),
    );

    print('📡 rejectDevis status: ${response.statusCode}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    final errorBody = jsonDecode(response.body);
    throw Exception(errorBody['error'] ?? 'Erreur lors du rejet du devis');
  }

  /// Modifier le statut d'un devis sans transition d'approbation spécifique (admin)
  static Future<Map<String, dynamic>> updateDevisStatut(
    int devisId,
    String statut,
  ) async {
    final token = await ensureAuthenticated();
    if (token == null)
      throw const ApiException(
        type: ApiErrorType.request,
        message: 'Session requise. Veuillez vous reconnecter.',
      );

    final response = await http.patch(
      Uri.parse('$baseUrl/devis/$devisId/statut'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'statut': statut}),
    );

    print('📡 updateDevisStatut status: ${response.statusCode}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    final errorBody = jsonDecode(response.body);
    throw Exception(
      errorBody['error'] ?? 'Erreur lors de la mise à jour du statut',
    );
  }

  /// Modifier un appareil existant (admin only)
  static Future<Map<String, dynamic>> updateAppareil({
    required int id,
    String? nom,
    String? type,
    int? prixLocation,
    int? prixVente,
    String? imageUrl,
  }) async {
    final token = await ensureAuthenticated();
    if (token == null)
      throw Exception('Not authenticated - Veuillez vous reconnecter');

    print('📡 API updateAppareil called with:');
    print('   - id: $id');
    print('   - imageUrl: $imageUrl');

    final response = await http.put(
      Uri.parse('$baseUrl/appareils/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'nom': nom,
        'type': type,
        'prixLocation': prixLocation,
        'prixVente': prixVente,
        'imageUrl': imageUrl,
      }),
    );

    print('📡 updateAppareil status: ${response.statusCode}');
    print('📡 updateAppareil body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('✅ Appareil modifié: ${data['appareil']?['code']}');
      return data;
    } else {
      final errorBody = jsonDecode(response.body);
      final errorMsg =
          errorBody['error'] ?? errorBody['message'] ?? 'Erreur inconnue';
      print('❌ updateAppareil failed: $errorMsg');
      throw Exception(errorMsg);
    }
  }

  /// Supprimer un appareil (admin only)
  static Future<void> deleteAppareil(int id) async {
    final token = await ensureAuthenticated();
    if (token == null)
      throw const ApiException(
        type: ApiErrorType.request,
        message: 'Session requise. Veuillez vous reconnecter.',
      );

    final response = await http.delete(
      Uri.parse('$baseUrl/appareils/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print('📡 deleteAppareil status: ${response.statusCode}');

    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    } else {
      final errorBody = jsonDecode(response.body);
      final errorMsg =
          errorBody['error'] ?? errorBody['message'] ?? 'Erreur inconnue';
      print('❌ deleteAppareil failed: $errorMsg');
      throw Exception(errorMsg);
    }
  }

  /// Récupérer les demandes de devis (admin)
  static Future<List<Map<String, dynamic>>> getDevis({String? statut}) async {
    final token = await ensureAuthenticated();
    if (token == null)
      throw const ApiException(
        type: ApiErrorType.request,
        message: 'Session requise. Veuillez vous reconnecter.',
      );

    String url = '$baseUrl/devis';
    if (statut != null) {
      url += '?statut=$statut';
    }

    print('📡 API getDevis: $url');

    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      print('📡 getDevis status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['devis']);
      } else {
        throw Exception(
          jsonDecode(response.body)['error'] ??
              'Erreur lors de la récupération des devis',
        );
      }
    } on TimeoutException {
      throw const ApiException(
        type: ApiErrorType.serverUnavailable,
        message:
            'Le serveur ne répond pas pour le moment. Veuillez réessayer plus tard.',
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        type: ApiErrorType.network,
        message:
            'Impossible de contacter le serveur. Vérifiez votre connexion internet.',
      );
    }
  }

  /// Récupérer les devis rattachés au compte connecté (client)
  static Future<List<Map<String, dynamic>>> getMyDevis() async {
    final token = await ensureAuthenticated();
    if (token == null)
      throw const ApiException(
        type: ApiErrorType.request,
        message: 'Session requise. Veuillez vous reconnecter.',
      );

    print('📡 API getMyDevis');

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/devis/me'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      print('📡 getMyDevis status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['devis'] ?? []);
      } else {
        throw Exception(
          jsonDecode(response.body)['error'] ??
              'Erreur lors de la récupération de vos devis',
        );
      }
    } on TimeoutException {
      throw const ApiException(
        type: ApiErrorType.serverUnavailable,
        message:
            'Le serveur ne répond pas pour le moment. Veuillez réessayer plus tard.',
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        type: ApiErrorType.network,
        message:
            'Impossible de contacter le serveur. Vérifiez votre connexion internet.',
      );
    }
  }

  /// Supprimer un devis (admin)
  static Future<void> deleteDevis(int devisId) async {
    final token = await ensureAuthenticated();
    if (token == null)
      throw const ApiException(
        type: ApiErrorType.request,
        message: 'Session requise. Veuillez vous reconnecter.',
      );

    final response = await http.delete(
      Uri.parse('$baseUrl/devis/$devisId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print('📡 deleteDevis status: ${response.statusCode}');

    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    } else {
      final errorBody = jsonDecode(response.body);
      final errorMsg =
          errorBody['error'] ?? errorBody['message'] ?? 'Erreur inconnue';
      print('❌ deleteDevis failed: $errorMsg');
      throw Exception(errorMsg);
    }
  }

  // ============================================
  // FONCTIONS: Promotions (admin)
  // ============================================

  /// Récupérer toutes les promotions (admin)
  static Future<List<Map<String, dynamic>>> getPromotions() async {
    final token = await ensureAuthenticated();
    if (token == null)
      throw const ApiException(
        type: ApiErrorType.request,
        message: 'Session requise. Veuillez vous reconnecter.',
      );

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/promotions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      print('📡 getPromotions status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['promotions']);
      } else {
        throw Exception(
          jsonDecode(response.body)['error'] ??
              'Erreur lors de la récupération des promotions',
        );
      }
    } on TimeoutException {
      throw const ApiException(
        type: ApiErrorType.serverUnavailable,
        message:
            'Le serveur ne répond pas pour le moment. Veuillez réessayer plus tard.',
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        type: ApiErrorType.network,
        message:
            'Impossible de contacter le serveur. Vérifiez votre connexion internet.',
      );
    }
  }

  /// Créer une promotion (admin)
  static Future<Map<String, dynamic>> createPromotion(
    Map<String, dynamic> promotionData,
  ) async {
    final token = await ensureAuthenticated();
    if (token == null)
      throw const ApiException(
        type: ApiErrorType.request,
        message: 'Session requise. Veuillez vous reconnecter.',
      );

    final response = await http.post(
      Uri.parse('$baseUrl/promotions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(promotionData),
    );

    print('📡 createPromotion status: ${response.statusCode}');

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception(
        errorBody['error'] ?? 'Erreur lors de la création de la promotion',
      );
    }
  }

  /// Activer/désactiver une promotion (admin)
  static Future<Map<String, dynamic>> togglePromotion(
    int promotionId,
    bool activate,
  ) async {
    final token = await ensureAuthenticated();
    if (token == null)
      throw const ApiException(
        type: ApiErrorType.request,
        message: 'Session requise. Veuillez vous reconnecter.',
      );

    final response = await http.patch(
      Uri.parse('$baseUrl/promotions/$promotionId/toggle'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'actif': activate}),
    );

    print('📡 togglePromotion status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception(
        errorBody['error'] ?? 'Erreur lors de la mise à jour de la promotion',
      );
    }
  }

  /// Supprimer une promotion (admin)
  static Future<void> deletePromotion(int promotionId) async {
    final token = await ensureAuthenticated();
    if (token == null)
      throw const ApiException(
        type: ApiErrorType.request,
        message: 'Session requise. Veuillez vous reconnecter.',
      );

    final response = await http.delete(
      Uri.parse('$baseUrl/promotions/$promotionId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print('📡 deletePromotion status: ${response.statusCode}');

    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    } else {
      final errorBody = jsonDecode(response.body);
      final errorMsg =
          errorBody['error'] ?? errorBody['message'] ?? 'Erreur inconnue';
      print('❌ deletePromotion failed: $errorMsg');
      throw Exception(errorMsg);
    }
  }

  /// Récupérer la promotion active à afficher (client)
  static Future<Map<String, dynamic>?> getActivePromotion() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/promotions/active'));

      print('📡 getActivePromotion status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['promotion'];
      }
      return null;
    } catch (e) {
      print('❌ getActivePromotion error: $e');
      return null;
    }
  }
}
