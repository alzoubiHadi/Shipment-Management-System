import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
Future<void> confirmAndLogout(BuildContext context, {bool light = false}) async {
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
Widget logoutAction(BuildContext context) {
  return IconButton(
    icon: const Icon(Icons.logout, color: AppColors.cream),
    tooltip: 'Log out',
    onPressed: () => confirmAndLogout(context),
  );
}
