import 'package:flutter/material.dart';

import '../API/config.dart';

/// Admin Shipments redesign (2026-08-24): shared status-pill styling so the
/// list cards and every detail screen (Live Tracking / Trip Report /
/// Cancellation Report / Matching Status) agree on the same colors.
class AdminShipmentStatusStyle {
  final Color color;
  final Color bg;

  const AdminShipmentStatusStyle(this.color, this.bg);

  static AdminShipmentStatusStyle forGroup(String statusGroup) {
    switch (statusGroup) {
      case 'delivered':
        return const AdminShipmentStatusStyle(LightColors.success, LightColors.successBg);
      case 'cancelled':
        return const AdminShipmentStatusStyle(LightColors.error, LightColors.errorBg);
      case 'pending':
        return const AdminShipmentStatusStyle(LightColors.pending, LightColors.pendingBg);
      case 'active':
      default:
        return const AdminShipmentStatusStyle(LightColors.navy, Color(0xFFE7EAF3));
    }
  }
}

class AdminStatusPill extends StatelessWidget {
  final String label;
  final String statusGroup;

  const AdminStatusPill({super.key, required this.label, required this.statusGroup});

  @override
  Widget build(BuildContext context) {
    final style = AdminShipmentStatusStyle.forGroup(statusGroup);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: style.color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3),
      ),
    );
  }
}
