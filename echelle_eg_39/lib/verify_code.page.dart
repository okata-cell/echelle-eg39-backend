import 'package:flutter/material.dart';
import 'forgot_password.page.dart';
import 'reset_password.page.dart';

class VerifyCodePage extends StatefulWidget {
  final String contactInfo; // Email ou téléphone utilisé
  final bool isEmail; // true pour email, false pour téléphone

  const VerifyCodePage({
    super.key,
    required this.contactInfo,
    required this.isEmail,
  });

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage> {
  final TextEditingController codeController = TextEditingController();
  bool isLoading = false;

  void verifyCode() {
    final code = codeController.text.trim();
    
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez saisir le code de vérification"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Le code doit contenir 6 chiffres"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    // Simulation de vérification du code
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        isLoading = false;
      });

      // Code de test "123456" pour la démonstration
      if (code == "123456" || code == "783456" || code == "987654") {
        // Code valide, aller à la page de réinitialisation
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ResetPasswordPage(
                contactInfo: widget.contactInfo,
                isEmail: widget.isEmail,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Code de vérification invalide"),
              backgroundColor: Colors.red,
            ),
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
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
                            "VÉRIFICATION DU CODE",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 60),

                  // 📧📱 INFOS DE CONTACT
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          widget.isEmail ? Icons.email : Icons.phone,
                          color: Colors.white70,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Code envoyé à",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.contactInfo,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 🔢 SAISIE DU CODE
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Entrez le code de vérification à 6 chiffres",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: codeController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 8,
                          ),
                          decoration: InputDecoration(
                            hintText: "000000",
                            hintStyle: TextStyle(
                              color: Colors.white70,
                              letterSpacing: 8,
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.15),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            counterText: "", // Cache le compteur de caractères
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Nouveau code envoyé !"),
                                    backgroundColor: Color.fromARGB(255, 184, 117, 23),
                                  ),
                                );
                              },
                              child: const Text(
                                "Renvoyer le code",
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ForgotPasswordPage(),
                                  ),
                                );
                              },
                              child: const Text(
                                "Changer de contact",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 🔘 BOUTON VÉRIFIER
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : verifyCode,
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
                              "VÉRIFIER LE CODE",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 💡 CONSEIL
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      "💡 Codes de test : 123456, 783456, 987654\nVérifiez également votre dossier spam/courrier indésirable",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
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
