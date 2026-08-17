import 'package:flutter/material.dart';

import '../API/config.dart';
import '../models/Appuser.dart';
import '../utils/logout_helper.dart';
import 'ActivityLogPage.dart';
import 'AdminProfileEditRequestsPage.dart';
import 'AdminSettingsPage.dart';
import 'Companiespage.dart';
import 'Driverspage.dart';
import 'NotificationsPage.dart';
import 'ReportsHomePage.dart';
import 'ShipmentOffersAdminPage.dart';

/// Left sidebar navigation from the 2026-08-21 admin dashboard mockup,
/// adapted to mobile as a slide-out Drawer (2026-08-17: paired with a
/// bottom nav per the "Registration Requests" mobile mockup — Dashboard/
/// Requests/+/Shipments/Menu, where Menu opens this Drawer for everything
/// else, rather than the Drawer being the only nav).
///
/// Only Home/Registration Requests/Shipments live in HomeScreen's
/// IndexedStack (go through [onSelectTab]); Drivers/Companies/Offers/
/// Documents & Permissions/Reports/Notifications/Activity Log/Settings are
/// full standalone pages reached via a normal push.
class AdminDrawer extends StatelessWidget {
  final AppUser user;
  final int currentTabIndex; // 0=Home,1=Registration Requests,2=Shipments
  final void Function(int index) onSelectTab;
  final int pendingRegistrations;
  final int unreadNotifications;

  const AdminDrawer({
    super.key,
    required this.user,
    required this.currentTabIndex,
    required this.onSelectTab,
    this.pendingRegistrations = 0,
    this.unreadNotifications = 0,
  });

  bool get _isSuperAdmin => user.role.toLowerCase() == 'super_admin';

  String get _roleLabel {
    switch (user.role.toLowerCase()) {
      case 'super_admin':
        return 'Super Admin';
      case 'sub_admin':
        return 'Sub Admin';
      default:
        return 'Admin';
    }
  }

  String get _initials {
    if (user.avatarInitials?.isNotEmpty == true) return user.avatarInitials!;
    if (user.name.isNotEmpty) return user.name[0].toUpperCase();
    return '?';
  }

  void _selectTab(BuildContext context, int index) {
    Navigator.pop(context);
    onSelectTab(index);
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: LightColors.bg,
      width: 280,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: LightColors.gold.withOpacity(0.12),
                      border: Border.all(color: LightColors.gold.withOpacity(0.4)),
                    ),
                    child: Center(
                      child: Text(_initials,
                          style: const TextStyle(color: LightColors.goldMuted, fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: LightColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                        Text(_roleLabel, style: const TextStyle(color: LightColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: LightColors.border, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _DrawerTile(
                    icon: Icons.dashboard_outlined,
                    label: 'Home',
                    selected: currentTabIndex == 0,
                    onTap: () => _selectTab(context, 0),
                  ),
                  _DrawerTile(
                    icon: Icons.assignment_outlined,
                    label: 'Registration Requests',
                    selected: currentTabIndex == 1,
                    badge: pendingRegistrations,
                    onTap: () => _selectTab(context, 1),
                  ),
                  _DrawerTile(
                    icon: Icons.people_outline,
                    label: 'Drivers',
                    onTap: () => _push(context, Driverspage(user: user)),
                  ),
                  _DrawerTile(
                    icon: Icons.apartment_outlined,
                    label: 'Companies',
                    onTap: () => _push(context, Companiespage(user: user)),
                  ),
                  _DrawerTile(
                    icon: Icons.local_shipping_outlined,
                    label: 'Shipments',
                    selected: currentTabIndex == 2,
                    onTap: () => _selectTab(context, 2),
                  ),
                  _DrawerTile(
                    icon: Icons.handshake_outlined,
                    label: 'Offers',
                    onTap: () => _push(context, const ShipmentOffersAdminPage()),
                  ),
                  _DrawerTile(
                    icon: Icons.folder_shared_outlined,
                    label: 'Documents & Permissions',
                    onTap: () => _push(context, const AdminProfileEditRequestsPage()),
                  ),
                  _DrawerTile(
                    icon: Icons.bar_chart_outlined,
                    label: 'Reports',
                    onTap: () => _push(context, ReportsHomePage(user: user)),
                  ),
                  _DrawerTile(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    badge: unreadNotifications,
                    onTap: () => _push(context, NotificationsPage(user: user)),
                  ),
                  if (_isSuperAdmin)
                    _DrawerTile(
                      icon: Icons.history_rounded,
                      label: 'Activity Log',
                      onTap: () => _push(context, const ActivityLogPage()),
                    ),
                  _DrawerTile(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () => _push(context, const AdminSettingsPage()),
                  ),
                ],
              ),
            ),
            const Divider(color: LightColors.border, height: 1),
            _DrawerTile(
              icon: Icons.logout_rounded,
              label: 'Log Out',
              iconColor: LightColors.error,
              textColor: LightColors.error,
              onTap: () {
                Navigator.pop(context);
                confirmAndLogout(context, light: true);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final int? badge;
  final Color? iconColor;
  final Color? textColor;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.badge,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? LightColors.gold.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: iconColor ?? (selected ? LightColors.goldMuted : LightColors.textSecondary)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor ?? (selected ? LightColors.textPrimary : LightColors.textSecondary),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (badge != null && badge! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: LightColors.gold, borderRadius: BorderRadius.circular(10)),
                    child: Text('$badge',
                        style: const TextStyle(color: LightColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
