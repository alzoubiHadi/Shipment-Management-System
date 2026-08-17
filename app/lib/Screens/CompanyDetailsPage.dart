import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../API/CompanyService.dart';
import '../API/config.dart';
import '../models/Company.dart';

class CompanyDetailsPage extends StatefulWidget {
  final Company company;

  const CompanyDetailsPage({
    super.key,
    required this.company,
  });

  @override
  State<CompanyDetailsPage> createState() => _CompanyDetailsPageState();
}

class _CompanyDetailsPageState extends State<CompanyDetailsPage> {
  late Company company = widget.company;
  bool _busy = false;

  Color get _statusColor =>
      company.accountStatus == 'suspended' ? LightColors.error : LightColors.success;

  Color get _approvalColor => switch (company.approvalStatus) {
        'approved' => LightColors.success,
        'rejected' => LightColors.error,
        _ => LightColors.info,
      };

  String get _approvalLabel => switch (company.approvalStatus) {
        'approved' => 'Approved',
        'rejected' => 'Rejected',
        _ => 'Pending review',
      };

  /// UC-5: Super Admin final approval of a self-registered company.
  Future<void> _approve() async {
    setState(() => _busy = true);
    final result = await CompanyService.approveCompany(company.id);
    setState(() => _busy = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']?.toString() ?? '')),
    );
    if (result['success'] == true) {
      setState(() {
        company = company.copyWith(
          approvalStatus: 'approved',
          clearRejectionReason: true,
        );
      });
    }
  }

  /// UC-5: Super Admin outright rejects a self-registered company.
  Future<void> _reject() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LightColors.surface,
        title: const Text('Reject Company', style: TextStyle(color: LightColors.cream)),
        content: TextField(
          controller: reasonCtrl,
          style: const TextStyle(color: LightColors.cream),
          decoration: const InputDecoration(
            hintText: 'Reason (optional)',
            hintStyle: TextStyle(color: LightColors.muted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: LightColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject', style: TextStyle(color: LightColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _busy = true);
    final success = await CompanyService.rejectCompany(company.id, reason: reasonCtrl.text.trim());
    setState(() => _busy = false);

    if (!mounted) return;
    if (success) {
      setState(() {
        company = company.copyWith(
          approvalStatus: 'rejected',
          rejectionReason: reasonCtrl.text.trim(),
        );
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not reject company')),
      );
    }
  }

  /// Opens the company's uploaded trade/commercial license file in an
  /// external viewer (browser/PDF app) — the app itself doesn't render
  /// PDFs, so this hands off to whatever the device already has.
  Future<void> _openLicense() async {
    final path = company.licenseFilePath;
    if (path == null || path.isEmpty) return;

    final uri = Uri.parse(storageUrl(path));
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open license file')),
      );
    }
  }

  /// UC-27: Super Admin temporarily suspends a company account.
  Future<void> _suspend() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LightColors.surface,
        title: const Text('Suspend Company', style: TextStyle(color: LightColors.cream)),
        content: TextField(
          controller: reasonCtrl,
          style: const TextStyle(color: LightColors.cream),
          decoration: const InputDecoration(
            hintText: 'Reason (required)',
            hintStyle: TextStyle(color: LightColors.muted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: LightColors.muted)),
          ),
          TextButton(
            onPressed: reasonCtrl.text.trim().isEmpty
                ? null
                : () => Navigator.pop(ctx, true),
            child: const Text('Suspend', style: TextStyle(color: LightColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true || reasonCtrl.text.trim().isEmpty) return;

    setState(() => _busy = true);
    final result = await CompanyService.suspendCompany(
      companyId: company.id,
      reason: reasonCtrl.text.trim(),
    );
    setState(() => _busy = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']?.toString() ?? '')),
    );
    if (result['success'] == true) {
      setState(() {
        company = company.copyWith(
          accountStatus: 'suspended',
          suspensionReason: reasonCtrl.text.trim(),
        );
      });
    }
  }

  Future<void> _activate() async {
    setState(() => _busy = true);
    final result = await CompanyService.activateCompany(company.id);
    setState(() => _busy = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']?.toString() ?? '')),
    );
    if (result['success'] == true) {
      setState(() {
        company = company.copyWith(
          accountStatus: 'active',
          clearSuspensionReason: true,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: LightColors.cream),
        title: const Text(
          'Company Details',
          style: TextStyle(
            color: LightColors.cream,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: LightColors.surfaceHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: LightColors.border,
            ),
          ),
          child: Column(
            children: [
              // Company Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: LightColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: LightColors.gold,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.business,
                  size: 48,
                  color: LightColors.gold,
                ),
              ),
              const SizedBox(height: 20),

              // Company Name
              Text(
                company.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: LightColors.cream,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                company.email,
                style: const TextStyle(
                  fontSize: 14,
                  color: LightColors.muted,
                ),
              ),

              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _approvalColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _approvalLabel,
                      style: TextStyle(color: _approvalColor, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      company.accountStatus == 'suspended' ? 'Suspended' : 'Active',
                      style: TextStyle(color: _statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Divider(
                color: LightColors.border,
                thickness: 1,
              ),
              const SizedBox(height: 16),

              _buildItem("ID", company.id),
              _buildItem("Phone", company.phone),
              _buildItem("User ID", company.user_id),

              if (company.password.isNotEmpty)
                _buildItem("Password", "********"),

              if (company.accountStatus == 'suspended' &&
                  (company.suspensionReason ?? '').isNotEmpty)
                _buildItem("Suspension Reason", company.suspensionReason),

              if (company.approvalStatus == 'rejected' &&
                  (company.rejectionReason ?? '').isNotEmpty)
                _buildItem("Rejection Reason", company.rejectionReason),

              if ((company.licenseFilePath ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openLicense,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: LightColors.gold),
                    ),
                    icon: const Icon(Icons.description_outlined, size: 18, color: LightColors.gold),
                    label: const Text('View Trade License', style: TextStyle(color: LightColors.gold)),
                  ),
                ),
              ] else if (company.approvalStatus == 'pending') ...[
                const SizedBox(height: 8),
                _buildItem("Trade License", "Not provided"),
              ],

              if (company.approvalStatus == 'pending') ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : _approve,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LightColors.success,
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Approve'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _reject,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: LightColors.error),
                        ),
                        icon: const Icon(Icons.cancel_outlined, size: 18, color: LightColors.error),
                        label: const Text('Reject', style: TextStyle(color: LightColors.error)),
                      ),
                    ),
                  ],
                ),
              ],

              if (company.approvalStatus == 'approved') ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: company.accountStatus == 'suspended'
                      ? OutlinedButton.icon(
                          onPressed: _busy ? null : _activate,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: LightColors.success),
                          ),
                          icon: const Icon(Icons.refresh, size: 18, color: LightColors.success),
                          label: const Text('Activate', style: TextStyle(color: LightColors.success)),
                        )
                      : OutlinedButton.icon(
                          onPressed: _busy ? null : _suspend,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: LightColors.error),
                          ),
                          icon: const Icon(Icons.block, size: 18, color: LightColors.error),
                          label: const Text('Suspend', style: TextStyle(color: LightColors.error)),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: LightColors.muted,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              (value == null || value.isEmpty) ? "-" : value,
              style: const TextStyle(
                color: LightColors.cream,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
