import 'package:flutter/material.dart';

import '../API/config.dart';

/// Bottom nav for the company-side redesign (2026-08-17 mockup): Home /
/// Shipments / a raised "+" Create action / Finance / Profile. Mirrors
/// AdminBottomNav's raised-FAB layout for visual consistency between the
/// two redesigned areas of the app.
enum CompanyNavTab { home, shipments, finance, profile }

class CompanyBottomNav extends StatelessWidget {
  final CompanyNavTab selectedTab;
  final ValueChanged<CompanyNavTab> onSelectTab;
  final VoidCallback onCreate;

  const CompanyBottomNav({
    super.key,
    required this.selectedTab,
    required this.onSelectTab,
    required this.onCreate,
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
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home_rounded,
                        label: 'Home',
                        active: selectedTab == CompanyNavTab.home,
                        onTap: () => onSelectTab(CompanyNavTab.home),
                      ),
                      _NavIcon(
                        icon: Icons.local_shipping_outlined,
                        activeIcon: Icons.local_shipping_rounded,
                        label: 'Shipments',
                        active: selectedTab == CompanyNavTab.shipments,
                        onTap: () => onSelectTab(CompanyNavTab.shipments),
                      ),
                      const SizedBox(width: 56), // room for the raised FAB
                      _NavIcon(
                        icon: Icons.account_balance_wallet_outlined,
                        activeIcon: Icons.account_balance_wallet_rounded,
                        label: 'Finance',
                        active: selectedTab == CompanyNavTab.finance,
                        onTap: () => onSelectTab(CompanyNavTab.finance),
                      ),
                      _NavIcon(
                        icon: Icons.person_outline,
                        activeIcon: Icons.person_rounded,
                        label: 'Profile',
                        active: selectedTab == CompanyNavTab.profile,
                        onTap: () => onSelectTab(CompanyNavTab.profile),
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
              onTap: onCreate,
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
