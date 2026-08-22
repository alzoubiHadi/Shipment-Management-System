import 'package:flutter/material.dart';
import '../API/ReportService.dart';
import '../API/TruckService.dart';
import '../API/config.dart';
import '../API/error_messages.dart';
import '../l10n/app_localizations.dart';
import '../models/Appuser.dart';
import '../models/Truck.dart';
import '../utils/logout_helper.dart';
import '../widgets/LanguageSwitcherSheet.dart';
import 'AddTruckPage.dart';
import 'CompanyBalancePage.dart';
import 'DriverBalancePage.dart';
import 'DriverBankDetailsPage.dart';
import 'DriverChangePasswordScreen.dart';
import 'DriverComplianceReportsPage.dart';
import 'DriverDestinationsPage.dart';
import 'DriverDocumentsPage.dart';
import 'DriverMyTruckPage.dart';
import 'DriverPersonalInfoPage.dart';
import 'SupportCenterPage.dart';

class Profile extends StatefulWidget {
  final AppUser user;

  const Profile({required this.user, super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final _truckService = TruckService();
  final _reportService = ReportService();
  Future<List<Truck>>? _trucksFuture;
  Future<Map<String, dynamic>>? _reportFuture;

  bool get _isDriver => (widget.user.role ?? '').toLowerCase() == 'driver';

  @override
  void initState() {
    super.initState();
    if (_isDriver) {
      _trucksFuture = _truckService.fetchMyTrucks();
      _reportFuture = _reportService.fetchMyDriverReport();
    }
  }

  void _refreshTrucks() {
    setState(() {
      _trucksFuture = _truckService.fetchMyTrucks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final role = (widget.user.role ?? '').toLowerCase();
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        title: Text(
          t.profileTitle,
          style: const TextStyle(color: LightColors.cream),
        ),
        iconTheme: const IconThemeData(color: LightColors.cream),
        actions: [logoutAction(context, light: true)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfileHeader(user: widget.user, role: role),
            const SizedBox(height: 24),

            _SectionTitle(t.contactInformationTitle),
            const SizedBox(height: 12),
            _InfoTile(
              icon: Icons.email_outlined,
              label: t.emailLabel,
              value: widget.user.email ?? '—',
            ),

            if (_isDriver) ...[
              const SizedBox(height: 24),
              _SectionTitle(t.accountSectionTitle),
              const SizedBox(height: 12),
              _NavTile(
                icon: Icons.person_outline,
                label: t.personalInformationLabel,
                subtitle: t.personalInformationSubtitle,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DriverPersonalInfoPage(user: widget.user)),
                ),
              ),
              const SizedBox(height: 10),
              _NavTile(
                icon: Icons.account_balance_outlined,
                label: t.bankDetailsLabel,
                subtitle: t.bankDetailsSubtitle,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DriverBankDetailsPage()),
                ),
              ),
              const SizedBox(height: 10),
              _NavTile(
                icon: Icons.lock_outline,
                label: t.changePasswordLabel,
                subtitle: t.changePasswordSubtitle,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DriverChangePasswordScreen()),
                ),
              ),
              const SizedBox(height: 10),
              _NavTile(
                icon: Icons.support_agent_outlined,
                label: t.helpSupportLabel,
                subtitle: t.helpSupportSubtitle,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SupportCenterPage()),
                ),
              ),
              const SizedBox(height: 10),
              _NavTile(
                icon: Icons.language_outlined,
                label: t.languageSettingTitle,
                subtitle: t.languageSettingSubtitle,
                onTap: () => showLanguagePicker(context),
              ),
            ],

            if (role == 'driver' || role == 'company') ...[
              const SizedBox(height: 24),
              _SectionTitle(t.financeSectionTitle),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => role == 'driver'
                        ? const DriverBalancePage()
                        : const CompanyBalancePage(),
                  ),
                ),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: LightColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: LightColors.border, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: LightColors.gold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.account_balance_wallet_outlined,
                            color: LightColors.gold, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          t.myBalanceLabel,
                          style: const TextStyle(
                              color: LightColors.cream,
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: LightColors.muted),
                    ],
                  ),
                ),
              ),
            ],

            if (_isDriver) ...[
              const SizedBox(height: 24),
              _SectionTitle(t.myPerformanceTitle),
              const SizedBox(height: 12),
              FutureBuilder<Map<String, dynamic>>(
                future: _reportFuture,
                builder: (context, snapshot) {
                  final completed = snapshot.data?['completed_count'] ?? 0;
                  final cancelled = snapshot.data?['cancelled_count'] ?? 0;

                  return Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: t.statCompletedLabel,
                          value: completed.toString(),
                          color: LightColors.success,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: t.statCancelledLabel,
                          value: cancelled.toString(),
                          color: LightColors.error,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              _SectionTitle(t.ratingComplianceTitle),
              const SizedBox(height: 12),
              FutureBuilder<Map<String, dynamic>>(
                future: _reportFuture,
                builder: (context, snapshot) {
                  final rating =
                      double.tryParse(snapshot.data?['rating']?.toString() ?? '') ?? 4.5;
                  final compliance =
                      snapshot.data?['compliance_status']?.toString() ?? 'active';
                  final complianceColor = compliance == 'active'
                      ? LightColors.success
                      : compliance == 'warning'
                          ? LightColors.gold
                          : LightColors.error;

                  return InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DriverComplianceReportsPage(),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: LightColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: LightColors.border, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: LightColors.gold, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            rating.toStringAsFixed(2),
                            style: const TextStyle(
                                color: LightColors.cream,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: complianceColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              enumStatusLabel(compliance),
                              style: TextStyle(
                                  color: complianceColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right, color: LightColors.muted),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],

            if (_isDriver) ...[
              const SizedBox(height: 24),
              _SectionTitle(t.documentsCoverageTitle),
              const SizedBox(height: 12),
              _NavTile(
                icon: Icons.description_outlined,
                label: t.myDocumentsLabel,
                subtitle: t.myDocumentsSubtitle,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DriverDocumentsPage()),
                ),
              ),
              const SizedBox(height: 10),
              _NavTile(
                icon: Icons.local_shipping_outlined,
                label: t.myTruckLabel,
                subtitle: t.myTruckSubtitle,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DriverMyTruckPage()),
                ),
              ),
              const SizedBox(height: 10),
              _NavTile(
                icon: Icons.map_outlined,
                label: t.myDestinationsLabel,
                subtitle: t.myDestinationsSubtitle,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DriverDestinationsPage()),
                ),
              ),
            ],

            if (_isDriver) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SectionTitle(t.myTrucksTitle),
                  // A driver registers with exactly one truck and can only
                  // ever have one (server now enforces this too) — so this
                  // button only shows up before that one truck exists, not
                  // as a way to keep adding more.
                  FutureBuilder<List<Truck>>(
                    future: _trucksFuture,
                    builder: (context, snapshot) {
                      final hasTruck = (snapshot.data ?? []).isNotEmpty;
                      if (hasTruck) return const SizedBox.shrink();
                      return TextButton.icon(
                        onPressed: () async {
                          final added = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AddTruckPage()),
                          );
                          if (added == true) _refreshTrucks();
                        },
                        icon: const Icon(Icons.add, size: 16, color: LightColors.gold),
                        label: Text(
                          t.addTruckLabel,
                          style: const TextStyle(color: LightColors.gold, fontSize: 13),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              FutureBuilder<List<Truck>>(
                future: _trucksFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: LightColors.gold,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Text(
                      t.couldNotLoadTrucks,
                      style: const TextStyle(
                          color: LightColors.error, fontSize: 13),
                    );
                  }

                  final trucks = snapshot.data ?? [];

                  if (trucks.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 18, horizontal: 14),
                      decoration: BoxDecoration(
                        color: LightColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: LightColors.border, width: 0.5),
                      ),
                      child: Text(
                        t.noTrucksAddedYet,
                        style: const TextStyle(color: LightColors.muted, fontSize: 13),
                      ),
                    );
                  }

                  return Column(
                    children: trucks
                        .map((t) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _InfoTile(
                                icon: t.hasRefrigeration
                                    ? Icons.ac_unit
                                    : Icons.local_shipping_outlined,
                                label: t.truckType,
                                value: t.truckNumber,
                              ),
                            ))
                        .toList(),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final AppUser user;
  final String role;

  const _ProfileHeader({required this.user, required this.role});

  String _roleLabel(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    switch (role) {
      case 'driver':
        return t.roleDriver;
      case 'company':
        return t.roleCompany;
      case 'super_admin':
        return t.roleSuperAdmin;
      case 'sub_admin':
        return t.roleSubAdmin;
      case 'admin':
        return t.roleAdmin;
      default:
        return role.isEmpty ? t.roleUserFallback : role[0].toUpperCase() + role.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: LightColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LightColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: LightColors.bg,
            child: Icon(
              role == 'driver'
                  ? Icons.local_shipping_outlined
                  : role == 'company'
                  ? Icons.apartment_outlined
                  : Icons.person_outline,
              color: LightColors.gold,
              size: 36,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            user.name ?? '—',
            style: const TextStyle(
              color: LightColors.cream,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: LightColors.gold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _roleLabel(context),
              style: const TextStyle(
                color: LightColors.gold,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section title ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: LightColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

// ── Stat card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: LightColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LightColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: LightColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Nav tile ──────────────────────────────────────────────────────────────────

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: LightColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: LightColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: LightColors.gold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: LightColors.gold, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                        color: LightColors.cream, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: LightColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: LightColors.muted),
          ],
        ),
      ),
    );
  }
}

// ── Info tile ─────────────────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: LightColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LightColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: LightColors.gold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: LightColors.gold, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: LightColors.muted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: LightColors.cream,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
