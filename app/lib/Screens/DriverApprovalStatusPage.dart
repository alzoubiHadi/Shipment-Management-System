import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../API/ProfileService.dart';
import '../API/config.dart';
import '../main.dart';
import 'DriverDestinationsPage.dart';
import 'DriverDocumentsPage.dart';

/// Shown instead of the normal HomeScreen when a driver/company account is
/// not yet approved by an admin:
/// - 'pending' — just self-registered, never reviewed yet.
/// - 'changes_required' — an admin reviewed it and asked for specific
///   fixes (see rejectionReason); the owner can edit the flagged items
///   right here and resubmit, which puts them back in the 'pending' queue.
/// - 'rejected' — permanently terminal, no self-service path back.
/// A driver/company in any of these states must not be able to reach any
/// other screen (no bottom nav, no shipment offers) until an admin
/// approves them.
class DriverApprovalStatusPage extends StatefulWidget {
  final String approvalStatus;
  final String? rejectionReason;
  final List<String> documentIssues;
  // 'driver' or 'company' — changes both the copy and which self-service
  // actions are offered (documents/destinations for drivers, trade
  // license for companies) — the underlying approval workflow itself
  // (Super Admin approve/reject/return-for-completion) is identical.
  final String accountType;

  const DriverApprovalStatusPage({
    super.key,
    required this.approvalStatus,
    this.rejectionReason,
    this.documentIssues = const [],
    this.accountType = 'driver',
  });

  @override
  State<DriverApprovalStatusPage> createState() => _DriverApprovalStatusPageState();
}

class _DriverApprovalStatusPageState extends State<DriverApprovalStatusPage> {
  final _service = ProfileService();
  bool _resubmitting = false;
  bool _submittingLicense = false;

  bool get _isRejected => widget.approvalStatus == 'rejected';
  bool get _isChangesRequired => widget.approvalStatus == 'changes_required';
  bool get _isCompany => widget.accountType == 'company';

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SplashPage()),
        (route) => false,
      );
    }
  }

  Future<void> _resubmit() async {
    setState(() => _resubmitting = true);
    final result = _isCompany
        ? await _service.resubmitCompanyApplication()
        : await _service.resubmitDriverApplication();
    if (!mounted) return;
    setState(() => _resubmitting = false);

    if (result['success'] == true) {
      // The account's status just changed server-side (back to 'pending')
      // but everything this screen was built from (prefs, the login
      // response) is now stale — simplest correct thing is to send them
      // back through login, which always fetches a fresh status.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submitted for review — please log in again to see your status')),
        );
      }
      await Future.delayed(const Duration(seconds: 1));
      await _logout();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Could not resubmit')),
      );
    }
  }

  Future<void> _renewCompanyLicense() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || result.files.single.bytes == null) return;

    setState(() => _submittingLicense = true);
    final r = await _service.submitCompanyLicense(
      fileBytes: result.files.single.bytes!,
      fileName: result.files.single.name,
    );
    if (!mounted) return;
    setState(() => _submittingLicense = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(r['message']?.toString() ?? '')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _isRejected
        ? AppColors.error
        : _isChangesRequired
            ? AppColors.gold
            : AppColors.gold;

    final icon = _isRejected
        ? Icons.block_rounded
        : _isChangesRequired
            ? Icons.edit_note_rounded
            : Icons.hourglass_top_rounded;

    final title = _isRejected
        ? 'Registration rejected'
        : _isChangesRequired
            ? 'Action required'
            : 'Awaiting approval';

    final body = _isRejected
        ? 'An admin reviewed your account and could not approve it at this time.'
        : _isChangesRequired
            ? 'An admin reviewed your application and needs some changes before it can be approved. See the reason below, make the fix, then resubmit.'
            : widget.accountType == 'company'
                ? 'Your account was created successfully. A Super Admin needs to review your company before you can start requesting shipments.'
                : 'Your account was created successfully. An admin needs to review your documents (driver license, passport, residency) before you can start receiving shipments.';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 40),
              ),
              const SizedBox(height: 28),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.cream,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),

              if ((_isRejected || _isChangesRequired) &&
                  widget.rejectionReason != null &&
                  widget.rejectionReason!.isNotEmpty) ...[
                const SizedBox(height: 20),
                _InfoBox(
                  color: color,
                  icon: Icons.info_outline,
                  title: 'Reason from admin',
                  lines: [widget.rejectionReason!],
                ),
              ],

              if (widget.documentIssues.isNotEmpty) ...[
                const SizedBox(height: 20),
                _InfoBox(
                  color: AppColors.info,
                  icon: Icons.description_outlined,
                  title: 'Please update these documents',
                  lines: widget.documentIssues,
                ),
              ],

              if (_isChangesRequired) ...[
                const SizedBox(height: 28),
                if (!_isCompany) ...[
                  _ActionButton(
                    icon: Icons.folder_open_rounded,
                    label: 'Update documents',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DriverDocumentsPage()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ActionButton(
                    icon: Icons.map_outlined,
                    label: 'Update work destinations',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DriverDestinationsPage()),
                    ),
                  ),
                ] else
                  _ActionButton(
                    icon: Icons.description_outlined,
                    label: _submittingLicense ? 'Uploading…' : 'Update trade license',
                    onPressed: _submittingLicense ? null : _renewCompanyLicense,
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _resubmitting ? null : _resubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _resubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg),
                          )
                        : const Text(
                            'Resubmit for review',
                            style: TextStyle(color: AppColors.bg, fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _logout,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Log out',
                    style: TextStyle(color: AppColors.cream, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _ActionButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: AppColors.gold),
        label: Text(label, style: const TextStyle(color: AppColors.cream, fontSize: 14)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final List<String> lines;

  const _InfoBox({
    required this.color,
    required this.icon,
    required this.title,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...lines.map(
            (l) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '•  $l',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
