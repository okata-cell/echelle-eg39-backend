// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'dart:async';

import 'package:echelle_eg_39/main.dart';
import 'package:flutter/material.dart';
import 'AdminDashBoard.dart';
import 'change_temporary_password.page.dart';
import 'register.page.dart';
import 'forgot_password.page.dart';
import 'demo_main.dart';
import 'api_service.dart';
import 'login_feedback.dart';
import 'login_lockout.dart';
import 'password_recovery_scaffold.dart';
import 'widgets/clipboard_paste_action.dart';
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

  /// Échéance du blocage en cours, nulle tant que la connexion n'est pas
  /// bloquée par le serveur.
  DateTime? _blocageEcheance;

  /// Identifiant concerné par ce blocage : le compteur, côté serveur, suit
  /// l'identifiant saisi, pas l'appareil.
  String? _blocageIdentifiant;

  Timer? _blocageTimer;

  /// Refus posés sous les champs, nuls tant que la saisie est vierge de faute.
  String? _erreurIdentifiant;
  String? _erreurMotDePasse;

  @override
  void initState() {
    super.initState();

    // Rafraîchir le suffixIcon "clear" quand le texte change
    identifierController.addListener(_onIdentifierChanged);
    passwordController.addListener(_onPasswordChanged);

    // Un blocage posé lors d'une session précédente est réaffiché à l'ouverture,
    // sinon l'écran proposerait une connexion que le serveur refusera.
    unawaited(_restaurerBlocage());

    final notice = widget.noticeMessage;
    if (notice != null && notice.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showLoginMessage(notice, backgroundColor: Colors.orange.shade800);
      });
    }
  }

  /// Pose un refus sur le champ identifiant et y ramène le curseur.
  void _signalerIdentifiant(String message) {
    setState(() => _erreurIdentifiant = message);
    identifierFocus.requestFocus();
  }

  /// Saisie réelle dans le champ identifiant.
  ///
  /// Distinct du simple changement de sélection : demander le focus déplace le
  /// curseur, ce qui notifie aussi le contrôleur et effacerait le message à
  /// peine affiché.
  void _onIdentifiantSaisi(String valeur) {
    if (_erreurIdentifiant != null) {
      setState(() => _erreurIdentifiant = null);
    }

    // Le blocage ne concerne qu'un identifiant : dès qu'un autre est saisi, le
    // décompte disparaît, sinon il accuserait un compte qui n'est pas visé.
    final saisi = valeur.trim().toLowerCase();
    if (_blocageIdentifiant != null && saisi != _blocageIdentifiant) {
      _leverBlocage();
    }
  }

  void _onMotDePasseSaisi(String valeur) {
    if (_erreurMotDePasse == null || valeur.isEmpty) return;
    setState(() => _erreurMotDePasse = null);
  }

  void _onIdentifierChanged() {
    setState(() {});
  }

  /// Rafraîchit l'action de marge (Coller / Effacer) au fil de la saisie.
  void _onPasswordChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _blocageTimer?.cancel();
    identifierController.removeListener(_onIdentifierChanged);
    passwordController.removeListener(_onPasswordChanged);
    identifierController.dispose();
    passwordController.dispose();
    identifierFocus.dispose();
    passwordFocus.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────
  //  Blocage après plusieurs échecs : bandeau, décompte et mémoire locale
  // ────────────────────────────────────────────────────────────────

  /// Durée restante, nulle quand le blocage est levé.
  Duration? get _blocageRestant {
    final echeance = _blocageEcheance;
    if (echeance == null) return null;

    final restant = echeance.difference(DateTime.now());
    return restant > Duration.zero ? restant : null;
  }

  bool get _estBloque => _blocageRestant != null;

  Future<void> _restaurerBlocage() async {
    final prefs = await SharedPreferences.getInstance();
    final identifiant = prefs.getString('saved_identifier') ?? '';
    final cle = cleBlocage(identifiant);
    if (cle == null) return;

    final echeance = DateTime.tryParse(prefs.getString(cle) ?? '');
    if (echeance == null) return;

    if (!echeance.isAfter(DateTime.now())) {
      await prefs.remove(cle);
      return;
    }

    if (!mounted) return;
    setState(() {
      _blocageEcheance = echeance;
      _blocageIdentifiant = identifiant.trim().toLowerCase();
    });
    _demarrerDecompte();
  }

  /// Conserve l'échéance et lance le décompte affiché.
  ///
  /// L'échéance est absolue : un passage en arrière-plan ou une fermeture de
  /// l'application ne décale pas l'heure de reprise, contrairement à un compteur
  /// décrémenté à chaque battement.
  Future<void> _memoriserBlocage(String identifiant, int? secondes) async {
    final duree = (secondes != null && secondes > 0)
        ? Duration(seconds: secondes)
        : delaiBlocageParDefaut;
    final echeance = DateTime.now().add(duree);

    if (!mounted) return;
    setState(() {
      _blocageEcheance = echeance;
      _blocageIdentifiant = identifiant.trim().toLowerCase();
    });
    _demarrerDecompte();

    final cle = cleBlocage(identifiant);
    if (cle == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(cle, echeance.toIso8601String());
  }

  void _demarrerDecompte() {
    _blocageTimer?.cancel();
    _blocageTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      if (_blocageRestant == null) {
        _leverBlocage();
        return;
      }

      setState(() {});
    });
  }

  /// Retire le bandeau ; l'échéance mémorisée est effacée avec lui.
  void _leverBlocage() {
    _blocageTimer?.cancel();
    _blocageTimer = null;

    final identifiant = _blocageIdentifiant;
    if (identifiant == null && _blocageEcheance == null) return;

    if (mounted) {
      setState(() {
        _blocageEcheance = null;
        _blocageIdentifiant = null;
      });
    }

    final cle = cleBlocage(identifiant ?? '');
    if (cle == null) return;
    unawaited(
      SharedPreferences.getInstance().then((prefs) => prefs.remove(cle)),
    );
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
    // Un blocage en cours ne doit pas être forcé : le bouton est désactivé, cette
    // garde couvre l'envoi au clavier (validation du champ mot de passe).
    if (_estBloque) return;

    String identifier = identifierController.text.trim();
    String password = passwordController.text.trim();

    // Chaque refus est posé sous le champ qui le provoque : le client voit
    // immédiatement s'il doit corriger l'identifiant ou le mot de passe.
    setState(() {
      _erreurIdentifiant = null;
      _erreurMotDePasse = null;
    });

    bool isEmail = identifier.contains('@');

    if (identifier.isEmpty) {
      _signalerIdentifiant(
        'Saisissez votre e-mail ou votre numéro de téléphone.',
      );
      return;
    }

    if (isEmail) {
      // Format email attendu : nom@domaine.com
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
      if (!emailRegex.hasMatch(identifier)) {
        _signalerIdentifiant(
          'Adresse e-mail incomplète (ex: nom@domaine.com).',
        );
        return;
      }
    } else {
      // Format identifiant attendu : +228990929132 (Togo)
      final phoneRegex = RegExp(r'^\+228[0-9]{8,9}$');
      if (!phoneRegex.hasMatch(identifier)) {
        _signalerIdentifiant(
          'Numéro incomplet : +228 suivi de 8 ou 9 chiffres.',
        );
        return;
      }
    }

    if (password.isEmpty) {
      setState(() => _erreurMotDePasse = 'Saisissez votre mot de passe.');
      passwordFocus.requestFocus();
      return;
    }

    // La solidité est vérifiée à l'inscription et au changement de mot de
    // passe. À la connexion, seul le serveur juge : imposer un format ici
    // empêcherait d'entrer un mot de passe renforcé (caractères spéciaux).

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

      // Le compteur du serveur repart de zéro après une connexion réussie : le
      // décompte local n'a plus lieu d'être.
      _leverBlocage();

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

        // Blocage : le bandeau orange prend le relais et décompte le délai
        // restant fourni par le serveur.
        if (apiError.type == ApiErrorType.accountLocked) {
          await _memoriserBlocage(identifier, apiError.retryAfterSeconds);
        }

        if (!mounted) return;

        // Refus propre à un champ : le message se pose dessous, et le curseur
        // revient sur la case à corriger.
        final feedback = feedbackConnexion(
          apiError,
          identifiantEstEmail: isEmail,
        );
        if (feedback.aUneErreurDeChamp) {
          setState(() {
            _erreurIdentifiant = feedback.erreurIdentifiant;
            _erreurMotDePasse = feedback.erreurMotDePasse;
          });

          if (feedback.erreurIdentifiant != null) {
            identifierFocus.requestFocus();
          } else {
            // Le mot de passe saisi n'est pas effacé : le client peut l'afficher
            // et corriger sa faute de frappe sans le retaper.
            passwordFocus.requestFocus();
          }
          return;
        }

        // Un compte supprimé ou bloqué n'est pas une erreur de saisie : le
        // message informe sans accuser le client d'avoir mal tapé son mot de
        // passe.
        final isServerIssue =
            apiError.type == ApiErrorType.serverUnavailable ||
            apiError.type == ApiErrorType.network ||
            apiError.type == ApiErrorType.accountDeleted ||
            apiError.type == ApiErrorType.accountLocked;
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

  /// Précision sous un champ : ce qu'il accepte, en une ligne.
  Widget _buildFieldHint(String texte) {
    return Text(
      texte,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Colors.white.withValues(alpha: 0.78),
        height: 1.4,
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
      onChanged: _onIdentifiantSaisi,
      onSubmitted: (_) => passwordFocus.requestFocus(),
      style: const TextStyle(color: passwordRecoveryInk),
      decoration: passwordRecoveryFieldDecoration(
        hint: 'ex: +22890000000',
        errorText: _erreurIdentifiant,
        leading: const Icon(
          Icons.person_outline,
          color: Color(0xFF7A7A7A),
          size: 20,
        ),
        // Le champ vide propose « Coller » ; une fois rempli, la place revient
        // à l'effacement.
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (identifierController.text.isEmpty)
              ClipboardPasteAction(
                controller: identifierController,
                focusNode: identifierFocus,
              ),
            if (identifierController.text.isNotEmpty)
              IconButton(
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
          ],
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
      onChanged: _onMotDePasseSaisi,
      onSubmitted: (_) => login(),
      style: const TextStyle(color: passwordRecoveryInk),
      decoration: passwordRecoveryFieldDecoration(
        hint: 'Votre mot de passe',
        errorText: _erreurMotDePasse,
        leading: const Icon(
          Icons.lock_outline,
          color: Color(0xFF7A7A7A),
          size: 20,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (passwordController.text.isEmpty)
              ClipboardPasteAction(
                controller: passwordController,
                focusNode: passwordFocus,
                trim: false,
              ),
            IconButton(
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
          ],
        ),
      ),
    );
  }

  /// Bandeau de blocage : il porte le seul chiffre qui compte pour le client —
  /// le temps qu'il reste avant de pouvoir réessayer.
  Widget _buildBlocageBanner(Duration restant) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFB45309),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_clock_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Compte bloqué — réessayez dans '
                    '${libelleDelaiRestant(restant)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Quatre tentatives ont échoué sur ce compte. Le blocage se '
                    'lève seul à la fin du décompte.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
      description:
          'Ravi de vous revoir 👋. Accédez à votre espace Topographie et BTP 👷‍♂️.',
      backTooltip: 'Quitter la connexion',
      onBack: () => Navigator.maybePop(context),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_estBloque) ...[
            _buildBlocageBanner(_blocageRestant!),
            const SizedBox(height: 20),
          ],
          _buildFieldLabel('Email ou téléphone'),
          const SizedBox(height: 8),
          _buildIdentifierField(),
          const SizedBox(height: 8),
          _buildFieldHint(
            'nom@domaine.com, ou le numéro au format +228 suivi de 8 ou 9 chiffres.',
          ),
          const SizedBox(height: 18),
          _buildFieldLabel('Mot de passe'),
          const SizedBox(height: 8),
          _buildPasswordField(),
          const SizedBox(height: 8),
          _buildFieldHint(
            'Celui choisi à l’inscription. Majuscules, minuscules, chiffres, '
            'symboles et espaces sont acceptés ; la casse compte.',
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
      primaryLabel: _estBloque ? 'Connexion bloquée' : 'Se connecter',
      primaryLoadingLabel: 'Connexion…',
      isLoading: isLoading,
      onPrimary: _estBloque ? null : login,
    );
  }
}
