// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'package:flutter/material.dart';

import 'admin_activity_service.dart';
import 'admin_activity_sheet.dart';
import 'admin_tokens.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({
    super.key,
    required this.currentIndex,
    required this.pages,
    required this.onIndexChanged,
    required this.onLogout,
    required this.activity,
  });

  final int currentIndex;
  final List<Widget> pages;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback onLogout;

  /// Journal des demandes clientes : alimente la pastille et la feuille Activité.
  final AdminActivityService activity;

  static const _modules = <_AdminModule>[
    _AdminModule('Clients', Icons.people_alt_outlined),
    _AdminModule('Appareils', Icons.gps_fixed),
    _AdminModule('Locations', Icons.assignment_outlined, 'location'),
    _AdminModule('Ventes', Icons.shopping_cart_outlined, 'vente'),
    _AdminModule('Devis', Icons.request_quote_outlined, 'devis'),
    _AdminModule('Actualités', Icons.newspaper_outlined),
    _AdminModule('Promotions', Icons.campaign_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final safeIndex = currentIndex.clamp(0, _modules.length - 1);
    final module = _modules[safeIndex];

    return AnimatedBuilder(
      animation: activity,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AdminPalette.canvas,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(74),
            child: _AdminTopBar(
              module: module,
              onLogout: onLogout,
              unreadTotal: activity.total,
              fluxEnDirect: activity.fluxEnDirect,
              onOpenActivity: () => showAdminActivitySheet(
                context,
                service: activity,
                onModuleSelected: (kind) {
                  final cible = _modules.indexWhere(
                    (item) => item.kind == kind,
                  );
                  if (cible >= 0) onIndexChanged(cible);
                },
              ),
            ),
          ),
          body: pages[safeIndex],
          bottomNavigationBar: _AdminBottomNavigation(
            currentIndex: safeIndex,
            onChanged: onIndexChanged,
            activity: activity,
          ),
        );
      },
    );
  }
}

class _AdminModule {
  const _AdminModule(this.label, this.icon, [this.kind]);

  final String label;
  final IconData icon;

  /// Rapprochement avec le journal d'activité (`location`, `vente`, `devis`).
  final String? kind;
}

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({
    required this.module,
    required this.onLogout,
    required this.unreadTotal,
    required this.fluxEnDirect,
    required this.onOpenActivity,
  });

  final _AdminModule module;
  final VoidCallback onLogout;
  final int unreadTotal;
  final bool fluxEnDirect;
  final VoidCallback onOpenActivity;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AdminPalette.deepSlate,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AdminSpacing.lg,
            AdminSpacing.sm,
            AdminSpacing.xs,
            AdminSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AdminPalette.blueprintBlue,
                  borderRadius: BorderRadius.circular(AdminRadii.field),
                ),
                child: const Center(
                  child: Text(
                    'EG',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AdminSpacing.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ÉCHELLE EG39  /  ADMIN',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF93C5FD),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(module.icon, color: Colors.white, size: 16),
                        const SizedBox(width: AdminSpacing.sm),
                        Text(
                          module.label,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _ActivityButton(
                total: unreadTotal,
                fluxEnDirect: fluxEnDirect,
                onPressed: onOpenActivity,
              ),
              IconButton(
                onPressed: onLogout,
                tooltip: 'Se déconnecter',
                icon: const Icon(Icons.logout_outlined),
                color: const Color(0xFFCBD5E1),
                splashRadius: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Entrée du registre d'activité : la pastille s'anime quand une demande arrive.
class _ActivityButton extends StatelessWidget {
  const _ActivityButton({
    required this.total,
    required this.fluxEnDirect,
    required this.onPressed,
  });

  final int total;
  final bool fluxEnDirect;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final alerte = total > 0;

    return Semantics(
      button: true,
      label: alerte
          ? 'Activité, $total demandes non consultées'
          : 'Activité, aucune demande en attente',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AdminRadii.field),
        child: SizedBox(
          width: 46,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                alerte ? Icons.notifications_active : Icons.notifications_none,
                color: alerte
                    ? const Color(0xFFFFD38A)
                    : const Color(0xFFCBD5E1),
                size: 22,
              ),
              Positioned(
                top: 4,
                right: 4,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: alerte
                      ? Container(
                          key: ValueKey<int>(total),
                          constraints: const BoxConstraints(minWidth: 18),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AdminPalette.safetyAmber,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AdminPalette.deepSlate,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            total > 9 ? '9+' : '$total',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      : Container(
                          key: const ValueKey<int>(0),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: fluxEnDirect
                                ? AdminPalette.approvalGreen
                                : const Color(0xFF475569),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AdminPalette.deepSlate,
                              width: 1.5,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminBottomNavigation extends StatelessWidget {
  const _AdminBottomNavigation({
    required this.currentIndex,
    required this.onChanged,
    required this.activity,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;
  final AdminActivityService activity;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AdminPalette.deepSlate,
        border: Border(top: BorderSide(color: Color(0x33475569))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: List.generate(AdminShell._modules.length, (index) {
              final module = AdminShell._modules[index];
              final selected = currentIndex == index;
              final nonLus = module.kind == null
                  ? 0
                  : activity.nonLusDe(module.kind!);

              return Expanded(
                child: InkWell(
                  onTap: () => onChanged(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: selected
                              ? AdminPalette.blueprintBlue
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _OngletIcone(
                          icon: module.icon,
                          selectionne: selected,
                          nonLus: nonLus,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          module.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: selected
                                    ? const Color(0xFFBAE6FD)
                                    : const Color(0xFF94A3B8),
                                fontSize: 10,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _AdminBottomNavigationBadge extends StatelessWidget {
  const _AdminBottomNavigationBadge({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: AdminPalette.safetyAmber,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AdminPalette.deepSlate, width: 1.5),
      ),
      child: Text(
        total > 9 ? '9+' : '$total',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Icône d'onglet surmontée du compteur de demandes non consultées.
class _OngletIcone extends StatelessWidget {
  const _OngletIcone({
    required this.icon,
    required this.selectionne,
    required this.nonLus,
  });

  final IconData icon;
  final bool selectionne;
  final int nonLus;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Icon(
          icon,
          size: 21,
          color: selectionne
              ? Colors.white
              : nonLus > 0
              ? const Color(0xFFE2E8F0)
              : const Color(0xFF94A3B8),
        ),
        if (nonLus > 0)
          Positioned(
            top: -8,
            right: -12,
            child: _AdminBottomNavigationBadge(total: nonLus),
          ),
      ],
    );
  }
}
