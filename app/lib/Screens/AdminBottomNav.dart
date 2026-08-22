import 'package:flutter/material.dart';

import '../API/config.dart';
import '../l10n/app_localizations.dart';

/// Bottom nav for admin: Dashboard / Requests / Shipments / Finance / Menu
/// (opens the AdminDrawer). Originally had a raised gold "+" FAB in the
/// center (quick-action shortcut into SelectRequestTypeScreen) — removed
/// 2026-08-20 on request, since it only ever duplicated filtering that's
/// already available directly inside the Requests tab itself (type/status
/// chips), and a plain 5-icon row reads clearer than a FAB that didn't
/// actually add anything. Finance (top-ups/payouts/credit limits/
/// adjustments — AdminFinancePage) was promoted from the drawer to fill
/// the freed slot, since managing incoming/outgoing payments is a primary
/// daily admin task, same tier as Requests/Shipments.
///
/// `selectedTab` is one of [AdminNavTab] — "Menu" is a momentary action,
/// not persisted selection state.
enum AdminNavTab { dashboard, requests, shipments, finance }

class AdminBottomNav extends StatelessWidget {
  final AdminNavTab selectedTab;
  final ValueChanged<AdminNavTab> onSelectTab;
  final VoidCallback onMenu;

  const AdminBottomNav({
    super.key,
    required this.selectedTab,
    required this.onSelectTab,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    // Same fix as CompanyBottomNav: grow the total height by the device's
    // bottom safe-area inset instead of letting the internal SafeArea
    // padding squeeze the icon row into a fixed 74px box — otherwise the
    // icons end up under/behind the phone's system nav bar and can't be
    // tapped.
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final t = AppLocalizations.of(context)!;
    return Container(
      height: 64 + bottomInset,
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
                label: t.navDashboard,
                active: selectedTab == AdminNavTab.dashboard,
                onTap: () => onSelectTab(AdminNavTab.dashboard),
              ),
              _NavIcon(
                icon: Icons.assignment_outlined,
                activeIcon: Icons.assignment_rounded,
                label: t.navApprovals,
                active: selectedTab == AdminNavTab.requests,
                onTap: () => onSelectTab(AdminNavTab.requests),
              ),
              _NavIcon(
                icon: Icons.local_shipping_outlined,
                activeIcon: Icons.local_shipping_rounded,
                label: t.navShipments,
                active: selectedTab == AdminNavTab.shipments,
                onTap: () => onSelectTab(AdminNavTab.shipments),
              ),
              _NavIcon(
                icon: Icons.account_balance_wallet_outlined,
                activeIcon: Icons.account_balance_wallet_rounded,
                label: t.navFinance,
                active: selectedTab == AdminNavTab.finance,
                onTap: () => onSelectTab(AdminNavTab.finance),
              ),
              _NavIcon(
                icon: Icons.menu_rounded,
                activeIcon: Icons.menu_rounded,
                label: t.navMenu,
                active: false,
                onTap: onMenu,
              ),
            ],
          ),
        ),
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
