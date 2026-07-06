library config;

import 'dart:ui';

String baseUrl = "http://127.0.0.1:8000/api";





class AppColors {
  static const bg           = Color(0xFF0A0A0C);
  static const surface      = Color(0xFF111113);
  static const surfaceHigh  = Color(0xFF181820);
  static const border       = Color(0xFF2A2520);
  static const gold         = Color(0xFFD4AF37);
  static const goldMuted    = Color(0xFFB8962E);
  static const cream        = Color(0xFFF5F0E8);
  static const muted        = Color(0xFF6B6660);
  static const mutedLight   = Color(0xFF4A4540);
  static const error        = Color(0xFFE57373);
  static const success      = Color(0xFF66BB6A);
  static const info         = Color(0xFF64B5F6);
}

String statusLabel(dynamic status) {
  switch (status) {
    case 0:
      return "Pending";
    case 1:
      return "In Transit";
    case 2:
      return "Out for Delivery";
    case 3:
      return "Delivered";
    case 4:
      return "Cancelled";
    case 5:
      return "Delayed";
    default:
      return "Unknown";
  }
}

/// Reverse of [statusLabel] — converts a label picked in the UI back to the
/// numeric code the server expects. Without this, sending the label text
/// directly made the server's `(int) $status` cast silently fall back to 0.
int statusValue(String label) {
  switch (label) {
    case "Pending":
      return 0;
    case "In Transit":
      return 1;
    case "Out for Delivery":
      return 2;
    case "Delivered":
      return 3;
    case "Cancelled":
      return 4;
    case "Delayed":
      return 5;
    default:
      return 0;
  }
}
