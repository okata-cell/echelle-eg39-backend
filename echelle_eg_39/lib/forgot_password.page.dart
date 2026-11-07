// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261107-B7D2

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api_service.dart';
import 'company_contact.dart';
import 'login.page.dart';
import 'password_recovery_contact_mask.dart';
import 'password_recovery_scaffold.dart';
import 'reset_password.page.dart';
import 'widgets/temporary_password_dialog.dart';

/// Récupération d'accès sans e-mail ni SMS.
///
/// L'identité est prouvée par le code de récupération remis à la création du
/// compte : connaître une adresse ne suffit donc pas. Le serveur répond avec un
/// mot de passe temporaire, affiché deux minutes, que le client peut remplacer
/// immédiatement ou à sa première connexion.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    super.key,
    this.requestCode = ApiService.requestPasswordReset,
    this.updatePassword = ApiService.resetPassword,
    this.clearResetToken = ApiService.removeTempToken,
  });

  final PasswordResetCodeRequester requestCode;
  final PasswordUpdater updatePassword;
  final PasswordRecoveryTokenCleaner clearResetToken;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final codeController = TextEditingController();

  RecoveryContactType _contactType = RecoveryContactType.email;
  bool _isLoading = false;
  String? _requestError;

  @override
  void dispose() {
    emailController.dispose();
    phoneController.dispose();
    codeController.dispose();
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

  String? _validateRecoveryCode(String? value) {
    final compact = (value ?? '').replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (compact.isEmpty) return 'Entrez votre code de récupération.';
    if (compact.length != 8 && compact.length != 12) {
      return 'Le code compte 8 caractères, par exemple EG39-ABCD-EFGH.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isLoading || !(_formKey.currentState?.validate() ?? false)) return;

    final contact = _activeController.text.trim();
    final type = _contactType;
    final recoveryCode = codeController.text.trim();

    setState(() {
      _isLoading = true;
      _requestError = null;
    });

    try {
      try {
        await widget.clearResetToken();
      } catch (_) {
        // Un jeton périmé ne doit pas empêcher une nouvelle demande.
      }

      final result = await widget.requestCode(
        contact,
        type.apiValue,
        recoveryCode,
      );
      if (!mounted) return;

      final temporaryPassword =
          result['temporaryPassword']?.toString().trim() ?? '';
      if (result['success'] != true || temporaryPassword.isEmpty) {
        setState(() {
          _isLoading = false;
          _requestError =
              result['error']?.toString() ??
              result['message']?.toString() ??
              'Récupération impossible. Vérifiez vos informations.';
        });
        return;
      }

      setState(() => _isLoading = false);

      final seconds = (result['displaySeconds'] as num?)?.toInt() ?? 120;
      final action = await showTemporaryPasswordDialog(
        context,
        password: temporaryPassword,
        duration: Duration(seconds: seconds),
      );
      if (!mounted) return;

      if (action == TemporaryPasswordAction.chooseOwn) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResetPasswordPage(
              contactInfo: contact,
              contactType: type,
              updatePassword: widget.updatePassword,
              clearResetToken: widget.clearResetToken,
            ),
          ),
        );
        return;
      }

      await _backToSignIn();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _requestError = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _requestError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Le client garde le mot de passe temporaire : retour à la connexion.
  Future<void> _backToSignIn() async {
    try {
      await widget.clearResetToken();
    } catch (_) {
      // Sans importance : le jeton expirera de lui-même.
    }
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginPage(
          noticeMessage:
              'Connectez-vous avec votre mot de passe temporaire. '
              'Vous choisirez ensuite votre mot de passe définitif.',
        ),
      ),
      (route) => false,
    );
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

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildContactField() {
    final isEmail = _contactType.isEmail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(isEmail ? 'Adresse e-mail' : 'Numéro de téléphone'),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey(isEmail ? 'recovery-email' : 'recovery-phone'),
          controller: _activeController,
          enabled: !_isLoading,
          keyboardType: isEmail
              ? TextInputType.emailAddress
              : TextInputType.phone,
          textInputAction: TextInputAction.next,
          autofillHints: [
            isEmail ? AutofillHints.email : AutofillHints.telephoneNumber,
          ],
          validator: _validateContact,
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

  Widget _buildRecoveryCodeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Code de récupération'),
        const SizedBox(height: 8),
        TextFormField(
          key: const ValueKey('recovery-code'),
          controller: codeController,
          enabled: !_isLoading,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\- ]')),
            LengthLimitingTextInputFormatter(14),
          ],
          validator: _validateRecoveryCode,
          onFieldSubmitted: (_) => _submit(),
          style: const TextStyle(
            color: passwordRecoveryInk,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
          decoration: passwordRecoveryFieldDecoration(
            hint: 'EG39-ABCD-EFGH',
            leading: const Icon(
              Icons.key_outlined,
              color: Color(0xFF7A7A7A),
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
      stepLabel: 'Récupération · Identification',
      title: 'Retrouver l’accès à votre compte',
      description:
          'Saisissez le contact du compte et le code de récupération remis à '
          'sa création.',
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
            const SizedBox(height: 22),
            _buildContactField(),
            const SizedBox(height: 18),
            _buildRecoveryCodeField(),
            const SizedBox(height: 14),
            Text(
              'Ce code vous a été remis une seule fois, à la création du '
              'compte (format EG39-XXXX-XXXX). Code perdu ? Écrivez à '
              '${CompanyContact.email} ou appelez le '
              '${CompanyContact.phoneDisplay} : l’agence vous en génère un '
              'nouveau après vérification.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
      errorMessage: _requestError,
      primaryLabel: 'Obtenir mon accès',
      primaryLoadingLabel: 'Vérification…',
      isLoading: _isLoading,
      onPrimary: _submit,
    );
  }
}
