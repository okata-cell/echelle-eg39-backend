import 'package:echelle_eg_39/main.dart';
import 'package:flutter/material.dart';
import 'AdminDashBoard.dart';
import 'register.page.dart';
import 'forgot_password.page.dart';
import 'demo_main.dart';
import 'api_service.dart';
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

  void _showLoginMessage(
    String message, {
    required Color backgroundColor,
  }) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 5),
      ),
    );
  }

// Fonction pour sauvegarder les infos de connexion
  Future<void> _saveUserSession(String identifier, String password, bool isAdmin) async {
    final prefs = await SharedPreferences.getInstance();
    
    // NOTE: Le token est déjà sauvegardé par ApiService.login()
    // Ne pas surécrire avec un token fictif ici
    await prefs.setBool('isLoggedIn', true);
    await prefs.setBool('isAdmin', isAdmin);
    
    // Stocker les infos utilisateur (SANS le mot de passe pour la sécurité)
    await prefs.setString('userIdentifier', identifier);

    // Stocker l'identifiant (PAS le mot de passe) pour pré-remplir le login
    await prefs.setString('saved_identifier', identifier);
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


  Future<void> login() async {
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

    // 📧 VALIDATION EMAIL OU 📱 IDENTIFIANT TÉLÉPHONE
    bool isEmail = identifier.contains('@');

    if (isEmail) {
      // Format email attendu : okataolaniyi@gmail.com
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
      if (!emailRegex.hasMatch(identifier)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Veuillez saisir un email valide (ex: okataolaniyi@gmail.com)"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } else {
      // Format identifiant attendu : +228990929132 (Togo)
      final phoneRegex = RegExp(r'^\+228[0-9]{8,9}$');
      if (!phoneRegex.hasMatch(identifier)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Le numéro doit être au format +228 suivi de 8 ou 9 chiffres (ex: +22890000000)"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // 🔑 VALIDATION DU MOT DE PASSE : 4 chiffres + 4 lettres majuscules (ex: 1234AZER)
    final passwordRegex = RegExp(r'^\d{4}[A-Z]{4}$');
    if (!passwordRegex.hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Le mot de passe doit contenir 4 chiffres suivis de 4 lettres majuscules (ex: 1234AZER)"),
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
      
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      // Connexion API réussie
      // Accès admin réservé UNIQUEMENT au DG (admin@echelle-eg39.com)
      final String loggedEmail = (result['user']['email'] ?? '').toString().toLowerCase();
      final bool isAdmin = loggedEmail == 'admin@echelle-eg39.com';
      
      // Sauvegarder la session
      await _saveUserSession(identifier, password, isAdmin);
      if (!mounted) return;

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
    } on ApiException catch (apiError) {
      print('❌ API login failed: $apiError');

      if (mounted) {
        setState(() {
          isLoading = false;
        });

        final isServerIssue = apiError.type == ApiErrorType.serverUnavailable ||
            apiError.type == ApiErrorType.network;
        _showLoginMessage(
          apiError.message,
          backgroundColor: isServerIssue ? Colors.orange.shade800 : Colors.red,
        );
      }
    } catch (error) {
      print('❌ Erreur inattendue login: $error');

      if (mounted) {
        setState(() {
          isLoading = false;
        });
        _showLoginMessage(
          'Le serveur ne répond pas pour le moment. Veuillez réessayer plus tard.',
          backgroundColor: Colors.orange.shade800,
        );
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
                      hintText: "Email (ex: okataolaniyi@gmail.com) ou +228990929132",
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
