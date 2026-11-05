import 'package:flutter/material.dart';

import '../api_service.dart';
import '../profile_theme.dart';
import 'profile_sheet.dart';

/// Suppression du compte.
///
/// L'écran explique ce qui disparaît et ce qui reste avant de demander le mot
/// de passe : la suppression est immédiate et irréversible, elle ne doit donc
/// pas pouvoir être déclenchée par inadvertance.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key, this.deleteAccount = ApiService.deleteAccount});

  /// Injectable pour les tests : aucun appel réseau n'est fait hors production.
  final Future<void> Function(String password) deleteAccount;

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final TextEditingController _passwordController = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _passwordController
      ..removeListener(_onPasswordChanged)
      ..dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    if (mounted) setState(() {});
  }

  bool get _canSubmit => _passwordController.text.isNotEmpty && !_submitting;

  static const List<String> _erased = [
    'Votre nom, votre adresse e-mail et votre numéro de téléphone',
    'Votre mot de passe et votre photo de profil',
    'Les coordonnées de l’entreprise : adresse, ville, pays',
    'Les messages envoyés au service client et leurs pièces jointes',
    'Vos demandes de formation et la note laissée sur l\'application',
  ];

  @override
  Widget build(BuildContext context) {
    return ProfileSheetScaffold(
      title: 'Supprimer mon compte',
      bottomBar: ProfileActionBar(
        children: [
          Expanded(
            child: ProfilePillButton(
              key: const ValueKey('delete-account-submit'),
              label: 'Supprimer mon compte',
              icon: Icons.delete_outline,
              danger: true,
              busy: _submitting,
              onPressed: _canSubmit ? _confirmDeletion : null,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWarning(),
          const SizedBox(height: 16),
          _buildBulletCard(
            heading: 'Ce qui sera effacé définitivement',
            items: _erased,
          ),
          const SizedBox(height: 12),
          _buildBulletCard(
            heading: 'Ce qui est conservé',
            items: const [
              'Vos locations et vos devis, sans votre nom, votre adresse e-mail '
                  'ni votre numéro de téléphone.',
            ],
            note: 'Ces pièces sont exigées par la comptabilité et ne permettent '
                'plus de vous identifier.',
          ),
          const SizedBox(height: 20),
          ProfileTextField(
            label: 'Mot de passe',
            controller: _passwordController,
            obscureText: true,
            helperText: 'Confirmez avec le mot de passe de votre compte.',
            textInputAction: TextInputAction.done,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.error_outline,
                    size: 16,
                    color: ProfileTokens.danger,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _error!,
                    style: ProfileText.footNote
                        .copyWith(color: ProfileTokens.danger, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWarning() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: ProfileTokens.dangerSurface,
        borderRadius: BorderRadius.circular(ProfileTokens.radiusCard),
        border: Border.all(color: ProfileTokens.danger.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: ProfileTokens.danger,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'La suppression est immédiate et définitive. Votre compte ne '
              'pourra pas être restauré.',
              style: ProfileText.rowTitle.copyWith(fontSize: 14, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletCard({
    required String heading,
    required List<String> items,
    String? note,
  }) {
    return ProfileCard(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(heading, style: ProfileText.documentHeading),
              const SizedBox(height: 10),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 9),
                        child: Icon(
                          Icons.circle,
                          size: 4,
                          color: ProfileTokens.muted,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(item, style: ProfileText.documentBody),
                      ),
                    ],
                  ),
                ),
              if (note != null) ...[
                const SizedBox(height: 2),
                Text(note, style: ProfileText.footNote),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer le compte ?'),
        content: const Text(
          'Vos données personnelles seront effacées et vous serez déconnecté. '
          'Vos locations et devis seront conservés sans votre identité.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: ProfileTokens.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.deleteAccount(_passwordController.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Suppression impossible pour le moment. Réessayez plus tard.';
      });
    }
  }
}
