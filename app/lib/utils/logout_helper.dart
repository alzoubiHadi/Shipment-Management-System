import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../API/AuthResponse.dart';
import '../API/DriverLocationReporter.dart';
import '../API/DriverService.dart';
import '../API/config.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';

/// Shared logout flow, reachable from every role's screens (Profile for
/// driver/company, an AppBar action for admin — there is no admin Profile
/// tab). Confirms first, then clears the stored session (token/id/etc, the
/// same SharedPreferences keys every *Service class reads) and sends the
/// user back to SplashPage, exactly like DriverApprovalStatusPage._logout().
///
/// [light]: pass true from screens already migrated to the light redesign
/// (CompanyProfileScreen, AdminDrawer) so the confirmation dialog isn't a
/// jarring dark popup dropped into an otherwise light screen. Defaults to
/// false so the still-dark screens (Profile.dart, AppBarWidget, etc.) keep
/// their original look until they're redesigned too.
///
/// Background-tracking rule (2026-08-24): a driver with an active trip
/// (Shipment.status 1/2/5) must not be able to log out until it ends —
/// otherwise background GPS tracking would stop reporting the driver's
/// location to the company/admin mid-trip. DriverLocationReporter.hasActiveTrip
/// is only ever set for driver sessions (HomeScreen only starts the
/// reporter for role == 'driver'), so this check is a no-op — always
/// false — for company/admin, no role parameter needed here.
Future<void> confirmAndLogout(BuildContext context, {bool light = false}) async {
  final t = AppLocalizations.of(context)!;
  final prefs = await SharedPreferences.getInstance();

  // 2026-08-29 (audit item 10): DriverLocationReporter.hasActiveTrip is
  // only updated by a 45s background poll, so right after a fresh app
  // launch — before the first poll tick lands — it's still sitting at its
  // default `false` even if the driver genuinely has an active trip
  // server-side. Do one fresh check against the same lightweight
  // current-trip endpoint the poller itself uses (never the full shipment
  // list) at the exact moment of logout, instead of trusting a snapshot
  // that could be stale or not-yet-populated. Only meaningful for
  // drivers — the reporter/poller never runs for company/admin.
  if (prefs.getString('role') == 'driver') {
    try {
      final result = await DriverService.fetchCurrentTrip();
      DriverLocationReporter.hasActiveTrip.value = result['has_active_trip'] == true;
    } catch (_) {
      // Couldn't reach the server — fall back to whatever the poller last
      // knew, same fail-safe reasoning DriverLocationReporter itself uses
      // (never silently unblock logout just because a check failed).
    }
  }

  if (DriverLocationReporter.hasActiveTrip.value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t.logOutBlockedActiveTrip),
      ),
    );
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: light ? LightColors.surface : AppColors.surface,
      title: Text(t.logOutTitle, style: TextStyle(color: light ? LightColors.textPrimary : AppColors.cream)),
      content: Text(
        t.logOutConfirmMessage,
        style: TextStyle(color: light ? LightColors.textSecondary : AppColors.muted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(t.commonCancel, style: TextStyle(color: light ? LightColors.textSecondary : AppColors.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(t.logOutLabel, style: TextStyle(color: light ? LightColors.error : AppColors.error)),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  // 2026-08-29 (audit item 9): revoke the token server-side before wiping
  // it locally. ApiService.logout() is deliberately silent on failure —
  // the local session is cleared either way right below, so a network
  // hiccup here never traps the user; it just means server-side
  // revocation may not have completed (the token still expires on its
  // own naturally).
  await ApiService.logout();

  await prefs.clear();

  if (context.mounted) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SplashPage()),
      (route) => false,
    );
  }
}

/// Drop-in AppBar action icon — `actions: [logoutAction(context)]`.
///
/// [light]: same meaning as on [confirmAndLogout] — pass true from screens
/// already migrated to the light redesign so both the icon and the
/// confirmation dialog match. Defaults to false for any still-dark screens.
Widget logoutAction(BuildContext context, {bool light = false}) {
  return ValueListenableBuilder<bool>(
    valueListenable: DriverLocationReporter.hasActiveTrip,
    builder: (context, blocked, _) {
      final t = AppLocalizations.of(context)!;
      final color = light ? LightColors.textPrimary : AppColors.cream;
      return IconButton(
        icon: Icon(Icons.logout, color: blocked ? color.withOpacity(0.35) : color),
        tooltip: blocked ? t.logOutTooltipBlocked : t.logOutLabel,
        onPressed: () => confirmAndLogout(context, light: light),
      );
    },
  );
}
