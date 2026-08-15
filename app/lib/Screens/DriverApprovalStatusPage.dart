import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../API/config.dart';
import '../main.dart';

/// Shown instead of the normal HomeScreen when a driver's account is not
/// yet approved by an admin — either because they just self-registered
/// ('pending') or because an admin rejected their application ('rejected').
/// A driver in this state must not be able to reach any other screen (no
/// bottom nav, no shipment offers) until an admin approves them.
class DriverApprovalStatusPage extends StatelessWidget {
  final String approvalStatus; // 'pending' or 'rejected'
  final String? rejectionReason;
  final List<String> documentIssues;
  // 'driver' or 'company' — only changes the copy shown, the approval
  // workflow itself (Super Admin approve/reject/return-for-completion) is
  // identical for both since Phase 2.
  final String accountType;

  const DriverApprovalStatusPage({
    super.key,
    required this.approvalStatus,
    this.rejectionReason,
    this.documentIssues = const [],
    this.accountType = 'driver',
  });

  bool get _isRejected => approvalStatus == 'rejected';

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SplashPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: _isRejected
                      ? AppColors.error.withOpacity(0.12)
                      : AppColors.gold.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isRejected
                      ? Icons.block_rounded
                      : Icons.hourglass_top_rounded,
                  color: _isRejected ? AppColors.error : AppColors.gold,
                  size: 40,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                _isRejected ? 'Registration rejected' : 'Awaiting approval',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.cream,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isRejected
                    ? 'An admin reviewed your account and could not approve it at this time.'
                    : accountType == 'company'
                        ? 'Your account was created successfully. A Super Admin needs to review your company before you can start requesting shipments.'
                        : 'Your account was created successfully. An admin needs to review your documents (driver license, passport, residency) before you can start receiving shipments.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),

              if (_isRejected && rejectionReason != null && rejectionReason!.isNotEmpty) ...[
                const SizedBox(height: 20),
                _InfoBox(
                  color: AppColors.error,
                  icon: Icons.info_outline,
                  title: 'Reason',
                  lines: [rejectionReason!],
                ),
              ],

              if (documentIssues.isNotEmpty) ...[
                const SizedBox(height: 20),
                _InfoBox(
                  color: AppColors.info,
                  icon: Icons.description_outlined,
                  title: 'Please update these documents',
                  lines: documentIssues,
                ),
              ],

              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => _logout(context),
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
