import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../API/ProfileService.dart';
import '../API/config.dart';
import '../l10n/app_localizations.dart';
import '../models/Appuser.dart';
import '../utils/logout_helper.dart';
import '../widgets/LanguageSwitcherSheet.dart';
import 'CompanyBalancePage.dart';
import 'CompanyChangePasswordScreen.dart';
import 'NotificationsPage.dart';
import 'register_shared.dart';

/// Company redesign Phase 5 (2026-08-17 mockup): light-themed "Company
/// Profile" — replaces the shared Profile.dart hub for the company role
/// specifically (Profile.dart stays as-is, still used by drivers, out of
/// scope for this pass).
///
/// Scope note: the mockup's separate "Documents" screen shows Trade
/// License/Memorandum/Certificate of Incorporation/VAT Certificate —
/// this data model only has one company license file
/// (Company.licenseFilePath), so that's folded into a single Trade
/// License card here rather than a whole extra screen for one field, same
/// reduced-scope call already made for company registration.
class CompanyProfileScreen extends StatefulWidget {
  final AppUser user;
  const CompanyProfileScreen({super.key, required this.user});

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  final _service = ProfileService();
  late Future<Map<String, dynamic>> _profileFuture;
  bool _uploadingLicense = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() => _profileFuture = _service.fetchMyProfile());
  }

  Future<void> _editProfile(Map<String, dynamic> current) async {
    final t = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(text: current['name']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: current['phone']?.toString() ?? '');

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LightColors.surface,
        title: Text(t.editCompanyInfoTitle, style: const TextStyle(color: LightColors.textPrimary, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildLightTextField(controller: nameCtrl, label: t.companyNameLabel),
            const SizedBox(height: 12),
            buildLightTextField(controller: phoneCtrl, label: t.phoneLabel, keyboardType: TextInputType.phone),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.commonCancel, style: const TextStyle(color: LightColors.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.commonSave, style: const TextStyle(color: LightColors.goldMuted, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (save != true) return;

    final result = await _service.updateBasic(name: nameCtrl.text.trim(), phone: phoneCtrl.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']?.toString() ?? ''), backgroundColor: result['success'] == true ? LightColors.success : LightColors.error),
    );
    if (result['success'] == true) _refresh();
  }

  Future<void> _renewLicense() async {
    final now = DateTime.now();
    final expiry = await showDatePicker(
      context: context,
      helpText: AppLocalizations.of(context)!.newTradeLicenseExpiryDate,
      initialDate: now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 10)),
    );
    if (expiry == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    setState(() => _uploadingLicense = true);
    final response = await _service.submitCompanyLicense(
      fileBytes: result.files.single.bytes!,
      fileName: result.files.single.name,
      expiryDate: '${expiry.year}-${expiry.month.toString().padLeft(2, '0')}-${expiry.day.toString().padLeft(2, '0')}',
    );
    if (!mounted) return;
    setState(() => _uploadingLicense = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(response['message']?.toString() ?? ''), backgroundColor: response['success'] == true ? LightColors.success : LightColors.error),
    );
    if (response['success'] == true) _refresh();
  }

  /// 2026-08-27 (security review, item 7): the license file moved to the
  /// private disk — fetched through the authenticated
  /// /companies/{id}/license/file endpoint instead of a plain storage URL.
  /// `show()` on the backend now returns the company's own id for exactly
  /// this purpose.
  Future<void> _viewLicense(String? path, dynamic companyId) async {
    if (path == null || path.isEmpty || companyId == null) return;
    await viewSecureFile(context, '$baseUrl/companies/$companyId/license/file');
  }

  /// Compliance/Approval separation feature (2026-08-23): (label, color)
  /// for the Trade License status chip — mirrors the driver My Documents
  /// screen's status display, driven by Company.compliance_status.
  (String, Color) _licenseStatusDisplay(String complianceStatus) {
    final t = AppLocalizations.of(context)!;
    return switch (complianceStatus) {
      'action_required' => (t.licenseStatusExpired, LightColors.error),
      'expiring_soon' => (t.licenseStatusExpiringSoon, LightColors.gold),
      'pending_review' => (t.licenseStatusPendingReview, LightColors.navy),
      _ => (t.licenseStatusValid, LightColors.success),
    };
  }

  /// "12d left" / "Expires today" / "3d overdue" — null with no expiry date.
  String? _daysRemainingLabel(DateTime? expiry) {
    if (expiry == null) return null;
    final t = AppLocalizations.of(context)!;
    final today = DateTime.now();
    final d0 = DateTime(today.year, today.month, today.day);
    final e = DateTime(expiry.year, expiry.month, expiry.day);
    final days = e.difference(d0).inDays;
    if (days < 0) return t.daysOverdue(-days);
    if (days == 0) return t.expiresToday;
    return t.daysLeft(days);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Container(
      color: LightColors.bg,
      child: SafeArea(
        child: RefreshIndicator(
          color: LightColors.gold,
          onRefresh: () async {
            _refresh();
            await _profileFuture;
          },
          child: FutureBuilder<Map<String, dynamic>>(
            future: _profileFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: LightColors.gold));
              }
              final data = snapshot.data ?? {};
              final name = data['name']?.toString() ?? widget.user.name;
              final email = data['email']?.toString() ?? widget.user.email;
              final phone = data['phone']?.toString() ?? '';
              final licensePath = data['license_file_path']?.toString();
              final accountStatus = data['account_status']?.toString() ?? 'active';
              final licenseExpiry = data['license_expiry'] != null ? DateTime.tryParse(data['license_expiry'].toString()) : null;
              final complianceStatus = data['compliance_status']?.toString() ?? 'active';
              final (licenseStatusLabel, licenseStatusColor) = _licenseStatusDisplay(complianceStatus);
              final daysLabel = _daysRemainingLabel(licenseExpiry);

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(color: LightColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LightColors.border)),
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: LightColors.gold.withOpacity(0.12)),
                          child: const Icon(Icons.apartment_outlined, color: LightColors.goldMuted, size: 34),
                        ),
                        const SizedBox(height: 12),
                        Text(name, style: const TextStyle(color: LightColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: accountStatus == 'suspended' ? LightColors.errorBg : LightColors.successBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(accountStatus == 'suspended' ? t.accountStatusSuspended : t.accountStatusActive,
                              style: TextStyle(color: accountStatus == 'suspended' ? LightColors.error : LightColors.success, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SectionLabel(t.companyInformationTitle),
                  const SizedBox(height: 10),
                  _InfoRow(icon: Icons.email_outlined, label: t.emailLabel, value: email),
                  const SizedBox(height: 8),
                  _InfoRow(icon: Icons.phone_outlined, label: t.phoneLabelShort, value: phone.isEmpty ? '—' : phone),
                  const SizedBox(height: 10),
                  LightOutlineButton(label: t.editCompanyInfoTitle, onPressed: () => _editProfile(data)),
                  const SizedBox(height: 20),
                  _SectionLabel(t.tradeLicenseLabel),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: LightColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: LightColors.border)),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: licenseStatusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.description_outlined, color: licenseStatusColor, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (licensePath ?? '').isEmpty ? t.notUploadedYet : t.tradeLicenseOnFile,
                                style: const TextStyle(color: LightColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600),
                              ),
                              if ((licensePath ?? '').isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(color: licenseStatusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                                      child: Text(licenseStatusLabel,
                                          style: TextStyle(color: licenseStatusColor, fontSize: 10, fontWeight: FontWeight.w600)),
                                    ),
                                    if (licenseExpiry != null)
                                      Text('exp. ${licenseExpiry.year}-${licenseExpiry.month.toString().padLeft(2, '0')}-${licenseExpiry.day.toString().padLeft(2, '0')}',
                                          style: const TextStyle(color: LightColors.textSecondary, fontSize: 11)),
                                    if (daysLabel != null)
                                      Text(daysLabel,
                                          style: TextStyle(
                                            color: licenseExpiry != null && licenseExpiry.isBefore(DateTime.now()) ? LightColors.error : LightColors.textSecondary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          )),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        if ((licensePath ?? '').isNotEmpty)
                          TextButton(onPressed: () => _viewLicense(licensePath, data['id']), child: Text(t.commonView, style: const TextStyle(color: LightColors.goldMuted, fontWeight: FontWeight.w700))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  LightOutlineButton(
                    label: _uploadingLicense ? t.uploadingEllipsis : ((licensePath ?? '').isEmpty ? t.uploadTradeLicense : t.renewTradeLicense),
                    onPressed: _uploadingLicense ? null : _renewLicense,
                  ),
                  const SizedBox(height: 20),
                  _SectionLabel(t.accountSectionTitle),
                  const SizedBox(height: 10),
                  _LinkTile(
                    icon: Icons.account_balance_wallet_outlined,
                    label: t.financeSectionTitle,
                    subtitle: t.financeLinkSubtitle,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanyBalancePage())),
                  ),
                  const SizedBox(height: 8),
                  _LinkTile(
                    icon: Icons.notifications_outlined,
                    label: t.drawerNotifications,
                    subtitle: t.notificationsLinkSubtitle,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsPage(user: widget.user))),
                  ),
                  const SizedBox(height: 8),
                  _LinkTile(
                    icon: Icons.lock_outline,
                    label: t.changePasswordLabel,
                    subtitle: t.changePasswordSubtitle,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanyChangePasswordScreen())),
                  ),
                  const SizedBox(height: 8),
                  _LinkTile(
                    icon: Icons.language_outlined,
                    label: t.languageSettingTitle,
                    subtitle: t.languageSettingSubtitle,
                    onTap: () => showLanguagePicker(context),
                  ),
                  const SizedBox(height: 24),
                  LightOutlineButton(label: t.logOutLabel, color: LightColors.error, onPressed: () => confirmAndLogout(context, light: true)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(),
        style: const TextStyle(color: LightColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.4));
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: LightColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: LightColors.border)),
      child: Row(
        children: [
          Icon(icon, color: LightColors.goldMuted, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: LightColors.textSecondary, fontSize: 11)),
                Text(value, style: const TextStyle(color: LightColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  const _LinkTile({required this.icon, required this.label, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LightColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: LightColors.border)),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: LightColors.gold.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: LightColors.goldMuted, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(color: LightColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(subtitle, style: const TextStyle(color: LightColors.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: LightColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
