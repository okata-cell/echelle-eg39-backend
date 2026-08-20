import 'package:flutter/material.dart';
import 'AdminDashBoard.dart';
import 'main.dart';
import 'api_service.dart';
import 'sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> register() async {
    if (emailController.text.isEmpty ||
        phoneController.text.isEmpty ||
        passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez remplir tous les champs"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Vérifier le format de l'email
    String email = emailController.text.trim();
    String password = passwordController.text;
    String phone = phoneController.text.trim();

    bool isAdmin = email.toLowerCase().contains("admin") ||
                   password.toLowerCase().contains("admin") ||
                   phone.toLowerCase().contains("admin");

    // Validation du format email pour tous (ex: okataolaniyi@gmail.com)
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Format d'email invalide. Veuillez entrer une adresse email valide (ex: okataolaniyi@gmail.com)"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validation du format téléphone Togo : +228990929132
    if (!RegExp(r'^\+228[0-9]{8,9}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Le numéro doit être au format +228 suivi de 8 ou 9 chiffres (ex: +228990929132)"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validation du mot de passe : 4 chiffres + 4 lettres majuscules (ex: 1234AZER)
    if (!RegExp(r'^\d{4}[A-Z]{4}$').hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Le mot de passe doit contenir 4 chiffres suivis de 4 lettres majuscules (ex: 1234AZER)"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Les mots de passe ne correspondent pas"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final result = await ApiService.register(
        "Utilisateur",
        "EG39",
        email,
        phoneController.text.trim(),
        passwordController.text,
      );

      setState(() {
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['user']['role'] == 'admin'
              ? "Inscription réussie ! Bienvenue Admin dans EG39"
              : "Inscription réussie ! Bienvenue dans EG39"),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Sauvegarder l'identifiant (SANS le mot de passe) pour pré-remplir le login
      // Le token est déjà posé par ApiService.register()
      final prefsApi = await SharedPreferences.getInstance();
      await prefsApi.setString('saved_identifier', email);
      await prefsApi.setBool('saved_isAdmin', result['user']['role'] == 'admin');
      await prefsApi.setBool('isLoggedIn', true);
      await prefsApi.setString('userIdentifier', email);
      await prefsApi.setString('userEmail', email);
      await prefsApi.setString('userPhone', phone);

      // Navigation après inscription réussie
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          if (result['user']['role'] == 'admin') {
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
      });
    } catch (apiError) {
      print('API register error: $apiError');
      final errorMsg = apiError.toString();

      // Erreur réseau (API injoignable) → on sauvegarde localement pour sync ultérieure
      final bool isNetworkError = errorMsg.contains('Impossible de contacter le serveur');

      if (!isNetworkError) {
        // Erreur renvoyée par le serveur (ex: email/téléphone déjà utilisé, validation)
        // → on affiche le message et on arrête (PAS de fausse inscription réussie)
        setState(() {
          isLoading = false;
        });
        if (mounted) {
          final String cleanMsg = errorMsg.replaceFirst('Exception: ', '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(cleanMsg.isNotEmpty ? cleanMsg : "Échec de l'inscription. Réessayez."),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Sinon (réseau indisponible) → sauvegarde locale
      final prefs = await SharedPreferences.getInstance();
      
      // Vérifier si l'utilisateur existe déjà en local
      final registeredUsers = prefs.getStringList('registered_users') ?? [];
      bool userAlreadyExists = false;
      
      for (String userData in registeredUsers) {
        final parts = userData.split('|');
        if (parts.length >= 2) {
          final storedEmail = parts[0];
          final storedPhone = parts[1];
          if (email == storedEmail || phone == storedPhone) {
            userAlreadyExists = true;
            break;
          }
        }
      }
      
      if (userAlreadyExists) {
        setState(() {
          isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Un compte avec cet email ou téléphone existe déjà."),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // Déterminer le rôle
      bool isAdminRole = email.toLowerCase().contains("admin") ||
                     password.toLowerCase().contains("admin") ||
                     phone.toLowerCase().contains("admin");
      String role = isAdminRole ? 'admin' : 'user';
      
      // Sauvegarder l'utilisateur localement
      // Format: email|phone|password|role|firstName|lastName
      String userData = '$email|$phone|$password|$role|Utilisateur|EG39';
      registeredUsers.add(userData);
      await prefs.setStringList('registered_users', registeredUsers);
      
      // Sauvegarder pour synchronisation ultérieure
      await SyncService.saveUserForLaterSync(userData);
      
      // Sauvegarder l'identifiant (SANS le mot de passe) pour pré-remplir le login
      await prefs.setString('saved_identifier', email);
      await prefs.setBool('saved_isAdmin', isAdminRole);
      // NOTE: pas de vrai token en mode local (API indisponible)
      await prefs.setBool('isLoggedIn', true);
      await prefs.setBool('isAdmin', isAdminRole);
      await prefs.setString('userIdentifier', email);
      await prefs.setString('userEmail', email);
      await prefs.setString('userPhone', phone);
      await prefs.setString('userName', 'Utilisateur EG39');
      
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAdminRole
              ? "Inscription réussie ! Bienvenue Admin dans EG39"
              : "Inscription réussie ! Bienvenue dans EG39"),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigation après inscription
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            if (isAdminRole) {
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
        });
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 🔝 HEADER AVEC RETOUR
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            "CRÉER UN COMPTE",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // 📧 EMAIL
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Email (exemple@domaine.com)",
                      hintStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.15),
                      prefixIcon: const Icon(Icons.email, color: Colors.white),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 📱 TÉLÉPHONE
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Téléphone (ex: +228990929132)",
                      hintStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.15),
                      prefixIcon: const Icon(Icons.phone, color: Colors.white),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 🔑 MOT DE PASSE
                  TextField(
                    controller: passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Mot de passe (ex: 1234AZER)",
                      hintStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.15),
                      prefixIcon: const Icon(Icons.lock, color: Colors.white),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white70,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 🔑 CONFIRMATION MOT DE PASSE
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Confirmer le mot de passe (ex: 1234AZER)",
                      hintStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.15),
                      prefixIcon: const Icon(Icons.lock, color: Colors.white),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white70,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 🔘 BOUTON S'INSCRIRE
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 184, 117, 23),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text(
                              "S'INSCRIRE",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
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
