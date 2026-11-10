// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../quote_request_lock.dart';

/// Remplace le bouton « Demander un devis » quand une demande est déjà ouverte.
///
/// Le blocage est expliqué, daté et mène directement au suivi : le client n'est
/// pas laissé devant un bouton grisé sans raison.
class QuotePendingNotice extends StatelessWidget {
  const QuotePendingNotice({
    super.key,
    required this.demande,
    required this.onSuivre,
  });

  final Map<String, dynamic> demande;
  final VoidCallback onSuivre;

  @override
  Widget build(BuildContext context) {
    final reference = referenceDemande(demande['id']);
    final envoye = dateDemandeLibelle(demande['createdAt']);
    final statut = libelleStatutDemande(demande['statut']);

    final details = [
      if (envoye.isNotEmpty) envoye,
      if (reference.isNotEmpty) reference,
      statut,
    ].join(' · ');

    return Semantics(
      button: true,
      label: 'Demande en attente de réponse. $details. Suivre ma demande.',
      child: Material(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onSuivre,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.hourglass_top,
                  size: 18,
                  color: Color(0xFFB45309),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Demande en attente de réponse',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        details,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFFB45309),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Suivre',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFB45309),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Color(0xFFB45309),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
