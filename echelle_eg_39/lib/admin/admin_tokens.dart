import 'package:flutter/material.dart';

/// Design tokens scoped to the administrator workspace.
///
/// The client-facing screens keep their existing theme; only the admin command
/// center uses this palette so operational screens stay visually coherent.
abstract final class AdminPalette {
  static const Color canvas = Color(0xFFF8FAFC);
  static const Color deepSlate = Color(0xFF0F172A);
  static const Color blueprintBlue = Color(0xFF0284C7);
  static const Color safetyAmber = Color(0xFFD97706);
  static const Color approvalGreen = Color(0xFF16A34A);
  static const Color destructiveRed = Color(0xFFDC2626);
  static const Color surface = Colors.white;
  static const Color mutedSurface = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color primaryText = Color(0xFF0F172A);
  static const Color secondaryText = Color(0xFF64748B);
  static const Color tertiaryText = Color(0xFF94A3B8);
}

abstract final class AdminSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double section = 32;

  static const EdgeInsets page = EdgeInsets.fromLTRB(lg, md, lg, section);
}

abstract final class AdminRadii {
  static const double field = 10;
  static const double card = 12;
  static const double sheet = 16;
}

abstract final class AdminStroke {
  static const double hairline = 1;
  static const double pendingAccent = 4;
}

abstract final class AdminElevation {
  static const BoxShadow card = BoxShadow(
    color: Color(0x120F172A),
    blurRadius: 12,
    offset: Offset(0, 4),
  );
}

String adminStatusKey(Object? value) {
  final raw = value?.toString().toLowerCase().trim() ?? '';
  switch (raw) {
    case 'en_attente':
    case 'pending':
    case 'nouveau':
      return 'en_attente';
    case 'approuvee':
    case 'approuvé':
    case 'approved':
      return 'approuvee';
    case 'rejetee':
    case 'rejetée':
    case 'rejected':
      return 'rejetee';
    case 'en_cours':
    case 'active':
      return 'en_cours';
    case 'envoye':
    case 'sent':
      return 'envoye';
    case 'livree':
    case 'termine':
    case 'completed':
      return 'termine';
    default:
      return raw;
  }
}

String adminStatusLabel(Object? value) {
  switch (adminStatusKey(value)) {
    case 'en_attente':
      return 'En attente';
    case 'approuvee':
      return 'Approuvée';
    case 'rejetee':
      return 'Rejetée';
    case 'en_cours':
      return 'En cours';
    case 'envoye':
      return 'Envoyé';
    case 'termine':
      return 'Terminé';
    default:
      final raw = value?.toString().trim() ?? '';
      return raw.isEmpty ? 'Inconnu' : raw.replaceAll('_', ' ');
  }
}

Color adminStatusColor(Object? value) {
  switch (adminStatusKey(value)) {
    case 'en_attente':
      return AdminPalette.safetyAmber;
    case 'approuvee':
      return AdminPalette.approvalGreen;
    case 'rejetee':
      return AdminPalette.destructiveRed;
    case 'en_cours':
    case 'envoye':
      return AdminPalette.blueprintBlue;
    case 'termine':
      return AdminPalette.secondaryText;
    default:
      return AdminPalette.secondaryText;
  }
}

bool isAdminPending(Object? value) => adminStatusKey(value) == 'en_attente';

String formatAdminDate(Object? value) {
  final raw = value?.toString();
  if (raw == null || raw.trim().isEmpty) return '';

  try {
    final date = DateTime.parse(raw).toLocal();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  } catch (_) {
    return raw;
  }
}

String formatAdminAmount(Object? value) {
  final amount = num.tryParse(value?.toString() ?? '');
  if (amount == null) return value?.toString() ?? '';

  final digits = amount.round().toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ' ',
  );
  return '$grouped FCFA';
}

TextStyle adminMonoStyle(
  BuildContext context, {
  Color color = AdminPalette.secondaryText,
  double size = 12,
  FontWeight weight = FontWeight.w600,
}) {
  return Theme.of(context).textTheme.labelMedium!.copyWith(
        color: color,
        fontSize: size,
        fontWeight: weight,
        fontFeatures: const [FontFeature.tabularFigures()],
        letterSpacing: 0.2,
      );
}
