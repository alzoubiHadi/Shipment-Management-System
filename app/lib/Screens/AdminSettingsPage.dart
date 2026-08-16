import 'package:flutter/material.dart';

import '../API/config.dart';
import 'DeletedDrivers.dart';
import 'Deletedcompanies.dart';
import 'SubAdminsPage.dart';

/// Super Admin settings hub. Reached from a gear icon on the admin's
/// Reports tab. Groups two things that used to be scattered: the recycle
/// bin (previously a top-bar icon on the Drivers/Companies list pages) and
/// sub-admin account management (create/permissions/suspend).
class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text('Settings', style: TextStyle(color: AppColors.cream)),
        iconTheme: const IconThemeData(color: AppColors.cream),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _SettingsSectionTitle('Administration'),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.admin_panel_settings_outlined,
            title: 'Admin Accounts',
            subtitle: 'Create sub-admins, manage permissions, suspend or remove them',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubAdminsPage()),
            ),
          ),
          const SizedBox(height: 28),
          const _SettingsSectionTitle('Recycle Bin'),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.people_outline,
            title: 'Deleted Drivers',
            subtitle: 'Restore drivers removed from the system',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => Deleteddrivers()),
            ),
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.apartment_outlined,
            title: 'Deleted Companies',
            subtitle: 'Restore companies removed from the system',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => Deletedcompanies()),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  final String text;
  const _SettingsSectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.gold),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: AppColors.cream, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
