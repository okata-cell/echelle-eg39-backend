import 'package:echelle_eg_39/main.dart';
import 'package:flutter/material.dart';
import 'AdminHomePage.dart';
import 'AdminDashBoard.dart';
import 'register.page.dart';
import 'forgot_password.page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController identifierController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();


  bool isLoading = false;

  void login() {
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

    // 🔹 Simulation de connexion (à remplacer par API plus tard)
    Future.delayed(const Duration(seconds: 2), () {
      String identifierLower = identifier.toLowerCase();
      String passwordLower = password.toLowerCase();

      // 🔐 LOGIQUE DE RÔLE - Vérification dans tous les champs
      bool isAdmin = identifierLower.contains("admin") || passwordLower.contains("admin");

      setState(() {
        isLoading = false;
      });

      if (mounted) {
        if (isAdmin) {
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
    });
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
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text(
                              "SE CONNECTER",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 📝 BOUTONS S'INSCRIRE ET MOT DE PASSE OUBLIÉ
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RegisterPage()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: Colors.white.withOpacity(0.3)),
                            ),
                          ),
                          child: const Text(
                            "S'INSCRIRE",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.1),
                            foregroundColor: Colors.white70,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: Colors.white.withOpacity(0.2)),
                            ),
                          ),
                          child: const Text(
                            "MOT DE PASSE OUBLIÉ",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
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
