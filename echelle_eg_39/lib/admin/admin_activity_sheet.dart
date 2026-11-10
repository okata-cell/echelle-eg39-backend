// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'package:flutter/material.dart';

import '../models_admin_activity.dart';
import 'admin_activity_service.dart';
import 'admin_components.dart';
import 'admin_tokens.dart';

/// Ouvre le registre d'activité des demandes clientes.
///
/// `onModuleSelected` reçoit `location`, `vente` ou `devis` : la feuille se
/// referme et l'atelier bascule sur l'onglet correspondant.
Future<void> showAdminActivitySheet(
  BuildContext context, {
  required AdminActivityService service,
  required ValueChanged<String> onModuleSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x660F172A),
    builder: (_) => AdminActivitySheet(
      service: service,
      onModuleSelected: onModuleSelected,
    ),
  );
}

class AdminActivitySheet extends StatefulWidget {
  const AdminActivitySheet({
    super.key,
    required this.service,
    required this.onModuleSelected,
  });

  final AdminActivityService service;
  final ValueChanged<String> onModuleSelected;

  @override
  State<AdminActivitySheet> createState() => _AdminActivitySheetState();
}

class _AdminActivitySheetState extends State<AdminActivitySheet> {
  String? _filtre;

  static const List<String> _modules = <String>['location', 'vente', 'devis'];

  @override
  Widget build(BuildContext context) {
    final hauteur = MediaQuery.sizeOf(context).height * 0.78;

    return SizedBox(
      height: hauteur,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AdminPalette.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AdminRadii.sheet + 2),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x330F172A),
              blurRadius: 24,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: widget.service,
          builder: (context, _) {
            final evenements = _filtre == null
                ? widget.service.evenements
                : widget.service.evenements
                      .where((item) => item.kind == _filtre)
                      .toList(growable: false);

            return Column(
              children: [
                const _Poignee(),
                _EnTete(
                  service: widget.service,
                  filtre: _filtre,
                  onFiltre: (kind) =>
                      setState(() => _filtre = _filtre == kind ? null : kind),
                ),
                const Divider(height: 1, color: AdminPalette.border),
                Expanded(
                  child: evenements.isEmpty
                      ? AdminEmptyState(
                          icon: Icons.check_circle_outline,
                          title: _filtre == null
                              ? 'Aucune demande en attente'
                              : 'Rien dans ce module',
                          message: _filtre == null
                              ? 'Les nouvelles demandes de location, d’achat et '
                                    'de devis apparaîtront ici dès leur envoi.'
                              : 'Aucune demande non consultée pour ce module.',
                        )
                      : _Registre(
                          sections: grouperParJour(evenements),
                          onOuvrir: _ouvrir,
                        ),
                ),
                const Divider(height: 1, color: AdminPalette.border),
                _Pied(
                  service: widget.service,
                  onToutLire: widget.service.toutMarquerLu,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _ouvrir(AdminActivityEvent evenement) async {
    final navigateur = Navigator.of(context);
    await widget.service.marquerLu(evenement);
    if (!mounted) return;

    navigateur.pop();
    widget.onModuleSelected(evenement.kind);
  }
}

class _Poignee extends StatelessWidget {
  const _Poignee();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AdminSpacing.md,
        bottom: AdminSpacing.sm,
      ),
      child: Container(
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: AdminPalette.border,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _EnTete extends StatelessWidget {
  const _EnTete({
    required this.service,
    required this.filtre,
    required this.onFiltre,
  });

  final AdminActivityService service;
  final String? filtre;
  final ValueChanged<String?> onFiltre;

  @override
  Widget build(BuildContext context) {
    final total = service.total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AdminSpacing.lg,
        AdminSpacing.xs,
        AdminSpacing.lg,
        AdminSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activité',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AdminPalette.primaryText,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      total == 0
                          ? 'Journal à jour'
                          : 'Demandes clientes à ouvrir',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AdminPalette.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$total',
                style: adminMonoStyle(
                  context,
                  color: total == 0
                      ? AdminPalette.tertiaryText
                      : AdminPalette.primaryText,
                  size: 30,
                  weight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: AdminSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'à traiter',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AdminPalette.secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Filtre(
                  label: 'Tous',
                  icone: Icons.inbox_outlined,
                  nombre: service.evenements.length,
                  teinte: AdminPalette.deepSlate,
                  selectionne: filtre == null,
                  onTap: () => onFiltre(null),
                ),
                for (final kind in _AdminActivitySheetState._modules) ...[
                  const SizedBox(width: AdminSpacing.sm),
                  _Filtre(
                    label: _moduleLabel(kind),
                    icone: _icone(kind),
                    nombre: service.nonLusDe(kind),
                    teinte: _teinte(kind),
                    selectionne: filtre == kind,
                    onTap: () => onFiltre(kind),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Filtre extends StatelessWidget {
  const _Filtre({
    required this.label,
    required this.icone,
    required this.nombre,
    required this.teinte,
    required this.selectionne,
    required this.onTap,
  });

  final String label;
  final IconData icone;
  final int nombre;
  final Color teinte;
  final bool selectionne;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selectionne
          ? teinte.withValues(alpha: 0.08)
          : AdminPalette.surface,
      borderRadius: BorderRadius.circular(AdminRadii.field),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AdminRadii.field),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AdminRadii.field),
            border: Border.all(
              color: selectionne ? teinte : AdminPalette.border,
              width: selectionne ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, size: 15, color: teinte),
              const SizedBox(width: 6),
              Text(
                '$nombre',
                style: adminMonoStyle(
                  context,
                  color: selectionne ? teinte : AdminPalette.primaryText,
                  size: 12,
                  weight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selectionne
                      ? AdminPalette.primaryText
                      : AdminPalette.secondaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Registre extends StatelessWidget {
  const _Registre({required this.sections, required this.onOuvrir});

  final List<AdminActivityJour> sections;
  final ValueChanged<AdminActivityEvent> onOuvrir;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AdminSpacing.lg,
        AdminSpacing.sm,
        AdminSpacing.lg,
        AdminSpacing.lg,
      ),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AdminSpacing.md, bottom: 2),
              child: Row(
                children: [
                  Text(
                    section.entete.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AdminPalette.tertiaryText,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(width: AdminSpacing.sm),
                  const Expanded(
                    child: Divider(height: 1, color: AdminPalette.border),
                  ),
                ],
              ),
            ),
            for (final evenement in section.evenements)
              _Ligne(evenement: evenement, onTap: () => onOuvrir(evenement)),
          ],
        );
      },
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.evenement, required this.onTap});

  final AdminActivityEvent evenement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final teinte = _teinte(evenement.kind);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 42,
              child: Text(
                heureActivite(evenement.createdAt),
                style: adminMonoStyle(
                  context,
                  color: evenement.nonLu
                      ? AdminPalette.secondaryText
                      : AdminPalette.tertiaryText,
                  size: 11,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Column(
                children: [
                  Container(
                    width: evenement.nonLu ? 7 : 5,
                    height: evenement.nonLu ? 7 : 5,
                    decoration: BoxDecoration(
                      color: evenement.nonLu ? teinte : AdminPalette.border,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (evenement.nonLu)
                    Container(
                      width: 1,
                      height: 26,
                      margin: const EdgeInsets.only(top: 3),
                      color: teinte.withValues(alpha: 0.28),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    evenement.reference.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: adminMonoStyle(
                      context,
                      color: evenement.nonLu
                          ? teinte
                          : AdminPalette.tertiaryText,
                      size: 10.5,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    evenement.titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AdminPalette.primaryText,
                      fontWeight: evenement.nonLu
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      evenement.demandeur ?? 'Client non identifié',
                      if (evenement.description != null) evenement.description!,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AdminPalette.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            if (evenement.montant != null) ...[
              const SizedBox(width: AdminSpacing.sm),
              Text(
                formatAdminAmount(evenement.montant),
                style: adminMonoStyle(
                  context,
                  color: AdminPalette.primaryText,
                  size: 11.5,
                  weight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(width: 2),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AdminPalette.tertiaryText,
            ),
          ],
        ),
      ),
    );
  }
}

class _Pied extends StatelessWidget {
  const _Pied({required this.service, required this.onToutLire});

  final AdminActivityService service;
  final Future<void> Function() onToutLire;

  @override
  Widget build(BuildContext context) {
    final enDirect = service.fluxEnDirect;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AdminSpacing.lg,
          AdminSpacing.xs,
          AdminSpacing.sm,
          AdminSpacing.xs,
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: enDirect
                    ? AdminPalette.approvalGreen
                    : AdminPalette.tertiaryText,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                enDirect
                    ? 'En direct'
                    : service.horsLigne
                    ? 'Serveur injoignable'
                    : 'Reprise toutes les 20 s',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AdminPalette.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: service.total == 0
                  ? null
                  : () {
                      onToutLire();
                    },
              child: const Text('Tout marquer comme lu'),
            ),
          ],
        ),
      ),
    );
  }
}

String _moduleLabel(String kind) => switch (kind) {
  'location' => 'Locations',
  'vente' => 'Ventes',
  'devis' => 'Devis',
  _ => 'Activité',
};

IconData _icone(String kind) => switch (kind) {
  'location' => Icons.assignment_outlined,
  'vente' => Icons.shopping_cart_outlined,
  'devis' => Icons.request_quote_outlined,
  _ => Icons.notifications_none,
};

Color _teinte(String kind) => switch (kind) {
  'location' => AdminPalette.safetyAmber,
  'vente' => AdminPalette.blueprintBlue,
  'devis' => AdminPalette.approvalGreen,
  _ => AdminPalette.secondaryText,
};
