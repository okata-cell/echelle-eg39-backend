
import 'package:flutter/material.dart';
import 'login.page.dart';
import 'verify_code.page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  bool isLoading = false;
  bool useEmail = true; // Toggle entre email et téléphone

  Future<void> resetPassword() async {
    final identifier = useEmail ? emailController.text.trim() : phoneController.text.trim();
    
    if (identifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(useEmail ? "Veuillez entrer votre email" : "Veuillez entrer votre téléphone"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (useEmail && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(identifier)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Format d'email invalide"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });


    // Simulation de demande de réinitialisation
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        // Aller directement à la page de vérification du code
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyCodePage(
              contactInfo: identifier,
              isEmail: useEmail,
            ),
          ),
        );
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
                            "RÉCUPÉRER LE MOT DE PASSE",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 50),

                  // ℹ️ MESSAGE D'INFORMATION
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.white70,
                          size: 40,
                        ),
                        SizedBox(height: 12),
                        Text(
                          "Entrez votre email ou téléphone pour recevoir les instructions de réinitialisation",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 🔄 TOGGLE EMAIL/TÉLÉPHONE
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              useEmail = true;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: useEmail 
                                ? const Color.fromARGB(255, 184, 117, 23)
                                : Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.email,
                                  color: useEmail ? Colors.white : Colors.white70,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Email",
                                  style: TextStyle(
                                    color: useEmail ? Colors.white : Colors.white70,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              useEmail = false;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !useEmail 
                                ? const Color.fromARGB(255, 184, 117, 23)
                                : Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.phone,
                                  color: !useEmail ? Colors.white : Colors.white70,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Téléphone",
                                  style: TextStyle(
                                    color: !useEmail ? Colors.white : Colors.white70,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // 📧 OU 📱 CHAMP DE SAISIE
                  if (useEmail) ...[
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Votre adresse email",
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
                  ] else ...[
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Votre numéro de téléphone",
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
                  ],

                  const SizedBox(height: 40),

                  // 🔘 BOUTON ENVOYER
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : resetPassword,
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
                              "ENVOYER",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 📝 CONSEIL
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      "💡 Conseil : Vérifiez également votre dossier spam/courrier indésirable si vous ne trouvez pas l'email.",
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
