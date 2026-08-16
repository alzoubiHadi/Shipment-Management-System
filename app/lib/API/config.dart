library config;

import 'dart:ui';

// Deployed backend (Render) — works from any device, any network, no need
// to be on the same Wi-Fi or run a local server. If you ever go back to
// running the server locally instead, swap this for
// "http://<LAN-IP>:8000/api" and make sure `php artisan serve
// --host=0.0.0.0 --port=8000` is running.
String baseUrl = "https://shipment-management-system.onrender.com/api";

/// Turns a relative path returned by the backend (e.g. from
/// Storage::disk('public')->store(...), like "payment_receipts/xyz.png")
/// into a fully-qualified URL under Laravel's public storage symlink.
/// Requires `php artisan storage:link` to have been run once on the server.
String storageUrl(String relativePath) {
  final base = baseUrl.endsWith('/api')
      ? baseUrl.substring(0, baseUrl.length - 4)
      : baseUrl;
  return '$base/storage/$relativePath';
}





// Must mirror Truck::TRUCK_TYPES on the backend exactly (server rejects
// anything else with a 422). Kept here as the single Flutter-side source
// of truth for the truck-type dropdowns (AddTruckPage, offer creation).
// Web push (FCM) needs a VAPID public key to fetch a token — get it from
// Firebase Console -> Project Settings -> Cloud Messaging -> Web Push
// certificates -> "Key pair". Leave empty to skip token registration on
// web only; Android/iOS don't need this at all.
const String kFcmWebVapidKey = 'BPjIsOd0TF_SpfRnozlWal8abK7R4FA4em6H2HCDK4O8KS19kMoh_ObARBC3QTduwowC34Z97ZHZXf7XJ5HBAJc';

const List<String> kTruckTypes = [
  '3 Ton pick up',
  '7 Ton pick up',
  '10 Ton pick up',
  'Trailer 40 FT-12M-Open',
  'Trailer 40 FT-12M-Box',
  'Trailer 50 FT-15M-Open',
  'Curtain Trailer 13.5M',
  'Curtain Trailer 15M',
  'Reefer Trailer',
  'Lowbed Trailer - 25 Tons',
  'Car Career',
];

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

/// Light theme tokens (2026-08-21 design pass) — used by the auth/
/// onboarding screens (Welcome screen stays dark/gold; everything after it
/// — Login, role confirm, registration wizards, account-status screens —
/// switches to this light palette to match the design mockups). Kept
/// separate from [AppColors] (dark) since the rest of the app — dashboard,
/// shipments, admin screens — hasn't been redesigned yet and still relies
/// on the dark palette; migrating those is a separate, larger follow-up.
class LightColors {
  static const bg           = Color(0xFFF7F8FA);
  static const surface      = Color(0xFFFFFFFF);
  static const border       = Color(0xFFE3E5EA);
  static const textPrimary  = Color(0xFF14161A);
  static const textSecondary = Color(0xFF6B7280);
  static const gold         = Color(0xFFD4AF37);
  static const goldMuted    = Color(0xFFB8962E);
  static const navy         = Color(0xFF16213E);
  static const success      = Color(0xFF16A34A);
  static const successBg    = Color(0xFFE9F8EF);
  static const pending      = Color(0xFFF59E0B);
  static const pendingBg    = Color(0xFFFEF3E2);
  static const error        = Color(0xFFDC2626);
  static const errorBg      = Color(0xFFFDECEC);
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
