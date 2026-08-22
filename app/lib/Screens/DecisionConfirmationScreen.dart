import 'package:flutter/material.dart';

import '../API/config.dart';
import '../l10n/app_localizations.dart';
import 'register_shared.dart';

/// The 3 outcome confirmation screens from the 2026-08-21 admin dashboard
/// mockup (Changes Required Sent / Approved / Rejected) — shown after
/// RequestReviewScreen's Approve/Reject/Request Changes succeeds, replacing
/// that screen in the nav stack (see RequestReviewScreen._afterDecision()).
/// "Back to Requests" pops straight back to RegistrationRequestsScreen and
/// tells it to refresh, since this screen sits directly above it once
/// RequestReviewScreen has been replaced.
enum DecisionOutcome { approved, changesRequired, rejected }

class DecisionConfirmationScreen extends StatelessWidget {
  final DecisionOutcome outcome;
  final String name; // the driver/company name, for the message
  final bool isDriver;

  const DecisionConfirmationScreen({
    super.key,
    required this.outcome,
    required this.name,
    required this.isDriver,
  });

  Color get _color => switch (outcome) {
        DecisionOutcome.approved => LightColors.success,
        DecisionOutcome.changesRequired => LightColors.goldMuted,
        DecisionOutcome.rejected => LightColors.error,
      };

  Color get _bg => switch (outcome) {
        DecisionOutcome.approved => LightColors.successBg,
        DecisionOutcome.changesRequired => LightColors.gold.withOpacity(0.14),
        DecisionOutcome.rejected => LightColors.errorBg,
      };

  IconData get _icon => switch (outcome) {
        DecisionOutcome.approved => Icons.check_circle_rounded,
        DecisionOutcome.changesRequired => Icons.edit_note_rounded,
        DecisionOutcome.rejected => Icons.cancel_rounded,
      };

  String _title(AppLocalizations t) => switch (outcome) {
        DecisionOutcome.approved => t.decisionApprovedTitle,
        DecisionOutcome.changesRequired => t.decisionChangesRequestedTitle,
        DecisionOutcome.rejected => t.decisionRejectedTitle,
      };

  String _message(AppLocalizations t) {
    return switch (outcome) {
      DecisionOutcome.approved =>
        isDriver ? t.decisionApprovedMessageDriver(name) : t.decisionApprovedMessageCompany(name),
      DecisionOutcome.changesRequired => t.decisionChangesRequiredMessage(name),
      DecisionOutcome.rejected =>
        isDriver ? t.decisionRejectedMessageDriver(name) : t.decisionRejectedMessageCompany(name),
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: LightColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _bg),
                child: Icon(_icon, color: _color, size: 52),
              ),
              const SizedBox(height: 24),
              Text(_title(t),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: LightColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(_message(t),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: LightColors.textSecondary, fontSize: 14, height: 1.4)),
              const SizedBox(height: 36),
              LightPrimaryButton(
                label: t.backToRequestsButton,
                color: _color,
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
