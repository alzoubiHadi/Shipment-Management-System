import 'package:flutter/material.dart';
import '../API/config.dart';
import '../models/Company.dart';

/// Read-only "Company Information" screen (Companies list Phase 3,
/// 2026-08-22). Shows every currently available piece of company data on
/// one page — no approve/reject/suspend/reactivate/edit controls here.
/// Approve/Reject/Request Changes live in RequestReviewScreen, and
/// Suspend/Reactivate/Delete live directly on the Companies list cards.
/// Reuses only the existing Company model fields; no new fields or
/// fabricated statistics are introduced (the Company model doesn't carry
/// shipment/driver counts or a rating, so no stats section is shown).
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

  Color get _statusColor =>
      company.accountStatus == 'suspended' ? LightColors.error : LightColors.success;

  Color get _approvalColor => switch (company.approvalStatus) {
        'approved' => LightColors.success,
        'rejected' => LightColors.error,
        'changes_required' => LightColors.goldMuted,
        _ => LightColors.info,
      };

  String get _approvalLabel => switch (company.approvalStatus) {
        'approved' => 'Approved',
        'rejected' => 'Rejected',
        'changes_required' => 'Changes requested',
        _ => 'Pending review',
      };

  /// 2026-08-27 (security review, item 7): the license file moved to the
  /// private disk, so it's fetched through the authenticated
  /// /companies/{id}/license/file endpoint instead of a plain storage URL.
  Future<void> _openLicense() async {
    final path = company.licenseFilePath;
    if (path == null || path.isEmpty) return;
    await viewSecureFile(context, '$baseUrl/companies/${company.id}/license/file');
  }

  String _fmtDate(DateTime? d) =>
      d == null ? '' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: LightColors.textPrimary),
        title: const Text(
          'Company Information',
          style: TextStyle(
            color: LightColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: LightColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: LightColors.border),
          ),
          child: Column(
            children: [
              // Company Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: LightColors.surfaceHigh,
                  shape: BoxShape.circle,
                  border: Border.all(color: LightColors.gold, width: 2),
                ),
                child: const Icon(
                  Icons.business,
                  size: 48,
                  color: LightColors.gold,
                ),
              ),
              const SizedBox(height: 20),

              // Company Name + code
              Text(
                company.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: LightColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'CO-${company.id}',
                style: const TextStyle(
                  fontSize: 13,
                  color: LightColors.textSecondary,
                ),
              ),

              const SizedBox(height: 12),
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

              if (company.approvalStatus == 'rejected' &&
                  (company.rejectionReason ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Reason: ${company.rejectionReason}',
                  style: const TextStyle(fontSize: 12, color: LightColors.error),
                ),
              ],

              const SizedBox(height: 24),
              const Divider(color: LightColors.border, thickness: 1),
              const SizedBox(height: 16),

              // Basic company information
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: const Text('Basic Information',
                    style: TextStyle(fontWeight: FontWeight.w600, color: LightColors.textPrimary, fontSize: 15)),
              ),
              const SizedBox(height: 8),
              _buildItem("Company Name", company.name),
              _buildItem("Company Code", 'CO-${company.id}'),
              _buildItem("Registered On", _fmtDate(company.createdAt)),

              const SizedBox(height: 12),
              const Divider(color: LightColors.border, thickness: 1),
              const SizedBox(height: 16),

              // Contact information
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: const Text('Contact Information',
                    style: TextStyle(fontWeight: FontWeight.w600, color: LightColors.textPrimary, fontSize: 15)),
              ),
              const SizedBox(height: 8),
              _buildItem("Email", company.email),
              _buildItem("Phone", company.phone),

              const SizedBox(height: 12),
              const Divider(color: LightColors.border, thickness: 1),
              const SizedBox(height: 16),

              // Account status
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: const Text('Account Status',
                    style: TextStyle(fontWeight: FontWeight.w600, color: LightColors.textPrimary, fontSize: 15)),
              ),
              const SizedBox(height: 8),
              _buildItem("Approval Status", _approvalLabel),
              _buildItem("Account Status", company.accountStatus == 'suspended' ? 'Suspended' : 'Active'),
              if (company.accountStatus == 'suspended' && (company.suspensionReason ?? '').isNotEmpty)
                _buildItem("Suspension Reason", company.suspensionReason),
              _buildItem(
                "Compliance Status",
                company.complianceStatus == 'action_required' ? 'Action required' : 'Active',
              ),

              const SizedBox(height: 12),
              const Divider(color: LightColors.border, thickness: 1),
              const SizedBox(height: 16),

              // Additional information currently available from the API
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: const Text('Additional Information',
                    style: TextStyle(fontWeight: FontWeight.w600, color: LightColors.textPrimary, fontSize: 15)),
              ),
              const SizedBox(height: 8),
              _buildItem("Balance", company.balance.toStringAsFixed(2)),
              _buildItem("Credit Limit", company.creditLimit.toStringAsFixed(2)),
              _buildItem("User ID", company.user_id),

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
                    label: const Text('View Trade License', style: TextStyle(color: LightColors.goldMuted)),
                  ),
                ),
              ] else if (company.approvalStatus == 'pending') ...[
                const SizedBox(height: 8),
                _buildItem("Trade License", "Not provided"),
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
                color: LightColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              (value == null || value.isEmpty) ? "-" : value,
              style: const TextStyle(
                color: LightColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
