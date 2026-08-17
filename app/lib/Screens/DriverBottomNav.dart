import 'package:flutter/material.dart';

import '../API/config.dart';

/// Bottom nav for the driver redesign (2026-08-17 mockup): Home / Shipments
/// / Wallet / Profile — no raised "+" (confirmed with the user: drivers
/// don't create shipments, accepting one already lives inside the
/// Shipments tab). Dark-themed (AppColors) — unlike the admin/company
/// redesigns, the driver mockup itself is dark, and the user asked to
/// improve the existing workflow, not re-theme it.
enum DriverNavTab { home, shipments, wallet, profile }

class DriverBottomNav extends StatelessWidget {
  final DriverNavTab selectedTab;
  final ValueChanged<DriverNavTab> onSelectTab;

  const DriverBottomNav({
    super.key,
    required this.selectedTab,
    required this.onSelectTab,
  });

  @override
  Widget build(BuildContext context) {
    // Same fix as AdminBottomNav/CompanyBottomNav: grow the total height by
    // the device's bottom safe-area inset instead of letting internal
    // padding squeeze the icon row into a fixed box, which left icons
    // under/behind the phone's system nav bar and untappable.
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 64 + bottomInset,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavIcon(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home',
              active: selectedTab == DriverNavTab.home,
              onTap: () => onSelectTab(DriverNavTab.home),
            ),
            _NavIcon(
              icon: Icons.local_shipping_outlined,
              activeIcon: Icons.local_shipping_rounded,
              label: 'Shipments',
              active: selectedTab == DriverNavTab.shipments,
              onTap: () => onSelectTab(DriverNavTab.shipments),
            ),
            _NavIcon(
              icon: Icons.account_balance_wallet_outlined,
              activeIcon: Icons.account_balance_wallet_rounded,
              label: 'Wallet',
              active: selectedTab == DriverNavTab.wallet,
              onTap: () => onSelectTab(DriverNavTab.wallet),
            ),
            _NavIcon(
              icon: Icons.person_outline,
              activeIcon: Icons.person_rounded,
              label: 'Profile',
              active: selectedTab == DriverNavTab.profile,
              onTap: () => onSelectTab(DriverNavTab.profile),
            ),
          ],
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
    final color = active ? AppColors.gold : AppColors.muted;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(active ? activeIcon : icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
