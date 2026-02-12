# 📱 Guide d'intégration Flutter avec l'API Backend

## 🎯 Vue d'ensemble

Ce guide explique comment connecter votre application Flutter ÉCHELLE EG39 au backend API déployé sur Render.

## 📦 Dépendances Flutter requises

Ajoutez dans votre `pubspec.yaml` :

```yaml
dependencies:
  http: ^1.1.0
  shared_preferences: ^2.2.2
  provider: ^6.1.1
```

Puis exécutez :
```bash
flutter pub get
```

## 🔧 Configuration

### 1. Créer le fichier de configuration API

Créez `lib/services/api_config.dart` :

```dart
class ApiConfig {
  // URL de votre API déployée sur Render
  static const String baseUrl = 'https://echelle-eg39-api.onrender.com/api';
  
  // En développement local, utilisez :
  // static const String baseUrl = 'http://localhost:3000/api';
  
  static const Duration timeout = Duration(seconds: 30);
}
```

### 2. Créer le service d'authentification

Créez `lib/services/auth_service.dart` :

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  // Inscription
  Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'password': password,
      }),
    ).timeout(ApiConfig.timeout);

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      // Sauvegarder le token et les infos utilisateur
      await _saveAuthData(data['token'], data['user']);
      return data;
    } else {
      throw Exception(data['error'] ?? 'Erreur d\'inscription');
    }
  }

  // Connexion
  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identifier': identifier,
        'password': password,
      }),
    ).timeout(ApiConfig.timeout);

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      await _saveAuthData(data['token'], data['user']);
      return data;
    } else {
      throw Exception(data['error'] ?? 'Identifiants invalides');
    }
  }

  // Déconnexion
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  // Obtenir le token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Obtenir les infos utilisateur
  Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);
    if (userData != null) {
      return jsonDecode(userData);
    }
    return null;
  }

  // Vérifier si connecté
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  // Sauvegarder les données d'auth
  Future<void> _saveAuthData(String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user));
  }
}
```

### 3. Créer le service API générique

Créez `lib/services/api_service.dart` :

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';

class ApiService {
  final AuthService _authService = AuthService();

  // Headers avec authentification
  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // GET Request
  Future<dynamic> get(String endpoint) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}$endpoint'),
      headers: headers,
    ).timeout(ApiConfig.timeout);

    return _handleResponse(response);
  }

  // POST Request
  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}$endpoint'),
      headers: headers,
      body: jsonEncode(body),
    ).timeout(ApiConfig.timeout);

    return _handleResponse(response);
  }

  // PUT Request
  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}$endpoint'),
      headers: headers,
      body: jsonEncode(body),
    ).timeout(ApiConfig.timeout);

    return _handleResponse(response);
  }

  // PATCH Request
  Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}$endpoint'),
      headers: headers,
      body: jsonEncode(body),
    ).timeout(ApiConfig.timeout);

    return _handleResponse(response);
  }

  // DELETE Request
  Future<dynamic> delete(String endpoint) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}$endpoint'),
      headers: headers,
    ).timeout(ApiConfig.timeout);

    return _handleResponse(response);
  }

  // Gérer la réponse
  dynamic _handleResponse(http.Response response) {
    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(data['error'] ?? 'Erreur serveur');
    }
  }
}
```

### 4. Créer les services spécifiques

#### Service Appareils (`lib/services/appareil_service.dart`)

```dart
import 'api_service.dart';

class AppareilService {
  final ApiService _api = ApiService();

  Future<List<dynamic>> getAppareils({String? type, bool? disponible}) async {
    String endpoint = '/appareils';
    List<String> params = [];
    
    if (type != null) params.add('type=$type');
    if (disponible != null) params.add('disponible=$disponible');
    
    if (params.isNotEmpty) {
      endpoint += '?${params.join('&')}';
    }

    final response = await _api.get(endpoint);
    return response['appareils'];
  }

  Future<dynamic> addAppareil(Map<String, dynamic> data) async {
    return await _api.post('/appareils', data);
  }

  Future<dynamic> updateAppareil(int id, Map<String, dynamic> data) async {
    return await _api.put('/appareils/$id', data);
  }

  Future<void> deleteAppareil(int id) async {
    await _api.delete('/appareils/$id');
  }
}
```

#### Service Demandes d'achat (`lib/services/demande_service.dart`)

```dart
import 'api_service.dart';

class DemandeService {
  final ApiService _api = ApiService();

  Future<List<dynamic>> getDemandes({String? statut}) async {
    String endpoint = '/demandes';
    if (statut != null) endpoint += '?statut=$statut';

    final response = await _api.get(endpoint);
    return response['demandes'];
  }

  Future<dynamic> createDemande({
    required int appareilId,
    int quantite = 1,
  }) async {
    return await _api.post('/demandes', {
      'appareilId': appareilId,
      'quantite': quantite,
    });
  }

  Future<dynamic> updateStatut({
    required int demandeId,
    required String statut,
    String? commentaire,
  }) async {
    return await _api.patch('/demandes/$demandeId/statut', {
      'statut': statut,
      'commentaire': commentaire,
    });
  }
}
```

### 5. Modifier login.page.dart pour utiliser l'API

```dart
import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'main.dart';
import 'AdminDashBoard.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController identifierController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool isLoading = false;

  Future<void> login() async {
    String identifier = identifierController.text.trim();
    String password = passwordController.text.trim();

    // Validations...
    if (identifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez remplir tous les champs"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Appel API
      final result = await _authService.login(
        identifier: identifier,
        password: password,
      );

      setState(() {
        isLoading = false;
      });

      if (mounted) {
        final role = result['user']['role'];
        
        if (role == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboard()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        }
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ... reste du widget
}
```

### 6. Modifier ventes.dart pour utiliser l'API

```dart
void _handleAchat(Product product) async {
  try {
    final demandeService = DemandeService();
    
    await demandeService.createDemande(
      appareilId: product.id,
      quantite: 1,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Demande d\'achat envoyée pour ${product.name}'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

## 🚀 Démarrage rapide

1. **Déployez le backend sur Render** (suivez backend/README.md)
2. **Mettez à jour `ApiConfig.baseUrl`** avec l'URL Render
3. **Ajoutez les dépendances** dans pubspec.yaml
4. **Créez les fichiers services** mentionnés ci-dessus
5. **Modifiez vos pages** pour utiliser les services
6. **Testez !**

## ⚠️ Notes importantes

- **Cold Start Render**: Premier appel peut prendre 30-60s
- **Gestion d'erreurs**: Toujours utiliser try/catch
- **Loading states**: Afficher des indicateurs de chargement
- **Token expiration**: Gérer le rafraîchissement du token si nécessaire

## 📞 Support

Pour toute question sur l'intégration : contact@echelle-eg39.com