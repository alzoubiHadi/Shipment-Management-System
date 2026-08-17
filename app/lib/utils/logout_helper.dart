import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../API/DriverLocationReporter.dart';
import '../API/config.dart';
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
  if (DriverLocationReporter.hasActiveTrip.value) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("You can't log out while a trip is in progress. Finish or hand off the trip first."),
      ),
    );
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: light ? LightColors.surface : AppColors.surface,
      title: Text('Log out', style: TextStyle(color: light ? LightColors.textPrimary : AppColors.cream)),
      content: Text(
        'Are you sure you want to log out?',
        style: TextStyle(color: light ? LightColors.textSecondary : AppColors.muted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel', style: TextStyle(color: light ? LightColors.textSecondary : AppColors.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('Log out', style: TextStyle(color: light ? LightColors.error : AppColors.error)),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

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

/// Drop-in AppBar action icon — `actions: [logoutAction(context)]`.
///
/// [light]: same meaning as on [confirmAndLogout] — pass true from screens
/// already migrated to the light redesign so both the icon and the
/// confirmation dialog match. Defaults to false for any still-dark screens.
Widget logoutAction(BuildContext context, {bool light = false}) {
  return ValueListenableBuilder<bool>(
    valueListenable: DriverLocationReporter.hasActiveTrip,
    builder: (context, blocked, _) {
      final color = light ? LightColors.textPrimary : AppColors.cream;
      return IconButton(
        icon: Icon(Icons.logout, color: blocked ? color.withOpacity(0.35) : color),
        tooltip: blocked ? "Log out (unavailable during an active trip)" : 'Log out',
        onPressed: () => confirmAndLogout(context, light: light),
      );
    },
  );
}
