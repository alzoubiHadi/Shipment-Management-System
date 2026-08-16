import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../API/config.dart';
import '../main.dart';
import 'ChangesRequiredEditScreen.dart';
import 'register_shared.dart';

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
///
/// Recolored 2026-08-21 to match the "Login Account States" mockup screens
/// (Pending Review / Changes Required / Rejected) — light theme, status
/// pill badge, icon circle, and (for pending) an application-status
/// checklist card.
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
  bool get _isRejected => widget.approvalStatus == 'rejected';
  bool get _isChangesRequired => widget.approvalStatus == 'changes_required';

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

  Future<void> _openEditScreen() async {
    final resubmitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ChangesRequiredEditScreen(
          accountType: widget.accountType,
          rejectionReason: widget.rejectionReason,
          documentIssues: widget.documentIssues,
        ),
      ),
    );
    // ChangesRequiredEditScreen pops `true` once it successfully resubmits
    // (status flips server-side back to 'pending') — everything this page
    // was built from (prefs, the login response) is now stale, so send
    // them back through login, same as the old inline resubmit did.
    if (resubmitted == true && mounted) {
      await _logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _isRejected ? LightColors.error : LightColors.pending;
    final colorBg = _isRejected ? LightColors.errorBg : LightColors.pendingBg;

    final icon = _isRejected
        ? Icons.gpp_bad_rounded
        : _isChangesRequired
            ? Icons.edit_note_rounded
            : Icons.hourglass_top_rounded;

    final pillLabel = _isRejected ? 'REJECTED' : (_isChangesRequired ? 'CHANGES REQUIRED' : 'PENDING');

    final title = _isRejected
        ? 'Registration Rejected'
        : _isChangesRequired
            ? 'Action Required'
            : 'Account Under Review';

    final body = _isRejected
        ? 'Unfortunately, your registration has been rejected.'
        : _isChangesRequired
            ? 'We need some changes in your documents or information. Please review the comments from admin and update your application.'
            : (widget.accountType == 'company'
                ? 'Your account is currently being reviewed by our team. You will be notified via email once your account is approved.'
                : 'Your account is currently being reviewed by our team. You will be notified via email once your account is approved.');

    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(backgroundColor: LightColors.bg, elevation: 0, automaticallyImplyLeading: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(color: colorBg, shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 38),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: colorBg, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    pillLabel,
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: LightColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(color: LightColors.textSecondary, fontSize: 14, height: 1.6),
              ),

              if ((_isRejected || _isChangesRequired) &&
                  widget.rejectionReason != null &&
                  widget.rejectionReason!.isNotEmpty) ...[
                const SizedBox(height: 20),
                _InfoBox(title: 'Reason from Admin', lines: [widget.rejectionReason!]),
              ],

              if (widget.documentIssues.isNotEmpty) ...[
                const SizedBox(height: 16),
                _InfoBox(title: 'Please update these documents', lines: widget.documentIssues),
              ],

              if (!_isRejected && !_isChangesRequired) ...[
                const SizedBox(height: 24),
                const _ApplicationStatusCard(),
              ],

              if (_isChangesRequired) ...[
                const SizedBox(height: 24),
                LightPrimaryButton(
                  label: 'Update Application',
                  color: LightColors.gold,
                  textColor: LightColors.textPrimary,
                  onPressed: _openEditScreen,
                ),
              ],

              if (_isRejected) ...[
                const SizedBox(height: 24),
                LightPrimaryButton(
                  label: 'Register Again',
                  color: LightColors.error,
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const SplashPage()),
                    (route) => false,
                  ),
                ),
                const SizedBox(height: 10),
                LightOutlineButton(
                  label: 'Contact Support',
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contact your admin for support')),
                  ),
                ),
              ],

              const SizedBox(height: 12),
              LightOutlineButton(label: 'Log Out', onPressed: _logout),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApplicationStatusCard extends StatelessWidget {
  const _ApplicationStatusCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LightColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LightColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Application Status', style: TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          SizedBox(height: 12),
          _StatusRow(label: 'Account Information', state: _RowState.done),
          SizedBox(height: 10),
          _StatusRow(label: 'Documents Submitted', state: _RowState.done),
          SizedBox(height: 10),
          _StatusRow(label: 'Under Admin Review', state: _RowState.active),
          SizedBox(height: 10),
          _StatusRow(label: 'Final Decision', state: _RowState.pending),
        ],
      ),
    );
  }
}

enum _RowState { done, active, pending }

class _StatusRow extends StatelessWidget {
  final String label;
  final _RowState state;
  const _StatusRow({required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    final icon = state == _RowState.done
        ? Icons.check_circle_rounded
        : state == _RowState.active
            ? Icons.access_time_filled_rounded
            : Icons.radio_button_unchecked_rounded;
    final color = state == _RowState.done
        ? LightColors.success
        : state == _RowState.active
            ? LightColors.pending
            : const Color(0xFFC4C8CF);
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: LightColors.textPrimary, fontSize: 13)),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String title;
  final List<String> lines;

  const _InfoBox({required this.title, required this.lines});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LightColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LightColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...lines.map(
            (l) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(l, style: const TextStyle(color: LightColors.textSecondary, fontSize: 13, height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }
}
