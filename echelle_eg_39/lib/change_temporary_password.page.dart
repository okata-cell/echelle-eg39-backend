// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261107-A1C4

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'AdminDashBoard.dart';
import 'api_service.dart';
import 'login.page.dart';
import 'main.dart';
import 'profile_theme.dart';

/// Écran imposé après une connexion avec un mot de passe temporaire.
///
/// Le client ne peut pas accéder à l'application avant d'avoir choisi son
/// propre mot de passe. Il garde toujours la possibilité de se déconnecter.
class ChangeTemporaryPasswordPage extends StatefulWidget {
  const ChangeTemporaryPasswordPage({
    super.key,
    this.isAdmin = false,
    this.changePassword = ApiService.changeTemporaryPassword,
    this.homeBuilder,
  });

  final bool isAdmin;
  final Future<void> Function(String newPassword) changePassword;

  /// Remplaçable en test : construit l'écran d'accueil après enregistrement.
  final Widget Function()? homeBuilder;

  @override
  State<ChangeTemporaryPasswordPage> createState() =>
      _ChangeTemporaryPasswordPageState();
}

class _ChangeTemporaryPasswordPageState
    extends State<ChangeTemporaryPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isSaving = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Saisissez votre nouveau mot de passe.';
    if (!RegExp(r'^\d{4}[A-Z]{4}$').hasMatch(password)) {
      return '4 chiffres puis 4 lettres majuscules (ex. 1234AZER).';
    }
    return null;
  }

  String? _validateConfirmation(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirmez votre nouveau mot de passe.';
    }
    if (value != _passwordController.text) {
      return 'Les deux mots de passe ne correspondent pas.';
    }
    return null;
  }

  Future<void> _save() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.changePassword(_passwordController.text);
      if (!mounted) return;

      final home =
          widget.homeBuilder?.call() ??
          (widget.isAdmin ? const AdminDashBoard() : const MainScreen());

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => home),
        (route) => false,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage =
            'Enregistrement impossible pour le moment. Réessayez plus tard.';
      });
    }
  }

  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await ApiService.removeToken();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('isAdmin');
    await prefs.remove('userIdentifier');
    await prefs.remove('userEmail');
    await prefs.remove('userPhone');
    await prefs.remove('userName');

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  TextStyle _text(
    double size,
    FontWeight weight, {
    Color color = ProfileTokens.ink,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  InputDecoration _decoration({
    required String label,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: ProfileTokens.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ProfileTokens.radiusField),
        borderSide: const BorderSide(color: ProfileTokens.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ProfileTokens.radiusField),
        borderSide: const BorderSide(color: ProfileTokens.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ProfileTokens.radiusField),
        borderSide: const BorderSide(color: ProfileTokens.primary, width: 2),
      ),
      suffixIcon: IconButton(
        onPressed: onToggle,
        tooltip: obscure ? 'Afficher' : 'Masquer',
        icon: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 20,
          color: ProfileTokens.muted,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: ProfileTokens.canvas,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(9, 6, 12, 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF3FC),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_clock_rounded,
                            size: 13,
                            color: Color(0xFF0A5AA8),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'MOT DE PASSE TEMPORAIRE',
                              overflow: TextOverflow.ellipsis,
                              style: _text(
                                9.5,
                                FontWeight.w800,
                                color: const Color(0xFF0A5AA8),
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Choisissez votre mot de passe',
                      style: _text(
                        24,
                        FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Vous vous êtes connecté avec un mot de passe '
                      'temporaire. Définissez celui que vous utiliserez '
                      'désormais.',
                      style: _text(
                        12.5,
                        FontWeight.w400,
                        color: ProfileTokens.muted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            key: const ValueKey('temporary-new-password'),
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            enableSuggestions: false,
                            style: _text(15, FontWeight.w600, letterSpacing: 1.2),
                            validator: _validatePassword,
                            onChanged: (_) => setState(() {
                              _errorMessage = null;
                            }),
                            decoration: _decoration(
                              label: 'Nouveau mot de passe',
                              hint: '1234AZER',
                              obscure: _obscurePassword,
                              onToggle: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const ValueKey('temporary-confirm-password'),
                            controller: _confirmController,
                            obscureText: _obscureConfirm,
                            textInputAction: TextInputAction.done,
                            autocorrect: false,
                            enableSuggestions: false,
                            style: _text(15, FontWeight.w600, letterSpacing: 1.2),
                            validator: _validateConfirmation,
                            onChanged: (_) => setState(() {
                              _errorMessage = null;
                            }),
                            onFieldSubmitted: (_) => _save(),
                            decoration: _decoration(
                              label: 'Confirmer le mot de passe',
                              hint: '1234AZER',
                              obscure: _obscureConfirm,
                              onToggle: () => setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '4 chiffres puis 4 lettres majuscules, comme à la '
                      'connexion.',
                      style: _text(
                        11,
                        FontWeight.w400,
                        color: ProfileTokens.muted,
                        height: 1.45,
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: ProfileTokens.dangerSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: ProfileTokens.danger.withValues(alpha: 0.24),
                            ),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: _text(
                              12,
                              FontWeight.w600,
                              color: ProfileTokens.danger,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        key: const ValueKey('temporary-password-save'),
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ProfileTokens.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          disabledBackgroundColor: ProfileTokens.primary
                              .withValues(alpha: 0.45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: _text(15, FontWeight.w800),
                        ),
                        child: _isSaving
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Enregistrer mon mot de passe'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: _isSaving ? null : _signOut,
                      style: TextButton.styleFrom(
                        foregroundColor: ProfileTokens.muted,
                        minimumSize: const Size(44, 44),
                        textStyle: _text(12.5, FontWeight.w600),
                      ),
                      child: const Text('Se déconnecter'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
