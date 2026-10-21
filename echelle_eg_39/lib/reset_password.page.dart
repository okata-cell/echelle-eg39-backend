import 'package:flutter/material.dart';

import 'login.page.dart';
import 'password_recovery_contact_mask.dart';
import 'password_recovery_scaffold.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    required this.contactInfo,
    required this.contactType,
    required this.updatePassword,
    required this.clearResetToken,
  });

  final String contactInfo;
  final RecoveryContactType contactType;
  final PasswordUpdater updatePassword;
  final PasswordRecoveryTokenCleaner clearResetToken;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _requestError;
  bool _didUpdatePassword = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateNewPassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Saisissez votre nouveau mot de passe.';
    if (password.length < 6 ||
        !RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password)) {
      return '6 caractères minimum, dont une lettre et un chiffre.';
    }
    return null;
  }

  String? _validateConfirmation(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirmez votre nouveau mot de passe.';
    }
    if (value != _newPasswordController.text) {
      return 'Les mots de passe ne correspondent pas.';
    }
    return null;
  }

  Future<void> _updatePassword() async {
    if (_isLoading ||
        _didUpdatePassword ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isLoading = true;
      _requestError = null;
      _didUpdatePassword = false;
    });

    try {
      final result = await widget.updatePassword(_newPasswordController.text);
      if (!mounted) return;
      if (result['success'] != true) {
        setState(() {
          _requestError =
              result['error']?.toString() ??
              'Impossible de mettre à jour le mot de passe. Réessayez.';
        });
        return;
      }

      try {
        await widget.clearResetToken();
      } catch (_) {
        // ApiService already removes the reset token on successful responses.
      }
      if (!mounted) return;
      setState(() {
        _didUpdatePassword = true;
        _isLoading = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _requestError = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPasswordField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool obscureText,
    required String? Function(String?) validator,
    required VoidCallback onToggle,
    required String visibilityTooltip,
    Key? fieldKey,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: fieldKey,
          controller: controller,
          enabled: !_isLoading,
          obscureText: obscureText,
          textInputAction: label == 'Confirmer le nouveau mot de passe'
              ? TextInputAction.done
              : TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: label == 'Confirmer le nouveau mot de passe'
              ? (_) => _updatePassword()
              : null,
          style: const TextStyle(
            color: passwordRecoveryInk,
            fontWeight: FontWeight.w600,
          ),
          decoration: passwordRecoveryFieldDecoration(
            hint: hint,
            leading: const Icon(
              Icons.lock_outline_rounded,
              color: Color(0xFF7A7A7A),
              size: 20,
            ),
            trailing: IconButton(
              tooltip: visibilityTooltip,
              onPressed: _isLoading ? null : onToggle,
              icon: Icon(
                obscureText
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: const Color(0xFF333333),
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final maskedContact = maskRecoveryContact(
      widget.contactInfo,
      isEmail: widget.contactType.isEmail,
    );
    return PasswordRecoveryScaffold(
      stepLabel: '3 sur 3 · Mot de passe',
      title: 'Choisissez un nouveau mot de passe',
      description: 'Créez un mot de passe sûr pour protéger votre compte.',
      backTooltip: 'Retour à la vérification du code',
      onBack: () => Navigator.maybePop(context),
      contextStatus: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: Color(0xFF2997FF),
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Contact vérifié : $maskedContact',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.92),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPasswordField(
              fieldKey: const ValueKey('recovery-new-password'),
              label: 'Nouveau mot de passe',
              hint: '••••••••',
              controller: _newPasswordController,
              obscureText: _obscureNewPassword,
              validator: _validateNewPassword,
              onToggle: () =>
                  setState(() => _obscureNewPassword = !_obscureNewPassword),
              visibilityTooltip: _obscureNewPassword
                  ? 'Afficher le nouveau mot de passe'
                  : 'Masquer le nouveau mot de passe',
              onChanged: (_) => _formKey.currentState?.validate(),
            ),
            const SizedBox(height: 20),
            _buildPasswordField(
              fieldKey: const ValueKey('recovery-confirm-password'),
              label: 'Confirmer le nouveau mot de passe',
              hint: 'Saisissez-le à nouveau',
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              validator: _validateConfirmation,
              onToggle: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
              visibilityTooltip: _obscureConfirmPassword
                  ? 'Afficher la confirmation du mot de passe'
                  : 'Masquer la confirmation du mot de passe',
            ),
          ],
        ),
      ),
      errorMessage: _requestError,
      primaryLabel: _didUpdatePassword
          ? 'Mot de passe mis à jour'
          : 'Mettre à jour le mot de passe',
      primaryLoadingLabel: 'Mise à jour…',
      onPrimary: _didUpdatePassword ? null : _updatePassword,
      isLoading: _isLoading,
      secondaryContent: _didUpdatePassword
          ? Text(
              'Retour à la connexion…',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
            )
          : null,
    );
  }
}
