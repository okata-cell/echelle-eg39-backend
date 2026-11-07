// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../profile_theme.dart';

/// Couleurs propres au récapitulatif d’identifiants.
const _successInk = Color(0xFF18794E);
const _successSurface = Color(0xFFE7F4ED);
const _noteSurface = Color(0xFFFFF8E8);
const _noteBorder = Color(0xFFF4E4BF);
const _noteInk = Color(0xFF7A5716);
const _noteInkStrong = Color(0xFF6A4A0E);
const _rowDivider = Color(0xFFE9EDF2);
const _rowIconBorder = Color(0xFFE4E9EF);
const _rowIconInk = Color(0xFF6B7683);
const _rowLabelInk = Color(0xFF8A929C);
const _footInk = Color(0xFF8A929C);

/// Coordonnées affichées une seule fois, juste après la création du compte.
///
/// Le mot de passe n’est jamais stocké en clair : cette valeur transite
/// directement du formulaire à la boîte de dialogue, puis au presse-papiers
/// si le client le demande.
@immutable
class AccountCredentials {
  const AccountCredentials({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.password,
    this.recoveryCode,
    this.isPendingSync = false,
  });

  final String firstName;
  final String lastName;
  final String email;

  /// Numéro complet tel qu’envoyé au serveur, par exemple `+22890000000`.
  final String phone;
  final String password;

  /// Code `EG39-XXXX-XXXX` remis par le serveur à la création du compte.
  ///
  /// C'est la seule preuve d'identité utilisable en cas de mot de passe
  /// oublié : sans e-mail ni SMS, il est indispensable. `null` quand
  /// l'inscription attend encore la synchronisation.
  final String? recoveryCode;

  /// `true` quand l'inscription attend encore le réseau.
  final bool isPendingSync;

  String get fullName => [
    firstName,
    lastName,
  ].where((part) => part.trim().isNotEmpty).join(' ').trim();

  /// Numéro lisible : `+228 90 12 34 567`.
  String get phoneDisplay => formatAccountPhone(phone);

  /// Contenu déposé dans le presse-papiers.
  String get clipboardText {
    final buffer = StringBuffer()
      ..writeln('ÉCHELLE EG39 — Identifiants de compte')
      ..writeln('E-mail : $email')
      ..writeln('Téléphone : $phoneDisplay')
      ..writeln('Mot de passe : $password');

    final code = recoveryCode?.trim() ?? '';
    if (code.isNotEmpty) {
      buffer.writeln('Code de récupération : $code');
    }

    buffer
      ..writeln()
      ..write(
        code.isEmpty
            ? 'Gardez ces coordonnées dans un endroit sûr : elles sont '
                  'nécessaires pour vous reconnecter plus tard.'
            : 'Gardez ces coordonnées dans un endroit sûr. Le code de '
                  'récupération permet de retrouver l’accès si vous oubliez '
                  'votre mot de passe.',
      );
    return buffer.toString();
  }
}

/// Regroupe un numéro togolais par paires de deux chiffres.
///
/// Les inscriptions acceptent 8 ou 9 chiffres après `+228` : le dernier groupe
/// garde donc trois chiffres pour les numéros à 9.
String formatAccountPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return phone;

  const prefix = '+228';
  final local = digits.startsWith('228') && digits.length > 8
      ? digits.substring(3)
      : digits;

  final groups = <String>[];
  var index = 0;
  while (index < local.length) {
    final remaining = local.length - index;
    final size = remaining == 3 ? 3 : 2;
    groups.add(local.substring(index, index + size));
    index += size;
  }
  return groups.isEmpty ? phone : '$prefix ${groups.join(' ')}';
}

/// Affiche le récapitulatif et renvoie `true` si le client a copié ses
/// coordonnées et fermé la boîte de dialogue.
Future<bool> showAccountCredentialsDialog(
  BuildContext context,
  AccountCredentials credentials,
) async {
  final copied = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AccountCredentialsDialog(credentials: credentials),
  );
  return copied ?? false;
}

/// Carte « fiche d’identifiants » : e-mail, téléphone et mot de passe
/// regroupés dans un seul bloc, avec un rappel de conservation.
class AccountCredentialsDialog extends StatefulWidget {
  const AccountCredentialsDialog({super.key, required this.credentials});

  final AccountCredentials credentials;

  @override
  State<AccountCredentialsDialog> createState() =>
      _AccountCredentialsDialogState();
}

class _AccountCredentialsDialogState extends State<AccountCredentialsDialog> {
  String? _copyError;

  Future<void> _copyAndClose() async {
    try {
      await Clipboard.setData(
        ClipboardData(text: widget.credentials.clipboardText),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _copyError =
            'La copie a échoué. Notez ces informations avant de fermer.';
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
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

  Widget _credentialRow({
    required IconData icon,
    required String label,
    required String value,
    bool isPassword = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 32,
            decoration: BoxDecoration(
              color: ProfileTokens.surface,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _rowIconBorder),
            ),
            child: Icon(icon, size: 15, color: _rowIconInk),
          ),
          const SizedBox(width: 11),
          Expanded(
            // Une seule annonce « E-mail : … » au lieu d’une valeur nue.
            child: Semantics(
              label: '$label : $value',
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: _text(
                        9,
                        FontWeight.w800,
                        color: _rowLabelInk,
                        letterSpacing: 1.17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: _text(
                        isPassword ? 20 : 14.5,
                        FontWeight.w800,
                        height: 1.35,
                        letterSpacing: isPassword ? 2.6 : -0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final credentials = widget.credentials;
    final recoveryCode = (credentials.recoveryCode ?? '').trim();
    final subtitle = credentials.isPendingSync
        ? 'L’inscription de ${credentials.fullName} est enregistrée. '
              'Voici ce qu’il faut conserver.'
        : 'Le compte de ${credentials.fullName} est actif. '
              'Voici ce qu’il faut conserver.';

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
          label: 'Vos identifiants de connexion',
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
                            color: _successSurface,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_rounded,
                                size: 13,
                                color: _successInk,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'COMPTE CRÉÉ',
                                style: _text(
                                  9.5,
                                  FontWeight.w800,
                                  color: _successInk,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Vos identifiants de connexion',
                        style: _text(
                          21,
                          FontWeight.w800,
                          height: 1.2,
                          letterSpacing: -0.55,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: _text(
                          12,
                          FontWeight.w400,
                          color: ProfileTokens.muted,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: ProfileTokens.surfaceMuted,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ProfileTokens.border),
                        ),
                        child: Column(
                          children: [
                            _credentialRow(
                              icon: Icons.mail_outline_rounded,
                              label: 'E-mail',
                              value: credentials.email,
                            ),
                            const Divider(
                              height: 1,
                              thickness: 1,
                              color: _rowDivider,
                            ),
                            _credentialRow(
                              icon: Icons.phone_outlined,
                              label: 'Téléphone',
                              value: credentials.phoneDisplay,
                            ),
                            const Divider(
                              height: 1,
                              thickness: 1,
                              color: _rowDivider,
                            ),
                            _credentialRow(
                              icon: Icons.key_rounded,
                              label: 'Mot de passe',
                              value: credentials.password,
                              isPassword: true,
                            ),
                            if (recoveryCode.isNotEmpty) ...[
                              const Divider(
                                height: 1,
                                thickness: 1,
                                color: _rowDivider,
                              ),
                              _credentialRow(
                                icon: Icons.pin_outlined,
                                label: 'Code de récupération',
                                value: recoveryCode,
                                isPassword: true,
                              ),
                            ],
                          ],
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
                                Icons.lock_outline_rounded,
                                size: 15,
                                color: _noteInk,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  text:
                                      'Gardez ces coordonnées dans un endroit '
                                      'sûr. ',
                                  style: _text(
                                    11,
                                    FontWeight.w800,
                                    color: _noteInkStrong,
                                    height: 1.55,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: recoveryCode.isEmpty
                                          ? 'Elles sont nécessaires pour vous '
                                                'reconnecter plus tard.'
                                          : 'Le code de récupération permet de '
                                                'retrouver l’accès si vous '
                                                'oubliez votre mot de passe.',
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
                          key: const ValueKey('account-credentials-copy-close'),
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
                      const SizedBox(height: 9),
                      Text(
                        'Vous serez redirigé vers l’accueil',
                        textAlign: TextAlign.center,
                        style: _text(
                          10,
                          FontWeight.w400,
                          color: _footInk,
                          height: 1.4,
                        ),
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
