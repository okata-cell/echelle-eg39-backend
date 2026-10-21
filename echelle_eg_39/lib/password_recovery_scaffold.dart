import 'package:flutter/material.dart';

const _recoveryActionBlue = Color(0xFF0066CC);
const _recoveryFocusBlue = Color(0xFF0071E3);
const _recoveryInk = Color(0xFF1D1D1F);
const _recoveryMutedInk = Color(0xFF333333);
const _recoveryMutedText = Color(0xFF7A7A7A);
const _recoveryFieldBorder = Color(0xFFE0E0E0);
const _recoveryBackground = Color(0xFF111820);
const _recoveryPhotoUrl =
    'https://images.unsplash.com/photo-1766830110938-0ea8a6d78ecb?auto=format&fit=crop&w=1100&q=85';
const _recoveryPhotoAlt =
    'Un géomètre utilisant une station totale dans un champ — Nazmul ahsan Meraz sur Unsplash';

/// Shared topographic-photo background and uniform dark scrim for auth pages.
class PasswordRecoveryPhotoBackdrop extends StatelessWidget {
  const PasswordRecoveryPhotoBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          _recoveryPhotoUrl,
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.12),
          semanticLabel: _recoveryPhotoAlt,
          errorBuilder: (context, error, stackTrace) => const ColoredBox(
            color: _recoveryBackground,
            child: Center(
              child: Icon(
                Icons.landscape_outlined,
                color: Colors.white38,
                size: 48,
              ),
            ),
          ),
        ),
        const ColoredBox(color: Color(0xB3000000)),
      ],
    );
  }
}

class PasswordRecoveryScaffold extends StatelessWidget {
  const PasswordRecoveryScaffold({
    required this.stepLabel,
    required this.title,
    required this.description,
    required this.onBack,
    required this.content,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryLoadingLabel,
    this.contextStatus,
    this.secondaryContent,
    this.errorMessage,
    this.isLoading = false,
    this.backTooltip = 'Retour à l’étape précédente',
    super.key,
  });

  final String stepLabel;
  final String title;
  final String description;
  final VoidCallback onBack;
  final Widget content;
  final String primaryLabel;
  final String? primaryLoadingLabel;
  final VoidCallback? onPrimary;
  final Widget? contextStatus;
  final Widget? secondaryContent;
  final String? errorMessage;
  final bool isLoading;
  final String backTooltip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _recoveryBackground,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PasswordRecoveryPhotoBackdrop(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 480,
                        minHeight: constraints.maxHeight - 40,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                tooltip: backTooltip,
                                onPressed: onBack,
                                style: IconButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.14,
                                  ),
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.24),
                                  ),
                                  minimumSize: const Size(44, 44),
                                ),
                                icon: const Icon(Icons.arrow_back_rounded),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ÉCHELLE EG39',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.1,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          Text(
                            stepLabel,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          if (contextStatus != null) ...[
                            const SizedBox(height: 16),
                            contextStatus!,
                          ],
                          const SizedBox(height: 14),
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  height: 1.12,
                                  letterSpacing: -0.7,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            description,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  height: 1.45,
                                ),
                          ),
                          const SizedBox(height: 28),
                          content,
                          if (errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Semantics(
                              liveRegion: true,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFBEEEB),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  errorMessage!,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: const Color(0xFF8A3324),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ),
                          ],
                          if (secondaryContent != null) ...[
                            const SizedBox(height: 12),
                            secondaryContent!,
                          ],
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: FilledButton.icon(
                              onPressed: isLoading ? null : onPrimary,
                              style: FilledButton.styleFrom(
                                backgroundColor: _recoveryActionBlue,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: _recoveryActionBlue
                                    .withValues(alpha: 0.65),
                                shape: const StadiumBorder(),
                              ),
                              icon: isLoading
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.arrow_forward_rounded),
                              label: Text(
                                isLoading
                                    ? (primaryLoadingLabel ?? 'Patientez…')
                                    : primaryLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration passwordRecoveryFieldDecoration({
  required String hint,
  Widget? leading,
  Widget? trailing,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _recoveryMutedText),
    prefixIcon: leading,
    suffixIcon: trailing,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: _recoveryFieldBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: _recoveryFieldBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: _recoveryFocusBlue, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: Color(0xFFAA5141)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: Color(0xFFAA5141), width: 2),
    ),
  );
}

const Color passwordRecoveryActionBlue = _recoveryActionBlue;
const Color passwordRecoveryInk = _recoveryInk;
const Color passwordRecoveryMutedInk = _recoveryMutedInk;
