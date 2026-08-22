import 'package:flutter/material.dart';

import '../API/config.dart';
import '../l10n/app_localizations.dart';

/// Bottom nav for the driver app: Home / Shipments / Wallet / Profile — no
/// raised "+" (confirmed with the user: drivers don't create shipments,
/// accepting one already lives inside the Shipments tab). FMS design system
/// unification (2026-08-24): converted from the old dark `AppColors` to
/// `LightColors`, same visual language as AdminBottomNav/CompanyBottomNav
/// now — white background + subtle top border, gray inactive, gold icon +
/// gold label when active.
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
    final t = AppLocalizations.of(context)!;
    return Container(
      height: 64 + bottomInset,
      decoration: const BoxDecoration(
        color: LightColors.surface,
        border: Border(top: BorderSide(color: LightColors.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavIcon(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: t.navHome,
              active: selectedTab == DriverNavTab.home,
              onTap: () => onSelectTab(DriverNavTab.home),
            ),
            _NavIcon(
              icon: Icons.local_shipping_outlined,
              activeIcon: Icons.local_shipping_rounded,
              label: t.navShipments,
              active: selectedTab == DriverNavTab.shipments,
              onTap: () => onSelectTab(DriverNavTab.shipments),
            ),
            _NavIcon(
              icon: Icons.account_balance_wallet_outlined,
              activeIcon: Icons.account_balance_wallet_rounded,
              label: t.navWallet,
              active: selectedTab == DriverNavTab.wallet,
              onTap: () => onSelectTab(DriverNavTab.wallet),
            ),
            _NavIcon(
              icon: Icons.person_outline,
              activeIcon: Icons.person_rounded,
              label: t.navProfile,
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
    final color = active ? LightColors.gold : LightColors.muted;
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
