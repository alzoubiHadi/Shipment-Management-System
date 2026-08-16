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

/// Left sidebar navigation from the 2026-08-21 admin dashboard mockup,
/// adapted to mobile as a slide-out Drawer instead of a permanently
/// pinned desktop sidebar (agreed 2026-08-21 — a fixed sidebar would eat
/// too much of a phone screen).
///
/// Tabs that already live in HomeScreen's IndexedStack (Home/Drivers/
/// Companies/Shipments/Offers/Reports) go through [onSelectTab] so the
/// existing tab-preservation behavior keeps working; everything else
/// (Registration Requests, Documents & Permissions, Notifications,
/// Activity Log, Settings) is a normal push since those aren't tabs.
///
/// "Registration Requests" doesn't have its own unified screen yet (that's
/// a follow-up pass) — for now it opens a quick chooser between the
/// existing Drivers/Companies lists, pre-filtered to 'pending'.
class AdminDrawer extends StatelessWidget {
  final AppUser user;
  final int currentTabIndex; // 0=Home,1=Drivers,2=Companies,3=Shipments,4=Offers,5=Reports
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

  void _openRegistrationRequests(BuildContext context) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: LightColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Registration Requests',
                      style: TextStyle(color: LightColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.local_shipping_outlined, color: LightColors.goldMuted),
                title: const Text('Pending Drivers', style: TextStyle(color: LightColors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => Driverspage(user: user, initialFilter: 'pending')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.apartment_outlined, color: LightColors.goldMuted),
                title: const Text('Pending Companies', style: TextStyle(color: LightColors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => Companiespage(user: user, initialApprovalFilter: 'pending')),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
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
                    badge: pendingRegistrations,
                    onTap: () => _openRegistrationRequests(context),
                  ),
                  _DrawerTile(
                    icon: Icons.people_outline,
                    label: 'Drivers',
                    selected: currentTabIndex == 1,
                    onTap: () => _selectTab(context, 1),
                  ),
                  _DrawerTile(
                    icon: Icons.apartment_outlined,
                    label: 'Companies',
                    selected: currentTabIndex == 2,
                    onTap: () => _selectTab(context, 2),
                  ),
                  _DrawerTile(
                    icon: Icons.local_shipping_outlined,
                    label: 'Shipments',
                    selected: currentTabIndex == 3,
                    onTap: () => _selectTab(context, 3),
                  ),
                  _DrawerTile(
                    icon: Icons.handshake_outlined,
                    label: 'Offers',
                    selected: currentTabIndex == 4,
                    onTap: () => _selectTab(context, 4),
                  ),
                  _DrawerTile(
                    icon: Icons.folder_shared_outlined,
                    label: 'Documents & Permissions',
                    onTap: () => _push(context, const AdminProfileEditRequestsPage()),
                  ),
                  _DrawerTile(
                    icon: Icons.bar_chart_outlined,
                    label: 'Reports',
                    selected: currentTabIndex == 5,
                    onTap: () => _selectTab(context, 5),
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
                confirmAndLogout(context);
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
