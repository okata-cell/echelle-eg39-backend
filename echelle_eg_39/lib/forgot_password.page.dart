import 'package:flutter/material.dart';

import 'api_service.dart';
import 'password_recovery_contact_mask.dart';
import 'password_recovery_scaffold.dart';
import 'verify_code.page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    super.key,
    this.requestCode = ApiService.requestPasswordReset,
    this.verifyCode = ApiService.verifyResetCode,
    this.updatePassword = ApiService.resetPassword,
    this.clearResetToken = ApiService.removeTempToken,
  });

  final PasswordResetCodeRequester requestCode;
  final PasswordResetCodeVerifier verifyCode;
  final PasswordUpdater updatePassword;
  final PasswordRecoveryTokenCleaner clearResetToken;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();

  RecoveryContactType _contactType = RecoveryContactType.email;
  bool _isLoading = false;
  String? _requestError;

  @override
  void dispose() {
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  TextEditingController get _activeController =>
      _contactType.isEmail ? emailController : phoneController;

  String? _validateContact(String? value) {
    final contact = value?.trim() ?? '';
    if (contact.isEmpty) {
      return _contactType.isEmail
          ? 'Entrez votre adresse e-mail.'
          : 'Entrez votre numéro de téléphone.';
    }
    if (_contactType.isEmail &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(contact)) {
      return 'Vérifiez le format de votre adresse e-mail.';
    }
    return null;
  }

  Future<void> _requestResetCode() async {
    if (_isLoading || !(_formKey.currentState?.validate() ?? false)) return;

    final contact = _activeController.text.trim();
    final type = _contactType;
    setState(() {
      _isLoading = true;
      _requestError = null;
    });

    try {
      try {
        await widget.clearResetToken();
      } catch (_) {
        // A stale token must not prevent a new recovery request.
      }
      final result = await widget.requestCode(contact, type.apiValue);
      if (!mounted) return;
      if (result['success'] != true) {
        setState(() {
          _requestError =
              result['message']?.toString() ??
              'Impossible de lancer la récupération. Réessayez.';
        });
        return;
      }

      final returnedContact = result['contactInfo']?.toString().trim();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyCodePage(
            contactInfo: returnedContact == null || returnedContact.isEmpty
                ? contact
                : returnedContact,
            contactType: type,
            initialNotice:
                'Si un compte existe avec ce contact, vous recevrez un code.',
            requestCode: widget.requestCode,
            verifyCode: widget.verifyCode,
            updatePassword: widget.updatePassword,
            clearResetToken: widget.clearResetToken,
          ),
        ),
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

  Widget _buildChannelButton(RecoveryContactType type) {
    final selected = _contactType == type;
    final icon = type.isEmail ? Icons.email_outlined : Icons.phone_outlined;
    return Expanded(
      child: SizedBox(
        height: 44,
        child: selected
            ? FilledButton.icon(
                onPressed: _isLoading ? null : () => _selectContactType(type),
                style: FilledButton.styleFrom(
                  backgroundColor: passwordRecoveryActionBlue,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                icon: Icon(icon, size: 18),
                label: Text(type.isEmail ? 'Email' : 'Téléphone'),
              )
            : OutlinedButton.icon(
                onPressed: _isLoading ? null : () => _selectContactType(type),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.65)),
                  shape: const StadiumBorder(),
                ),
                icon: Icon(icon, size: 18),
                label: Text(type.isEmail ? 'Email' : 'Téléphone'),
              ),
      ),
    );
  }

  void _selectContactType(RecoveryContactType type) {
    if (_contactType == type) return;
    setState(() {
      _contactType = type;
      _requestError = null;
    });
  }

  Widget _buildContactField() {
    final isEmail = _contactType.isEmail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isEmail ? 'Adresse e-mail' : 'Numéro de téléphone',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey(isEmail ? 'recovery-email' : 'recovery-phone'),
          controller: _activeController,
          enabled: !_isLoading,
          keyboardType: isEmail
              ? TextInputType.emailAddress
              : TextInputType.phone,
          textInputAction: TextInputAction.done,
          autofillHints: [
            isEmail ? AutofillHints.email : AutofillHints.telephoneNumber,
          ],
          validator: _validateContact,
          onFieldSubmitted: (_) => _requestResetCode(),
          style: const TextStyle(color: passwordRecoveryInk),
          decoration: passwordRecoveryFieldDecoration(
            hint: isEmail ? 'nom@exemple.com' : '+228 90 00 00 00',
            leading: Icon(
              isEmail ? Icons.email_outlined : Icons.phone_outlined,
              color: const Color(0xFF7A7A7A),
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PasswordRecoveryScaffold(
      stepLabel: '1 sur 3 · Contact',
      title: 'Où recevoir votre code ?',
      description: 'Choisissez l’adresse ou le numéro associé à votre compte.',
      backTooltip: 'Retour à la connexion',
      onBack: () => Navigator.maybePop(context),
      content: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildChannelButton(RecoveryContactType.email),
                const SizedBox(width: 8),
                _buildChannelButton(RecoveryContactType.phone),
              ],
            ),
            const SizedBox(height: 24),
            _buildContactField(),
            const SizedBox(height: 16),
            Text(
              'Si un compte existe avec ce contact, vous recevrez un code.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
      errorMessage: _requestError,
      primaryLabel: 'Envoyer le code',
      primaryLoadingLabel: 'Envoi du code…',
      isLoading: _isLoading,
      onPrimary: _requestResetCode,
    );
  }
}
