import 'package:flutter/material.dart';

import '../API/config.dart';

/// Bottom nav for the admin dashboard redesign (2026-08-21 "Registration
/// Requests" mockup): Dashboard / Requests / a raised "+" quick-action /
/// Shipments / Menu (opens the AdminDrawer). Chosen over a Drawer-only nav
/// per the user's explicit follow-up decision (2026-08-17) after seeing the
/// mobile mockups actually show this bottom bar, not just a sidebar.
///
/// `selectedTab` is one of [AdminNavTab] and only reflects Dashboard/
/// Requests/Shipments — the "+" and "Menu" slots are momentary actions, not
/// persisted selection state.
enum AdminNavTab { dashboard, requests, shipments }

class AdminBottomNav extends StatelessWidget {
  final AdminNavTab selectedTab;
  final ValueChanged<AdminNavTab> onSelectTab;
  final VoidCallback onAdd;
  final VoidCallback onMenu;

  const AdminBottomNav({
    super.key,
    required this.selectedTab,
    required this.onSelectTab,
    required this.onAdd,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 74,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned.fill(
            top: 12,
            child: Container(
              decoration: const BoxDecoration(
                color: LightColors.surface,
                border: Border(top: BorderSide(color: LightColors.border, width: 1)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _NavIcon(
                        icon: Icons.dashboard_outlined,
                        activeIcon: Icons.dashboard_rounded,
                        label: 'Dashboard',
                        active: selectedTab == AdminNavTab.dashboard,
                        onTap: () => onSelectTab(AdminNavTab.dashboard),
                      ),
                      _NavIcon(
                        icon: Icons.assignment_outlined,
                        activeIcon: Icons.assignment_rounded,
                        label: 'Requests',
                        active: selectedTab == AdminNavTab.requests,
                        onTap: () => onSelectTab(AdminNavTab.requests),
                      ),
                      const SizedBox(width: 56), // room for the raised FAB
                      _NavIcon(
                        icon: Icons.local_shipping_outlined,
                        activeIcon: Icons.local_shipping_rounded,
                        label: 'Shipments',
                        active: selectedTab == AdminNavTab.shipments,
                        onTap: () => onSelectTab(AdminNavTab.shipments),
                      ),
                      _NavIcon(
                        icon: Icons.menu_rounded,
                        activeIcon: Icons.menu_rounded,
                        label: 'Menu',
                        active: false,
                        onTap: onMenu,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LightColors.gold,
                  boxShadow: [
                    BoxShadow(color: LightColors.gold.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: const Icon(Icons.add_rounded, color: LightColors.textPrimary, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavIcon({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? LightColors.goldMuted : LightColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(active ? activeIcon : icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 10, color: color, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
