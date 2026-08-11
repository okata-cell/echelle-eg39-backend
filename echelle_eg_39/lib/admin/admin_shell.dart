import 'package:flutter/material.dart';

import 'admin_tokens.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({
    super.key,
    required this.currentIndex,
    required this.pages,
    required this.onIndexChanged,
    required this.onLogout,
  });

  final int currentIndex;
  final List<Widget> pages;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback onLogout;

  static const _modules = <_AdminModule>[
    _AdminModule('Clients', Icons.people_alt_outlined),
    _AdminModule('Appareils', Icons.gps_fixed),
    _AdminModule('Locations', Icons.assignment_outlined),
    _AdminModule('Ventes', Icons.shopping_cart_outlined),
    _AdminModule('Devis', Icons.request_quote_outlined),
    _AdminModule('Promotions', Icons.campaign_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final safeIndex = currentIndex.clamp(0, _modules.length - 1);
    final module = _modules[safeIndex];

    return Scaffold(
      backgroundColor: AdminPalette.canvas,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(74),
        child: _AdminTopBar(module: module, onLogout: onLogout),
      ),
      body: pages[safeIndex],
      bottomNavigationBar: _AdminBottomNavigation(
        currentIndex: safeIndex,
        onChanged: onIndexChanged,
      ),
    );
  }
}

class _AdminModule {
  const _AdminModule(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({required this.module, required this.onLogout});

  final _AdminModule module;
  final VoidCallback onLogout;

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
            AdminSpacing.sm,
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
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
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

class _AdminBottomNavigation extends StatelessWidget {
  const _AdminBottomNavigation({
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

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
            children: List.generate(
              AdminShell._modules.length,
              (index) {
                final module = AdminShell._modules[index];
                final selected = currentIndex == index;
                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: module.label,
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
                            Icon(
                              module.icon,
                              size: 21,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              module.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
