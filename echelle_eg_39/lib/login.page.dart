import 'package:echelle_eg_39/main.dart';
import 'package:flutter/material.dart';
import 'AdminHomePage.dart';
import 'AdminDashBoard.dart';
import 'register.page.dart';
import 'forgot_password.page.dart';
import 'demo_main.dart';
import 'api_service.dart';
import 'sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController identifierController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();


  bool isLoading = false;

// Fonction pour sauvegarder les infos de connexion
  Future<void> _saveUserSession(String identifier, String password, bool isAdmin) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Stocker un token fictif pour indiquer que l'utilisateur est connecté
    await prefs.setString('token', 'demo_token_${DateTime.now().millisecondsSinceEpoch}');
    await prefs.setBool('isLoggedIn', true);
    await prefs.setBool('isAdmin', isAdmin);
    
    // Stocker les infos utilisateur
    await prefs.setString('userIdentifier', identifier);
    await prefs.setString('userPassword', password);
    
    // Stocker les identifiants de manière permanente pour récupération après réinstallation
    await prefs.setString('saved_identifier', identifier);
    await prefs.setString('saved_password', password);
    await prefs.setBool('saved_isAdmin', isAdmin);
    
    // Déterminer le nom et email basée sur l'identifiant
    if (RegExp(r'^[0-9]+$').hasMatch(identifier.replaceAll(' ', ''))) {
      // C'est un numéro de téléphone
      await prefs.setString('userPhone', identifier);
      await prefs.setString('userEmail', '${identifier}@utilisateur.com');
      await prefs.setString('userName', 'Utilisateur $identifier');
    } else {
      // C'est un email
      await prefs.setString('userEmail', identifier);
      await prefs.setString('userPhone', '+228 00 00 00 00');
      await prefs.setString('userName', identifier.split('@').first);
    }
    
    print('✅ Session utilisateur sauvegardée');
  }

  // 🔄 Méthode pour tenter la synchronisation en arrière-plan
  Future<void> _attemptBackgroundSync() async {
    try {
      // Vérifier si l'API est disponible
      final apiAvailable = await SyncService.isApiAvailable();
      
      if (apiAvailable) {
        print('🔄 API disponible, tentative de synchronisation...');
        
        // Tenter de synchroniser les utilisateurs locaux
        final result = await SyncService.syncLocalUsers();
        
        if (result.success && result.syncedCount > 0) {
          print('✅ Synchronisation réussie: ${result.syncedCount} utilisateurs');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${result.syncedCount} utilisateur(s) synchronisé(s) avec le serveur'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          print('ℹ️ ${result.message}');
        }
      } else {
        print('⚠️ API non disponible, synchronisation reportée');
      }
    } catch (e) {
      print('❌ Erreur lors de la synchronisation: $e');
    }
  }

  void login() async {
    String identifier = identifierController.text.trim();
    String password = passwordController.text.trim();

    // 🔍 VALIDATION DES CHAMPS
    if (identifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez saisir votre téléphone ou email"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez saisir votre mot de passe"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 📱 VALIDATION DU NUMÉRO DE TÉLÉPHONE OU EMAIL
    bool isPhoneNumber = RegExp(r'^[0-9]+$').hasMatch(identifier.replaceAll(' ', ''));
    bool isValidEmail = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(identifier);

    if (isPhoneNumber) {
      // Validation du numéro de téléphone : 8 à 15 chiffres
      String phoneDigits = identifier.replaceAll(RegExp(r'[^0-9]'), '');
      if (phoneDigits.length < 8 || phoneDigits.length > 15) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Le numéro de téléphone doit contenir entre 8 et 15 chiffres"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } else if (!isValidEmail) {
      // Validation de l'email
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez saisir un email valide"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 🔑 VALIDATION DU MOT DE PASSE
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Le mot de passe doit contenir au moins 6 caractères"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Vérifier que le mot de passe contient au moins une lettre et un chiffre
    bool hasLetter = RegExp(r'[a-zA-Z]').hasMatch(password);
    bool hasDigit = RegExp(r'[0-9]').hasMatch(password);

    if (!hasLetter || !hasDigit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Le mot de passe doit contenir des lettres et des chiffres"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Essayer d'abord via l'API
      final result = await ApiService.login(identifier, password);
      
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        // Connexion API réussie
        bool isAdmin = result['user']['role'] == 'admin';
        
        // Sauvegarder la session
        await _saveUserSession(identifier, password, isAdmin);

        if (isAdmin) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashBoard()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        }
      }
    } catch (apiError) {
      // Si l'API échoue, vérifier localement
      print('API login failed, checking local users: $apiError');
      
      final prefs = await SharedPreferences.getInstance();
      final registeredUsers = prefs.getStringList('registered_users') ?? [];
      
      bool userFound = false;
      bool isAdmin = false;
      
      for (String userData in registeredUsers) {
        final parts = userData.split('|');
        if (parts.length >= 4) {
          final storedEmail = parts[0];
          final storedPhone = parts[1];
          final storedPassword = parts[2];
          final storedRole = parts[3];
          
          // Vérifier si les identifiants correspondent
          if ((identifier == storedEmail || identifier == storedPhone) && 
              password == storedPassword) {
            userFound = true;
            isAdmin = storedRole == 'admin';
            
            // Sauvegarder les infos utilisateur
            await prefs.setString('token', 'local_token_${DateTime.now().millisecondsSinceEpoch}');
            await prefs.setBool('isLoggedIn', true);
            await prefs.setBool('isAdmin', isAdmin);
            await prefs.setString('userIdentifier', identifier);
            await prefs.setString('userEmail', storedEmail);
            await prefs.setString('userPhone', storedPhone);
            await prefs.setString('userName', parts.length > 4 ? parts[4] : 'Utilisateur');
            
            break;
          }
        }
      }
      
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        if (userFound) {
          // Connexion locale réussie
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Connexion réussie !"),
              backgroundColor: Colors.green,
            ),
          );

          // 🔄 Tenter de synchroniser avec l'API en arrière-plan
          _attemptBackgroundSync();

          if (isAdmin) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AdminDashBoard()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MainScreen()),
            );
          }
        } else {
          // Utilisateur non trouvé
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Aucun compte trouvé avec ces identifiants. Veuillez créer un compte d'abord."),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: "S'inscrire",
                textColor: Colors.white,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterPage()),
                  );
                },
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🌄 IMAGE DE FOND (UNSPLASH)
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  "https://teg-ge.fr/wp-content/uploads/2018/04/topographie.jpg",
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 🖤 OVERLAY SOMBRE
          Container(
            color: const Color.fromRGBO(11, 11, 11, 1).withOpacity(0.6),
          ),

          // 📄 CONTENU
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 🔝 TEXTE BIENVENUE
                  const Text(
                    "BIENVENUE À L'ENTREPRISE ÉCHELLE EG39\nTOPOGRAPHIE - BTP",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),

                  const SizedBox(height: 100),

                  // 📱 TÉLÉPHONE / EMAIL
                  TextField(
                    controller: identifierController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Téléphone ou Email",
                      hintStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.15),
                      prefixIcon: const Icon(Icons.person, color: Colors.white),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 🔑 MOT DE PASSE
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Mot de passe",
                      hintStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.15),
                      prefixIcon: const Icon(Icons.lock, color: Colors.white),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 🔘 BOUTONS PRINCIPAUX
                  Column(
                    children: [
                      // 🔘 BOUTON CONNEXION
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 184, 117, 23),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.login, size: 22),
                                    SizedBox(width: 10),
                                    Text(
                                      "SE CONNECTER",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      // 🔘 BOUTON DÉMO
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const DemoMainScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Colors.white, width: 2),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_circle_outline, size: 22),
                              SizedBox(width: 10),
                              Text(
                                "DÉMO",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // 📝 BOUTONS TRANSPARENTS
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // 🔘 CRÉER UN COMPTE
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RegisterPage()),
                          );
                        },
                        child: const Text(
                          "Créer un compte",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Text(
                        "|",
                        style: TextStyle(color: Colors.white70),
                      ),
                      // 🔘 MOT DE PASSE OUBLIÉ
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                          );
                        },
                        child: const Text(
                          "Mot de passe oublié ?",
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
