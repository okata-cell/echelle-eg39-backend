import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_service.dart';

class ProfileApiException implements Exception {
  const ProfileApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ProfileRecord {
  const ProfileRecord({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.company,
    required this.address,
    required this.city,
    required this.country,
    required this.role,
    this.avatarData,
    this.avatarMimeType,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String company;
  final String address;
  final String city;
  final String country;
  final String role;
  final String? avatarData;
  final String? avatarMimeType;

  String get fullName =>
      [firstName, lastName].where((name) => name.trim().isNotEmpty).join(' ');

  factory ProfileRecord.fromJson(Map<String, dynamic> json) {
    return ProfileRecord(
      id: (json['id'] as num).toInt(),
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      company: json['company']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      country: json['country']?.toString() ?? 'Togo',
      role: json['role']?.toString() ?? 'client',
      avatarData: json['avatarData']?.toString(),
      avatarMimeType: json['avatarMimeType']?.toString(),
    );
  }
}

class ProfileImageAttachment {
  const ProfileImageAttachment({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

class ProfileApi {
  ProfileApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _ownsClient = client == null,
      _baseUrl = baseUrl ?? ApiService.baseUrl;

  static const maxAvatarBytes = 1024 * 1024;
  static const maxSupportAttachmentBytes = 2 * 1024 * 1024;
  static const maxSupportAttachmentCount = 3;

  final http.Client _client;
  final bool _ownsClient;
  final String _baseUrl;

  void dispose() {
    if (_ownsClient) _client.close();
  }

  Future<ProfileRecord> loadProfile() async {
    final response = await _send('GET', '/profile/me');
    final profile = response['profile'];
    if (profile is! Map) {
      throw const ProfileApiException('Réponse du profil invalide.');
    }
    return ProfileRecord.fromJson(Map<String, dynamic>.from(profile));
  }

  Future<ProfileRecord> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String company,
    required String address,
    required String city,
    required String country,
    String? currentPassword,
  }) async {
    final response = await _send(
      'PATCH',
      '/profile/me',
      body: {
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'company': company.trim(),
        'address': address.trim(),
        'city': city.trim(),
        'country': country.trim(),
        if (currentPassword != null && currentPassword.isNotEmpty)
          'currentPassword': currentPassword,
      },
    );

    final token = response['token'];
    if (token is String && token.isNotEmpty) {
      await ApiService.setToken(token);
    }

    final profile = response['profile'];
    if (profile is! Map) {
      throw const ProfileApiException(
        'Réponse de mise à jour du profil invalide.',
      );
    }
    return ProfileRecord.fromJson(Map<String, dynamic>.from(profile));
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _send(
      'POST',
      '/profile/password',
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  Future<ProfileRecord> updateAvatar({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (bytes.isEmpty || bytes.lengthInBytes > maxAvatarBytes) {
      throw const ProfileApiException('La photo doit peser 1 Mo maximum.');
    }

    final response = await _send(
      'PUT',
      '/profile/me/avatar',
      body: {
        'image': {'mimeType': mimeType, 'data': base64Encode(bytes)},
      },
    );
    final profile = response['profile'];
    if (profile is! Map) {
      throw const ProfileApiException('Réponse de la photo invalide.');
    }
    return ProfileRecord.fromJson(Map<String, dynamic>.from(profile));
  }

  Future<void> deleteAvatar() async {
    await _send('DELETE', '/profile/me/avatar');
  }

  Future<void> submitSupportMessage({
    required String message,
    List<ProfileImageAttachment> attachments = const [],
  }) async {
    final totalBytes = attachments.fold<int>(
      0,
      (total, image) => total + image.bytes.lengthInBytes,
    );
    if (attachments.length > maxSupportAttachmentCount ||
        totalBytes > maxSupportAttachmentBytes) {
      throw const ProfileApiException(
        'Ajoutez au maximum 3 images, pour un total de 2 Mo.',
      );
    }

    await _send(
      'POST',
      '/profile/support-messages',
      body: {
        'message': message.trim(),
        'attachments': attachments
            .map(
              (image) => {
                'mimeType': image.mimeType,
                'data': base64Encode(image.bytes),
              },
            )
            .toList(growable: false),
      },
    );
  }

  Future<void> registerTrainingInterest({
    required String trainingName,
    String message = '',
  }) async {
    await _send(
      'POST',
      '/profile/training-interests',
      body: {'trainingName': trainingName, 'message': message.trim()},
    );
  }

  Future<void> submitRating({required int rating, String comment = ''}) async {
    await _send(
      'POST',
      '/profile/ratings',
      body: {'rating': rating, 'comment': comment.trim()},
    );
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final token = await ApiService.ensureAuthenticated();
    if (token == null) {
      throw const ProfileApiException(
        'Votre session a expiré. Reconnectez-vous pour continuer.',
        statusCode: 401,
      );
    }

    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };

    late final http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _client
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 15));
          break;
        case 'POST':
          response = await _client
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 30));
          break;
        case 'PATCH':
          response = await _client
              .patch(uri, headers: headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 15));
          break;
        case 'PUT':
          response = await _client
              .put(uri, headers: headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 30));
          break;
        case 'DELETE':
          response = await _client
              .delete(uri, headers: headers)
              .timeout(const Duration(seconds: 15));
          break;
        default:
          throw const ProfileApiException('Méthode non prise en charge.');
      }
    } on TimeoutException {
      throw const ProfileApiException(
        'Le serveur ne répond pas. Réessayez plus tard.',
      );
    } on http.ClientException {
      throw const ProfileApiException(
        'Impossible de contacter le serveur. Vérifiez votre connexion.',
      );
    } on ProfileApiException {
      rethrow;
    } catch (_) {
      throw const ProfileApiException(
        'Impossible de contacter le serveur. Vérifiez votre connexion.',
      );
    }

    final decoded = ApiService.decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ProfileApiException(
        decoded?['error']?.toString() ?? 'La demande n’a pas pu aboutir.',
        statusCode: response.statusCode,
      );
    }
    if (decoded == null) {
      throw const ProfileApiException('Réponse du serveur invalide.');
    }
    return decoded;
  }
}
