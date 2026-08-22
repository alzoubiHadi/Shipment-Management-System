import 'package:flutter/material.dart';

import '../API/config.dart';
import '../l10n/app_localizations.dart';
import '../models/Appuser.dart';
import '../widgets/LanguageSwitcherSheet.dart';
import 'AdminFinancePage.dart';
import 'AdminPlatformSettingsPage.dart';
import 'AdminZonePricingPage.dart';
import 'ApprovalsPage.dart';
import 'DeletedDrivers.dart';
import 'Deletedcompanies.dart';
import 'HomeScreen.dart';
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
/// each tile the same way AdminDrawer already gates Reports: Admin
/// Accounts + Platform Settings + the recycle bin are Super Admin only
/// (Platform Settings per PlatformSettingController::requireSuperAdmin());
/// Finance/Price List/Zone Pricing/Profile Edit Requests need the
/// 'finance' permission.
///
/// 2026-08-28: the Profile Edit Requests tile now deep-links into
/// Approvals > Work Destinations (via HomeScreen's initialTabIndex/
/// initialApprovalSection) instead of pushing the removed
/// AdminProfileEditRequestsPage — that screen has no back button of its
/// own (it only ever lived inside HomeScreen's IndexedStack), so landing on
/// it means clearing the stack back to a fresh HomeScreen already on that
/// tab/section.
class AdminSettingsPage extends StatelessWidget {
  final AppUser user;
  const AdminSettingsPage({super.key, required this.user});

  // 2026-08-29: see AdminDrawer's matching fix — routed through the
  // centralized AppUser.isSuperAdmin getter so the legacy 'admin' account
  // (which the backend already treats as Super Admin) isn't silently
  // missing Admin Accounts / Platform Settings / the recycle bins.
  bool get _isSuperAdmin => user.isSuperAdmin;
  bool get _canFinance => user.hasPermission('finance');

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    // 2026-08-22: language switcher lives here rather than a dedicated
    // Settings screen — admin has no Profile tab (see AdminDrawer's
    // docblock), so this hub is the natural equivalent of the language
    // tile added to Profile.dart/CompanyProfileScreen.dart for
    // driver/company. Always shown regardless of permissions, unlike every
    // other tile on this page.
    final generalTiles = <Widget>[
      _SettingsTile(
        icon: Icons.language_outlined,
        title: t.languageSettingTitle,
        subtitle: t.languageSettingSubtitle,
        onTap: () => showLanguagePicker(context),
      ),
    ];

    final administrationTiles = <Widget>[
      if (_isSuperAdmin)
        _SettingsTile(
          icon: Icons.admin_panel_settings_outlined,
          title: t.adminAccountsTitle,
          subtitle: t.adminAccountsSubtitle,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SubAdminsPage()),
          ),
        ),
      if (_canFinance)
        _SettingsTile(
          icon: Icons.fact_check_outlined,
          title: t.profileEditRequestsTitle,
          subtitle: t.profileEditRequestsSubtitle,
          onTap: () => Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => HomeScreen(
                user: user,
                initialTabIndex: 1,
                initialApprovalSection: ApprovalSection.destinations,
              ),
            ),
            (route) => false,
          ),
        ),
    ];

    final financeTiles = <Widget>[
      if (_canFinance)
        _SettingsTile(
          icon: Icons.account_balance_wallet_outlined,
          title: t.financeTileTitle,
          subtitle: t.financeTileSubtitle,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminFinancePage()),
          ),
        ),
      if (_canFinance)
        _SettingsTile(
          icon: Icons.price_change_outlined,
          title: t.priceListTitle,
          subtitle: t.priceListSubtitle,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PriceListAdminPage()),
          ),
        ),
      if (_canFinance)
        _SettingsTile(
          icon: Icons.auto_graph_outlined,
          title: t.zonePricingTitle,
          subtitle: t.zonePricingSubtitle,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminZonePricingPage()),
          ),
        ),
      if (_isSuperAdmin)
        _SettingsTile(
          icon: Icons.tune_outlined,
          title: t.platformSettingsTitle,
          subtitle: t.platformSettingsSubtitle,
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
          title: t.deletedDriversTitle,
          subtitle: t.deletedDriversSubtitle,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const Deleteddrivers()),
          ),
        ),
      if (_isSuperAdmin)
        _SettingsTile(
          icon: Icons.apartment_outlined,
          title: t.deletedCompaniesTitle,
          subtitle: t.deletedCompaniesSubtitle,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const Deletedcompanies()),
          ),
        ),
    ];

    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        title: Text(t.settingsTitle, style: const TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: LightColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SettingsSectionTitle(t.settingsSectionGeneral),
          const SizedBox(height: 12),
          for (final tile in generalTiles) ...[tile, const SizedBox(height: 10)],
          const SizedBox(height: 18),
          if (administrationTiles.isNotEmpty) ...[
            _SettingsSectionTitle(t.settingsSectionAdministration),
            const SizedBox(height: 12),
            for (final tile in administrationTiles) ...[tile, const SizedBox(height: 10)],
            const SizedBox(height: 18),
          ],
          if (financeTiles.isNotEmpty) ...[
            _SettingsSectionTitle(t.settingsSectionFinance),
            const SizedBox(height: 12),
            for (final tile in financeTiles) ...[tile, const SizedBox(height: 10)],
            const SizedBox(height: 18),
          ],
          if (recycleBinTiles.isNotEmpty) ...[
            _SettingsSectionTitle(t.settingsSectionRecycleBin),
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
