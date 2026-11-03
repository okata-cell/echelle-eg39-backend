import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Jetons visuels de l’écran Profil et de ses feuilles de détail.
///
/// Reprend le langage déjà utilisé par l’écran Location et la fiche agence :
/// fond parchemin, cartes blanches à filet fin, un seul bleu d’action.
class ProfileTokens {
  const ProfileTokens._();

  static const Color canvas = Color(0xFFF5F5F7);
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFF5F7FA);
  static const Color ink = Color(0xFF1D1D1F);
  static const Color muted = Color(0xFF7A7A7A);
  static const Color border = Color(0xFFE6E6E6);
  static const Color divider = Color(0xFFF0F0F0);
  static const Color primary = Color(0xFF0066CC);
  static const Color chevron = Color(0xFFC7C7CC);
  static const Color danger = Color(0xFFB42318);

  /// Pastille neutre des initiales : l’équipe n’ajoute pas de seconde couleur.
  static const Color initials = Color(0xFFEFEFF4);

  static const double radiusCard = 18;
  static const double radiusField = 11;
  static const double pagePadding = 16;
  static const double avatarSize = 64;
  static const double touchTarget = 44;
}

/// Échelle typographique de l’écran Profil (400 / 600 / 700).
class ProfileText {
  const ProfileText._();

  static TextStyle _style(
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

  static TextStyle get pageTitle =>
      _style(28, FontWeight.w700, height: 1.1, letterSpacing: -0.6);

  static TextStyle get name =>
      _style(21, FontWeight.w700, height: 1.15, letterSpacing: -0.4);

  static TextStyle get email =>
      _style(14, FontWeight.w400, color: ProfileTokens.muted);

  static TextStyle get identityStrong => _style(14, FontWeight.w600, height: 1.35);

  static TextStyle get identityMuted =>
      _style(14, FontWeight.w400, color: ProfileTokens.muted, height: 1.35);

  static TextStyle get sectionTitle =>
      _style(17, FontWeight.w700, letterSpacing: -0.2);

  static TextStyle get rowTitle =>
      _style(16, FontWeight.w600, height: 1.2, letterSpacing: -0.2);

  static TextStyle get rowSubtitle =>
      _style(12, FontWeight.w400, color: ProfileTokens.muted, height: 1.3);

  static TextStyle get rowValue =>
      _style(12, FontWeight.w600, height: 1.3, letterSpacing: -0.1);

  static TextStyle get appName => _style(15, FontWeight.w700, letterSpacing: -0.15);

  static TextStyle get appVersion =>
      _style(13, FontWeight.w400, color: ProfileTokens.muted);

  static TextStyle get actionLabel => _style(15, FontWeight.w600);

  /// Titre d’une feuille plein écran, aligné sur le titre de page du Profil.
  static TextStyle get sheetTitle =>
      _style(21, FontWeight.w700, height: 1.15, letterSpacing: -0.4);

  /// Intitulé d’une section de document (histoire, mission, droits…).
  static TextStyle get documentHeading =>
      _style(16, FontWeight.w600, height: 1.25, letterSpacing: -0.2);

  /// Corps de lecture des documents et des réponses de FAQ.
  static TextStyle get documentBody => _style(15, FontWeight.w400, height: 1.55);

  /// Valeur stockée sous un libellé de ligne (numéro, adresse, fonction).
  static TextStyle get listValue =>
      _style(14, FontWeight.w400, color: ProfileTokens.muted, height: 1.35);

  /// Ligne d’action secondaire, sans graisse, pour les listes de canaux.
  static TextStyle get sheetRow => _style(15, FontWeight.w400, height: 1.3);

  /// Texte saisi dans un champ de recherche.
  static TextStyle get fieldText => _style(15, FontWeight.w400, height: 1.3);

  /// Pastille de technologie ou d’état compact.
  static TextStyle get chip => _style(14, FontWeight.w600);

  /// Mention secondaire : plus code, coordonnées, horaires.
  static TextStyle get footNote =>
      _style(12, FontWeight.w400, color: ProfileTokens.muted, height: 1.4);
}
