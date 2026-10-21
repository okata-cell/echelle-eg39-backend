import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'password_recovery_contact_mask.dart';
import 'password_recovery_scaffold.dart';
import 'reset_password.page.dart';

class VerifyCodePage extends StatefulWidget {
  const VerifyCodePage({
    super.key,
    required this.contactInfo,
    required this.contactType,
    required this.requestCode,
    required this.verifyCode,
    required this.updatePassword,
    required this.clearResetToken,
    this.initialNotice,
  });

  final String contactInfo;
  final RecoveryContactType contactType;
  final PasswordResetCodeRequester requestCode;
  final PasswordResetCodeVerifier verifyCode;
  final PasswordUpdater updatePassword;
  final PasswordRecoveryTokenCleaner clearResetToken;
  final String? initialNotice;

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage> {
  final codeController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  bool _isCodeVerified = false;
  String? _errorMessage;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _statusMessage = widget.initialNotice;
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyOrContinue() async {
    if (_isLoading) return;
    if (_isCodeVerified) {
      _openPasswordReset();
      return;
    }

    final code = codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() {
        _errorMessage = 'Saisissez les 6 chiffres du code.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = null;
    });

    try {
      final result = await widget.verifyCode(code, widget.contactInfo);
      if (!mounted) return;
      if (result['success'] == true && result['tempToken'] != null) {
        setState(() {
          _isCodeVerified = true;
          _statusMessage =
              'Code vérifié. Vous pouvez choisir un nouveau mot de passe.';
        });
        _openPasswordReset();
      } else {
        setState(() {
          _errorMessage =
              result['error']?.toString() ?? 'Code invalide ou expiré.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openPasswordReset() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResetPasswordPage(
          contactInfo: widget.contactInfo,
          contactType: widget.contactType,
          updatePassword: widget.updatePassword,
          clearResetToken: widget.clearResetToken,
        ),
      ),
    );
  }

  Future<void> _resendCode() async {
    if (_isResending || _isCodeVerified) return;
    setState(() {
      _isResending = true;
      _errorMessage = null;
      _statusMessage = null;
    });

    try {
      final result = await widget.requestCode(
        widget.contactInfo,
        widget.contactType.apiValue,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        codeController.clear();
        setState(() {
          _statusMessage =
              'Si un compte existe avec ce contact, un nouveau code sera envoyé.';
        });
      } else {
        setState(() {
          _errorMessage =
              result['message']?.toString() ??
              'Impossible de demander un nouveau code. Réessayez.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _changeContact() async {
    if (_isCodeVerified) {
      try {
        await widget.clearResetToken();
      } catch (_) {
        // Returning to contact selection remains possible even if local cleanup fails.
      }
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  Widget _buildCodeInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Code de vérification',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 60,
          child: Stack(
            children: [
              IgnorePointer(
                child: Row(
                  children: List.generate(6, (index) {
                    final value = codeController.text;
                    final hasDigit = index < value.length;
                    final isActive = index == value.length && value.length < 6;
                    return Expanded(
                      child: Container(
                        height: 60,
                        margin: EdgeInsets.only(right: index == 5 ? 0 : 7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isActive
                                ? passwordRecoveryActionBlue
                                : const Color(0xFFE0E0E0),
                            width: isActive ? 2 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          hasDigit ? value[index] : (isActive ? '|' : ''),
                          style: TextStyle(
                            color: hasDigit
                                ? passwordRecoveryInk
                                : passwordRecoveryActionBlue,
                            fontSize: hasDigit ? 22 : 25,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0.01,
                  child: TextField(
                    key: const ValueKey('recovery-otp-input'),
                    controller: codeController,
                    autofocus: false,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    maxLength: 6,
                    showCursor: false,
                    onChanged: (_) => setState(() {
                      _errorMessage = null;
                      _statusMessage = null;
                    }),
                    onSubmitted: (_) => _verifyOrContinue(),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      hintText: 'Code de vérification à 6 chiffres',
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(color: Colors.transparent),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Le code expire après 15 minutes.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_isCodeVerified) ...[
          Text(
            'Vous n’avez pas reçu le code ?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          TextButton.icon(
            key: const ValueKey('recovery-resend-code'),
            onPressed: _isResending || _isLoading ? null : _resendCode,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF2997FF),
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            icon: _isResending
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF2997FF),
                    ),
                  )
                : const Icon(Icons.refresh_rounded, size: 18),
            label: Text(_isResending ? 'Renvoi du code…' : 'Renvoyer le code'),
          ),
        ],
        TextButton(
          key: const ValueKey('recovery-change-contact'),
          onPressed: _isLoading || _isResending ? null : _changeContact,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF2997FF),
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: const Text('Changer de contact'),
        ),
        if (_statusMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Semantics(
              liveRegion: true,
              child: Text(
                _statusMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.4,
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
      stepLabel: _isCodeVerified ? '2 sur 3 · Code vérifié' : '2 sur 3 · Code',
      title: _isCodeVerified
          ? 'Votre contact est vérifié'
          : 'Entrez le code demandé pour $maskedContact',
      description: _isCodeVerified
          ? 'Continuez pour choisir un nouveau mot de passe.'
          : 'Saisissez le code de vérification à 6 chiffres.',
      onBack: () => Navigator.maybePop(context),
      backTooltip: 'Retour au choix du contact',
      content: _isCodeVerified ? const SizedBox.shrink() : _buildCodeInput(),
      secondaryContent: _buildSecondaryActions(),
      errorMessage: _errorMessage,
      primaryLabel: _isCodeVerified ? 'Continuer' : 'Vérifier le code',
      isLoading: _isLoading,
      onPrimary: _verifyOrContinue,
    );
  }
}
