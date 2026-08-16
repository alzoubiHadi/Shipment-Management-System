import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../API/config.dart';
import '../main.dart';

/// Shared logout flow, reachable from every role's screens (Profile for
/// driver/company, an AppBar action for admin — there is no admin Profile
/// tab). Confirms first, then clears the stored session (token/id/etc, the
/// same SharedPreferences keys every *Service class reads) and sends the
/// user back to SplashPage, exactly like DriverApprovalStatusPage._logout().
Future<void> confirmAndLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Log out', style: TextStyle(color: AppColors.cream)),
      content: const Text(
        'Are you sure you want to log out?',
        style: TextStyle(color: AppColors.muted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Log out', style: TextStyle(color: AppColors.error)),
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
