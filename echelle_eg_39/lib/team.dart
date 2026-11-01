import 'dart:ui' show Color;

/// Membre de l’équipe affiché dans « À propos › Notre équipe ».
///
/// Les noms et fonctions se modifient uniquement ici : l’écran du profil se
/// contente de lire cette liste.
class TeamMember {
  const TeamMember({
    required this.firstName,
    required this.role,
    required this.specialty,
    required this.color,
  });

  final String firstName;
  final String role;
  final String specialty;

  /// Couleur de la pastille d’initiale.
  final Color color;

  String get initial =>
      firstName.isEmpty ? '?' : firstName.substring(0, 1).toUpperCase();

  String get subtitle => '$role\n$specialty';
}

/// Équipe ÉCHELLE EG39.
const List<TeamMember> kTeamMembers = [
  TeamMember(
    firstName: 'Maurice',
    role: 'Directeur Général',
    specialty: 'Expert en topographie',
    color: Color(0xFF2563EB),
  ),
  TeamMember(
    firstName: 'Akossiwa',
    role: 'Responsable Commerciale',
    specialty: 'Spécialiste GPS',
    color: Color(0xFF059669),
  ),
  TeamMember(
    firstName: 'Koffi',
    role: 'Technicien SAV',
    specialty: 'Expert en réparation',
    color: Color(0xFFDC2626),
  ),
  TeamMember(
    firstName: 'Yao',
    role: 'Formateur',
    specialty: 'Expert en théodolites',
    color: Color(0xFF7C3AED),
  ),
  TeamMember(
    firstName: 'Abigail',
    role: 'Responsable Administrative',
    specialty: 'Support client',
    color: Color(0xFFEA580C),
  ),
];
