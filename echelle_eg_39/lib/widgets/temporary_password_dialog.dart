// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261107-A1C4

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../profile_theme.dart';

/// Ce que le client a choisi à la fermeture du popup.
enum TemporaryPasswordAction {
  /// Il garde le mot de passe temporaire pour se connecter.
  close,

  /// Il préfère choisir lui-même son mot de passe tout de suite.
  chooseOwn,
}

const _badgeInk = Color(0xFF0A5AA8);
const _badgeSurface = Color(0xFFEAF3FC);
const _trackSurface = Color(0xFFE9EDF2);
const _noteSurface = Color(0xFFFFF8E8);
const _noteBorder = Color(0xFFF4E4BF);
const _noteInk = Color(0xFF7A5716);
const _noteInkStrong = Color(0xFF6A4A0E);

/// Affiche le mot de passe temporaire pendant deux minutes.
///
/// Le serveur ne conserve que son hachage : c'est la seule occasion de le voir.
/// La fermeture est automatique à l'échéance, mais le mot de passe reste
/// utilisable jusqu'à ce que le client en choisisse un autre.
Future<TemporaryPasswordAction> showTemporaryPasswordDialog(
  BuildContext context, {
  required String password,
  Duration duration = const Duration(seconds: 120),
}) async {
  final action = await showDialog<TemporaryPasswordAction>(
    context: context,
    barrierDismissible: false,
    builder: (_) => TemporaryPasswordDialog(password: password, duration: duration),
  );
  return action ?? TemporaryPasswordAction.close;
}

class TemporaryPasswordDialog extends StatefulWidget {
  const TemporaryPasswordDialog({
    super.key,
    required this.password,
    this.duration = const Duration(seconds: 120),
  });

  final String password;
  final Duration duration;

  @override
  State<TemporaryPasswordDialog> createState() =>
      _TemporaryPasswordDialogState();
}

class _TemporaryPasswordDialogState extends State<TemporaryPasswordDialog> {
  late int _remainingSeconds;
  Timer? _ticker;
  String? _copyError;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.duration.inSeconds;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        _ticker?.cancel();
        Navigator.of(context).pop(TemporaryPasswordAction.close);
        return;
      }
      setState(() => _remainingSeconds -= 1);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String get _countdownLabel {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return 'Se ferme dans $minutes:$seconds';
  }

  double get _progress {
    final total = widget.duration.inSeconds;
    if (total <= 0) return 0;
    return (_remainingSeconds / total).clamp(0, 1).toDouble();
  }

  Future<void> _copyAndClose() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.password));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _copyError = 'La copie a échoué. Notez le mot de passe avant de fermer.';
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(TemporaryPasswordAction.close);
  }

  void _chooseOwn() {
    Navigator.of(context).pop(TemporaryPasswordAction.chooseOwn);
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Semantics(
          scopesRoute: true,
          explicitChildNodes: true,
          namesRoute: true,
          label: 'Mot de passe temporaire',
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Material(
                color: ProfileTokens.surface,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 21, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
                          decoration: BoxDecoration(
                            color: _badgeSurface,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.lock_clock_rounded,
                                size: 13,
                                color: _badgeInk,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'MOT DE PASSE TEMPORAIRE',
                                style: _text(
                                  9.5,
                                  FontWeight.w800,
                                  color: _badgeInk,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Votre accès est rétabli',
                        style: _text(
                          21,
                          FontWeight.w800,
                          height: 1.2,
                          letterSpacing: -0.55,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Connectez-vous avec ce mot de passe, puis choisissez '
                        'le vôtre. Il ne sera plus affiché.',
                        style: _text(
                          12,
                          FontWeight.w400,
                          color: ProfileTokens.muted,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 17,
                        ),
                        decoration: BoxDecoration(
                          color: ProfileTokens.surfaceMuted,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ProfileTokens.border),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'MOT DE PASSE',
                              style: _text(
                                9,
                                FontWeight.w800,
                                color: const Color(0xFF8A929C),
                                letterSpacing: 1.17,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Semantics(
                              label:
                                  'Mot de passe temporaire : ${widget.password}',
                              child: ExcludeSemantics(
                                child: Text(
                                  widget.password,
                                  textAlign: TextAlign.center,
                                  style: _text(
                                    26,
                                    FontWeight.w800,
                                    height: 1.3,
                                    letterSpacing: 4.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 13),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _countdownLabel,
                              style: _text(
                                11.5,
                                FontWeight.w600,
                                color: ProfileTokens.muted,
                              ),
                            ),
                          ),
                          Text(
                            '${widget.duration.inMinutes} min',
                            style: _text(
                              11.5,
                              FontWeight.w400,
                              color: ProfileTokens.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 4,
                          backgroundColor: _trackSurface,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            ProfileTokens.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 13),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _noteSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _noteBorder),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(
                                Icons.info_outline_rounded,
                                size: 15,
                                color: _noteInk,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  text: 'Changement obligatoire. ',
                                  style: _text(
                                    11,
                                    FontWeight.w800,
                                    color: _noteInkStrong,
                                    height: 1.55,
                                  ),
                                  children: [
                                    TextSpan(
                                      text:
                                          'À votre prochaine connexion, '
                                          'l’application vous demandera de '
                                          'définir votre propre mot de passe.',
                                      style: _text(
                                        11,
                                        FontWeight.w400,
                                        color: _noteInk,
                                        height: 1.55,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_copyError != null) ...[
                        const SizedBox(height: 12),
                        Semantics(
                          liveRegion: true,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: ProfileTokens.dangerSurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: ProfileTokens.danger.withValues(
                                  alpha: 0.24,
                                ),
                              ),
                            ),
                            child: Text(
                              _copyError!,
                              style: _text(
                                11.5,
                                FontWeight.w600,
                                color: ProfileTokens.danger,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 15),
                      SizedBox(
                        height: 51,
                        child: ElevatedButton.icon(
                          key: const ValueKey('temporary-password-copy-close'),
                          onPressed: _copyAndClose,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ProfileTokens.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: _text(14, FontWeight.w800),
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('Copier et fermer'),
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        key: const ValueKey('temporary-password-choose-own'),
                        onPressed: _chooseOwn,
                        style: TextButton.styleFrom(
                          foregroundColor: ProfileTokens.primary,
                          minimumSize: const Size(44, 44),
                          textStyle: _text(13, FontWeight.w600),
                        ),
                        child: const Text('Choisir mon mot de passe'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
