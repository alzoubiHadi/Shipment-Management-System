import 'package:flutter/material.dart';

import '../API/config.dart';
import '../models/Appuser.dart';
import 'AdminFinancePage.dart';
import 'AdminPlatformSettingsPage.dart';
import 'AdminProfileEditRequestsPage.dart';
import 'AdminZonePricingPage.dart';
import 'DeletedDrivers.dart';
import 'Deletedcompanies.dart';
import 'PriceListAdminPage.dart';
import 'SubAdminsPage.dart';

/// Admin settings hub — reached from the account-menu dropdown on any
/// AppBar (tap the avatar). Groups everything that isn't a report:
/// sub-admin account management, financial/pricing tools (moved out of
/// the Reports tab, which now only holds actual reports), the profile
/// edit-request review queue, the recycle bin, and platform settings.
///
/// Admin Phase 5 (2026-08-20) redesign to LightColors.
///
/// 2026-08-27 (security review): this page used to show every tile to
/// every admin type unconditionally — a trainer/technical_check-only
/// sub-admin could see (and tap into) Admin Accounts, Finance, Price List,
/// Zone Pricing, and Platform Settings, none of which they have backend
/// permission for (they'd just get a 403 from the API, but the tile itself
/// shouldn't have been offered). Now takes the logged-in [user] and hides
/// each tile the same way AdminDrawer already gates Reports/Work
/// Destinations: Admin Accounts + Platform Settings + the recycle bin are
/// Super Admin only (Platform Settings per PlatformSettingController::
/// requireSuperAdmin()); Finance/Price List/Zone Pricing need the
/// 'finance' permission; Profile Edit Requests mirrors AdminDrawer's own
/// _canReviewFinanceRequests.
class AdminSettingsPage extends StatelessWidget {
  final AppUser user;
  const AdminSettingsPage({super.key, required this.user});

  bool get _isSuperAdmin => user.role.toLowerCase() == 'super_admin';
  bool get _canFinance => user.hasPermission('finance');

  @override
  Widget build(BuildContext context) {
    final administrationTiles = <Widget>[
      if (_isSuperAdmin)
        _SettingsTile(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Admin Accounts',
          subtitle: 'Create sub-admins, manage permissions, suspend or remove them',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SubAdminsPage()),
          ),
        ),
      if (_canFinance)
        _SettingsTile(
          icon: Icons.fact_check_outlined,
          title: 'Profile Edit Requests',
          subtitle: 'Review driver/company self-service changes before they apply',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminProfileEditRequestsPage()),
          ),
        ),
    ];

    final financeTiles = <Widget>[
      if (_canFinance)
        _SettingsTile(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Finance',
          subtitle: 'Review top-ups, driver payouts, and set company credit limits',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminFinancePage()),
          ),
        ),
      if (_canFinance)
        _SettingsTile(
          icon: Icons.price_change_outlined,
          title: 'Price List',
          subtitle: 'Finance Admin: export/import the central price matrix (UC-33)',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PriceListAdminPage()),
          ),
        ),
      if (_canFinance)
        _SettingsTile(
          icon: Icons.auto_graph_outlined,
          title: 'Zone Pricing',
          subtitle: 'Smart Pricing Engine: review historical lanes, adjust market %',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminZonePricingPage()),
          ),
        ),
      if (_isSuperAdmin)
        _SettingsTile(
          icon: Icons.tune_outlined,
          title: 'Platform Settings',
          subtitle: 'Super Admin only — profit margin, matching weights/timeout, driver-ops defaults',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminPlatformSettingsPage()),
          ),
        ),
    ];

    final recycleBinTiles = <Widget>[
      if (_isSuperAdmin)
        _SettingsTile(
          icon: Icons.people_outline,
          title: 'Deleted Drivers',
          subtitle: 'Restore drivers removed from the system',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const Deleteddrivers()),
          ),
        ),
      if (_isSuperAdmin)
        _SettingsTile(
          icon: Icons.apartment_outlined,
          title: 'Deleted Companies',
          subtitle: 'Restore companies removed from the system',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const Deletedcompanies()),
          ),
        ),
    ];

    final hasAnySettings = administrationTiles.isNotEmpty || financeTiles.isNotEmpty || recycleBinTiles.isNotEmpty;

    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        title: const Text('Settings', style: TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: LightColors.textPrimary),
      ),
      body: !hasAnySettings
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No settings are available for your current permissions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: LightColors.textSecondary),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (administrationTiles.isNotEmpty) ...[
                  const _SettingsSectionTitle('Administration'),
                  const SizedBox(height: 12),
                  for (final tile in administrationTiles) ...[tile, const SizedBox(height: 10)],
                  const SizedBox(height: 18),
                ],
                if (financeTiles.isNotEmpty) ...[
                  const _SettingsSectionTitle('Finance & Payments'),
                  const SizedBox(height: 12),
                  for (final tile in financeTiles) ...[tile, const SizedBox(height: 10)],
                  const SizedBox(height: 18),
                ],
                if (recycleBinTiles.isNotEmpty) ...[
                  const _SettingsSectionTitle('Recycle Bin'),
                  const SizedBox(height: 12),
                  for (final tile in recycleBinTiles) ...[tile, const SizedBox(height: 10)],
                ],
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
        color: LightColors.textSecondary,
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
          color: LightColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: LightColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: LightColors.gold.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: LightColors.goldMuted),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: LightColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: LightColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: LightColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
