import 'package:flutter/material.dart';

import '../API/config.dart';

enum FmsStatusTone { success, warning, info, error, neutral }

/// FMS design system semantic status colors (2026-08-24) — "لا نستخدم Gold
/// لكل الحالات" per the spec. One mapping used everywhere a status
/// badge/pill is shown (shipments, documents, approvals, compliance):
///   - Active/Delivered/Approved/Valid -> green
///   - Pending/Expiring Soon -> amber
///   - In Transit -> blue
///   - Expired/Rejected/Cancelled/Action Required -> red
///   - Pending Review -> blue/indigo
///   - Inactive/Superseded -> gray
///
/// [FmsStatusBadge.forStatus] takes a raw backend status string (any
/// casing/underscore style) and resolves it via keyword matching, so
/// callers don't need to hand-map every one of the many distinct status
/// vocabularies in this app (compliance_status, document status,
/// approval_status, shipment status labels, offer status...) — they can
/// just pass the raw value through.
class FmsStatusBadge extends StatelessWidget {
  final String label;
  final FmsStatusTone tone;

  const FmsStatusBadge({super.key, required this.label, required this.tone});

  factory FmsStatusBadge.forStatus(String rawStatus, {String? labelOverride}) {
    return FmsStatusBadge(label: labelOverride ?? rawStatus, tone: toneFor(rawStatus));
  }

  static FmsStatusTone toneFor(String rawStatus) {
    final s = rawStatus.toLowerCase();

    if (_matchesAny(s, ['expired', 'rejected', 'cancelled', 'canceled', 'action_required', 'suspended', 'banned', 'disputed', 'changes_required'])) {
      return FmsStatusTone.error;
    }
    if (_matchesAny(s, ['expiring_soon', 'pending', 'awaiting', 'matching', 'escalated', 'warning'])) {
      return FmsStatusTone.warning;
    }
    if (_matchesAny(s, ['transit', 'progress', 'pending_review', 'review', 'loading', 'loaded', 'assigned'])) {
      return FmsStatusTone.info;
    }
    if (_matchesAny(s, ['inactive', 'superseded', 'not_uploaded', 'unknown'])) {
      return FmsStatusTone.neutral;
    }
    if (_matchesAny(s, ['active', 'delivered', 'approved', 'valid', 'confirmed', 'completed', 'accepted', 'available'])) {
      return FmsStatusTone.success;
    }

    return FmsStatusTone.neutral;
  }

  static bool _matchesAny(String haystack, List<String> needles) => needles.any(haystack.contains);

  static (Color, Color) _colorsFor(FmsStatusTone tone) {
    switch (tone) {
      case FmsStatusTone.success:
        return (LightColors.success, LightColors.successBg);
      case FmsStatusTone.warning:
        return (LightColors.pending, LightColors.pendingBg);
      case FmsStatusTone.info:
        return (LightColors.info, LightColors.infoBg);
      case FmsStatusTone.error:
        return (LightColors.error, LightColors.errorBg);
      case FmsStatusTone.neutral:
        return (LightColors.textSecondary, LightColors.surfaceHigh);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (color, bg) = _colorsFor(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3),
      ),
    );
  }
}
