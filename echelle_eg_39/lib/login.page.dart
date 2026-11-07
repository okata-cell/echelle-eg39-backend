// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'package:echelle_eg_39/main.dart';
import 'package:flutter/material.dart';
import 'AdminDashBoard.dart';
import 'change_temporary_password.page.dart';
import 'register.page.dart';
import 'forgot_password.page.dart';
import 'demo_main.dart';
import 'api_service.dart';
import 'password_recovery_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.noticeMessage});

  /// Message affiché à l'ouverture, par exemple quand la session a été fermée
  /// parce que le compte a été supprimé.
  final String? noticeMessage;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController identifierController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FocusNode identifierFocus = FocusNode();
  final FocusNode passwordFocus = FocusNode();

  bool isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();

    // Rafraîchir le suffixIcon "clear" quand le texte change
    identifierController.addListener(_onIdentifierChanged);

    final notice = widget.noticeMessage;
    if (notice != null && notice.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showLoginMessage(notice, backgroundColor: Colors.orange.shade800);
      });
    }
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
      await prefs.setString('userEmail', '$identifier@utilisateur.com');
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

      // Connexion avec un mot de passe temporaire (récupération de compte) :
      // le client choisit son mot de passe définitif avant d'entrer.
      final userPayload = result['user'];
      final mustChangePassword =
          userPayload is Map && userPayload['mustChangePassword'] == true;
      if (mustChangePassword) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeTemporaryPasswordPage(isAdmin: isAdmin),
          ),
        );
        return;
      }

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

        // Un compte supprimé n'est pas une erreur de saisie : le message
        // informe sans accuser le client d'avoir mal tapé son mot de passe.
        final isServerIssue =
            apiError.type == ApiErrorType.serverUnavailable ||
            apiError.type == ApiErrorType.network ||
            apiError.type == ApiErrorType.accountDeleted;
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

  // ────────────────────────────────────────────────────────────────
  //  UI — Proposition A : même design que forgot_password.page.dart
  //  (PasswordRecoveryScaffold : fond photo + scrim, en-tête retour,
  //   champs blancs, bouton bleu StadiumBorder). Aucune logique modifiée.
  // ────────────────────────────────────────────────────────────────

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildIdentifierField() {
    return TextField(
      controller: identifierController,
      focusNode: identifierFocus,
      enabled: !isLoading,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.username, AutofillHints.email],
      onSubmitted: (_) => passwordFocus.requestFocus(),
      style: const TextStyle(color: passwordRecoveryInk),
      decoration: passwordRecoveryFieldDecoration(
        hint: 'ex: +22890000000',
        leading: const Icon(
          Icons.person_outline,
          color: Color(0xFF7A7A7A),
          size: 20,
        ),
        trailing: identifierController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Effacer',
                icon: const Icon(
                  Icons.clear,
                  color: Color(0xFF7A7A7A),
                  size: 20,
                ),
                onPressed: () {
                  setState(() => identifierController.clear());
                  identifierFocus.requestFocus();
                },
              ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: passwordController,
      focusNode: passwordFocus,
      enabled: !isLoading,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      onSubmitted: (_) => login(),
      style: const TextStyle(color: passwordRecoveryInk),
      decoration: passwordRecoveryFieldDecoration(
        hint: '4 chiffres + 4 lettres (ex: 1234AZER)',
        leading: const Icon(
          Icons.lock_outline,
          color: Color(0xFF7A7A7A),
          size: 20,
        ),
        trailing: IconButton(
          tooltip: _obscurePassword
              ? 'Afficher le mot de passe'
              : 'Masquer le mot de passe',
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: const Color(0xFF7A7A7A),
            size: 20,
          ),
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
        ),
      ),
    );
  }

  Widget _buildDemoButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: isLoading
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DemoMainScreen()),
                );
              },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white54,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.65)),
          shape: const StadiumBorder(),
        ),
        icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
        label: const Text(
          'Découvrir la démo',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildSecondaryLinks() {
    return Column(
      children: [
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
          child: Text(
            'Mot de passe oublié ?',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.84),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton(
          onPressed: isLoading
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterPage()),
                  );
                },
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              children: const [
                TextSpan(text: 'Nouveau ici ? '),
                TextSpan(
                  text: 'Créer un compte',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Divider(color: Colors.white.withValues(alpha: 0.16), height: 1),
        const SizedBox(height: 14),
        Text(
          'Connexion sécurisée · ÉCHELLE EG39',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PasswordRecoveryScaffold(
      stepLabel: 'Connexion · Étape unique',
      title: 'Connexion',
      description: 'Ravi de vous revoir. Accédez à votre espace topographie et BTP.',
      backTooltip: 'Quitter la connexion',
      onBack: () => Navigator.maybePop(context),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel('Email ou téléphone'),
          const SizedBox(height: 8),
          _buildIdentifierField(),
          const SizedBox(height: 18),
          _buildFieldLabel('Mot de passe'),
          const SizedBox(height: 8),
          _buildPasswordField(),
          const SizedBox(height: 10),
          Text(
            'Format : +228 suivi de 8 chiffres · mot de passe 1234AZER',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.4,
            ),
          ),
        ],
      ),
      secondaryContent: Column(
        children: [
          _buildDemoButton(),
          const SizedBox(height: 6),
          _buildSecondaryLinks(),
        ],
      ),
      primaryLabel: 'Se connecter',
      primaryLoadingLabel: 'Connexion…',
      isLoading: isLoading,
      onPrimary: login,
    );
  }
}
