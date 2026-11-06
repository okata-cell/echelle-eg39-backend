// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'package:flutter/material.dart';

import '../profile_theme.dart';
import '../team.dart';
import 'profile_sheet.dart';

/// Équipe de l’entreprise, lue depuis `team.dart`.
///
/// Les noms et fonctions ne sont jamais recopiés ici : une modification dans
/// `team.dart` suffit à mettre l’écran à jour (après redémarrage complet).
class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileSheetScaffold(
      title: 'Équipe',
      child: ProfileCard(
        children: [
          for (final member in kTeamMembers)
            ProfileSheetRow(
              key: ValueKey('team-member-${member.firstName}'),
              leading: _InitialBadge(initial: member.initial),
              title: member.firstName,
              minHeight: 88,
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(member.role, style: ProfileText.identityStrong),
                  const SizedBox(height: 2),
                  Text(member.specialty, style: ProfileText.listValue),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Pastille d’initiale neutre : l’équipe n’ajoute pas de couleur au système.
class _InitialBadge extends StatelessWidget {
  const _InitialBadge({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ProfileTokens.touchTarget,
      height: ProfileTokens.touchTarget,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: ProfileTokens.initials,
        shape: BoxShape.circle,
      ),
      child: Text(initial, style: ProfileText.rowTitle),
    );
  }
}
