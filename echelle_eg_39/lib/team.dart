import 'dart:ui' show Color;

/// Membre de l’équipe affiché dans « À propos › Notre équipe ».
///
/// Les noms et fonctions se modifient uniquement ici : l’écran du profil se
/// contente de lire cette liste. Après modification, faire un **hot restart**
/// (R), pas un simple hot reload : ce sont des données chargées au démarrage.
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
    firstName: 'BADJO Gregoire',
    role: 'Directeur Général',
    specialty: 'Expert en topographie, dessinateur et cartographe',
    color: Color(0xFF2563EB),
  ),
  TeamMember(
    firstName: 'Valentin Koko',
    role: 'Technicien Topographie',
    specialty: 'Expert en GPS et stations totales',
    color: Color(0xFF059669),
  ),
  TeamMember(
    firstName: 'Marcel',
    role: 'Technicien et opérateur',
    specialty: 'Expert en GPS e-survey et station totale Leica',
    color: Color(0xFFDC2626),
  ),
  TeamMember(
    firstName: 'Maurice',
    role: 'Technicien et opérateur',
    specialty: 'Expert en GPS e-survey et station totale Leica',
    color: Color(0xFF7C3AED),
  ),
];
