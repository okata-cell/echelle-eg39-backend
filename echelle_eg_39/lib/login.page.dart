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

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController identifierController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FocusNode identifierFocus = FocusNode();
  final FocusNode passwordFocus = FocusNode();

  bool isLoading = false;
  bool _obscurePassword = true;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();

    // Rafraîchir le suffixIcon "clear" quand le texte change
    identifierController.addListener(_onIdentifierChanged);
  }

  void _onIdentifierChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    identifierController.removeListener(_onIdentifierChanged);
    identifierController.dispose();
    passwordController.dispose();
    identifierFocus.dispose();
    passwordFocus.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _showLoginMessage(String message, {required Color backgroundColor}) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              backgroundColor == Colors.red
                  ? Icons.error_outline
                  : Icons.info_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // Fonction pour sauvegarder les infos de connexion
  Future<void> _saveUserSession(
    String identifier,
    String password,
    bool isAdmin,
  ) async {
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
      _showLoginMessage(
        "Veuillez saisir votre téléphone ou email",
        backgroundColor: Colors.red,
      );
      return;
    }

    if (password.isEmpty) {
      _showLoginMessage(
        "Veuillez saisir votre mot de passe",
        backgroundColor: Colors.red,
      );
      return;
    }

    // 📧 VALIDATION EMAIL OU 📱 IDENTIFIANT TÉLÉPHONE
    bool isEmail = identifier.contains('@');

    if (isEmail) {
      // Format email attendu : okataolaniyi@gmail.com
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
      if (!emailRegex.hasMatch(identifier)) {
        _showLoginMessage(
          "Veuillez saisir un email valide (ex: okataolaniyi@gmail.com)",
          backgroundColor: Colors.red,
        );
        return;
      }
    } else {
      // Format identifiant attendu : +228990929132 (Togo)
      final phoneRegex = RegExp(r'^\+228[0-9]{8,9}$');
      if (!phoneRegex.hasMatch(identifier)) {
        _showLoginMessage(
          "Le numéro doit être au format +228 suivi de 8 chiffres (ex: +22890000000)",
          backgroundColor: Colors.red,
        );
        return;
      }
    }

    // 🔑 VALIDATION DU MOT DE PASSE : 4 chiffres + 4 lettres majuscules (ex: 1234AZER)
    final passwordRegex = RegExp(r'^\d{4}[A-Z]{4}$');
    if (!passwordRegex.hasMatch(password)) {
      _showLoginMessage(
        "Le mot de passe doit contenir 4 chiffres suivis de 4 lettres majuscules (ex: 1234AZER)",
        backgroundColor: Colors.red,
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
      final String loggedEmail = (result['user']['email'] ?? '')
          .toString()
          .toLowerCase();
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

        final isServerIssue =
            apiError.type == ApiErrorType.serverUnavailable ||
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
      backgroundColor: const Color(0xFF0A0E14),
      body: Stack(
        children: [
          // 🌄 IMAGE DE FOND (UNSPLASH)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(
                    "https://aptopo40.com/wp-content/uploads/elementor/thumbs/contractor-land-surveying-the-backyard-qdxwl69w7j376x9koemaihszy48w00htwz12y59x4w.jpg",
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // 🖤 OVERLAY SOMBRE GRADIENT POUR MEILLEURE LISIBILITÉ
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0A0E14).withOpacity(0.72),
                    const Color(0xFF0A0E14).withOpacity(0.55),
                    const Color(0xFF0A0E14).withOpacity(0.88),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),

          // 📄 CONTENU ANIMÉ
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 40,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),

                      // 🔷 LOGO / MONOGRAMME
                      Center(
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFF5B942), Color(0xFFD98E0F)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF5B942).withOpacity(0.4),
                                blurRadius: 28,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              "EG",
                              style: TextStyle(
                                color: Color(0xFF0A0E14),
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // 🏗️ TITRE PRINCIPAL
                      const Text(
                        "ÉCHELLE EG39",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 12,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // 🏬 SOUS-TITRE
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5B942).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: const Color(0xFFF5B942).withOpacity(0.55),
                            width: 1.2,
                          ),
                        ),
                        child: const Text(
                          "TOPOGRAPHIE  •  BTP",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFF5B942),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.4,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ✨ BIENVENUE
                      const Text(
                        "Ravi de vous revoir 👋",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 36),

                      // 🃏 CARTE VERRE DÉPOLI (GLASSMORPHISM)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.18),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 📱 TÉLÉPHONE / EMAIL
                            TextField(
                              controller: identifierController,
                              focusNode: identifierFocus,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                labelText: "Email ou téléphone",
                                labelStyle: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                                hintText: "ex: +22890000000",
                                hintStyle: const TextStyle(
                                  color: Colors.white38,
                                  fontWeight: FontWeight.w400,
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.10),
                                prefixIcon: const Icon(
                                  Icons.person_outline,
                                  color: Color(0xFFF5B942),
                                ),
                                suffixIcon: identifierController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.clear,
                                          color: Colors.white54,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          setState(
                                            () => identifierController.clear(),
                                          );
                                          identifierFocus.requestFocus();
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.15),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFF5B942),
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                  horizontal: 16,
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            // 🔑 MOT DE PASSE
                            TextField(
                              controller: passwordController,
                              focusNode: passwordFocus,
                              obscureText: _obscurePassword,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                labelText: "Mot de passe",
                                labelStyle: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                                hintText:
                                    "4 chiffres + 4 lettres (ex: 1234AZER)",
                                hintStyle: const TextStyle(
                                  color: Colors.white38,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 13,
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.10),
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  color: Color(0xFFF5B942),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.white54,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    );
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.15),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFF5B942),
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                  horizontal: 16,
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // 🔘 BOUTON CONNEXION
                            SizedBox(
                              height: 56,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFF5B942,
                                      ).withOpacity(isLoading ? 0.1 : 0.45),
                                      blurRadius: 22,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: isLoading ? null : login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF5B942),
                                    foregroundColor: const Color(0xFF0A0E14),
                                    disabledBackgroundColor: const Color(
                                      0xFFF5B942,
                                    ).withOpacity(0.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: isLoading
                                      ? const SizedBox(
                                          height: 26,
                                          width: 26,
                                          child: CircularProgressIndicator(
                                            color: Color(0xFF0A0E14),
                                            strokeWidth: 3,
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.login_rounded, size: 22),
                                            SizedBox(width: 10),
                                            Text(
                                              "SE CONNECTER",
                                              style: TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            // 🔘 BOUTON DÉMO
                            SizedBox(
                              height: 54,
                              child: OutlinedButton(
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const DemoMainScreen(),
                                          ),
                                        );
                                      },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withOpacity(0.55),
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.play_circle_outline_rounded,
                                      size: 22,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      "DÉMO",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // 📝 LIENS AUTH
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: isLoading
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const RegisterPage(),
                                      ),
                                    );
                                  },
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                                children: [
                                  const TextSpan(text: "Nouveau ici ? "),
                                  TextSpan(
                                    text: "Créer un compte",
                                    style: TextStyle(
                                      color: const Color(0xFFF5B942),
                                      fontWeight: FontWeight.w800,
                                      decoration: TextDecoration.underline,
                                      decorationColor: const Color(
                                        0xFFF5B942,
                                      ).withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // 🔑 MOT DE PASSE OUBLIÉ
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ForgotPasswordPage(),
                                  ),
                                );
                              },
                        child: const Text(
                          "Mot de passe oublié ?",
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ℹ️ CONDITIONS DE CONNEXION
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.lock_outline,
                                  color: Colors.white54,
                                  size: 14,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "CONDITIONS DE CONNEXION",
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Téléphone au format +228 suivi de 8 chiffres • Mot de passe : 4 chiffres + 4 lettres majuscules (ex: 1234AZER)",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.45),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ⏳ LOADING PLEIN ÉCRAN (optionnel, gardé subtil)
          if (isLoading)
            Positioned.fill(
              child: Container(color: Colors.black.withOpacity(0.15)),
            ),
        ],
      ),
    );
  }
}
