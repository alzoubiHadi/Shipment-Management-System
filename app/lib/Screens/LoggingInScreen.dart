import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../API/AuthResponse.dart';
import '../API/config.dart';
import '../API/error_messages.dart';
import '../l10n/app_localizations.dart';
import '../models/Appuser.dart';
import 'DriverApprovalStatusPage.dart';
import 'ForceChangePasswordScreen.dart';
import 'HomeScreen.dart';

/// Login-design screen 3 ("Logging you in..."). Runs the actual
/// ApiService.login() call and all of the post-login branching (force
/// password change, unapproved driver/company, role confirm) that used to
/// live inline in LoginScreen._handleLogin — pulled out here so that logic
/// has a real full-screen "please wait" moment to live in, matching the
/// mockup, instead of just a spinner inside the button.
///
/// Pops with an error message (String) if login fails, so LoginScreen can
/// show it inline; on success it replaces the whole stack itself (Splash →
/// Login → LoggingIn all get cleared) — this screen is never something the
/// user can navigate back into.
class LoggingInScreen extends StatefulWidget {
  final String email;
  final String password;

  const LoggingInScreen({super.key, required this.email, required this.password});

  @override
  State<LoggingInScreen> createState() => _LoggingInScreenState();
}

class _LoggingInScreenState extends State<LoggingInScreen> {
  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final started = DateTime.now();
    try {
      final response = await ApiService.login(email: widget.email, password: widget.password);

      // Keep this screen visible for at least a moment so it doesn't just
      // flash by on a fast connection — matches the design's dedicated
      // loading step rather than looking like a glitch.
      final elapsed = DateTime.now().difference(started);
      const minDuration = Duration(milliseconds: 700);
      if (elapsed < minDuration) {
        await Future.delayed(minDuration - elapsed);
      }
      if (!mounted) return;

      // A sub-admin logging in for the first time on their one-time
      // temporary password must set a real one before reaching anything
      // else (UC-7).
      if (response.mustChangePassword) {
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('token', response.token);
        prefs.setString('email', response.email);
        prefs.setString('id', response.userId);
        prefs.setString('name', response.name);
        prefs.setString('role', response.role.toString());
        prefs.setBool('loggedIn', true);

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => ForceChangePasswordScreen(
              user: AppUser(
                name: response.name,
                email: response.email,
                role: response.role,
                id: response.userId,
                permissions: response.permissions,
              ),
            ),
          ),
          (route) => false,
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      prefs.setString('token', response.token);
      prefs.setString('email', response.email);
      prefs.setString('id', response.userId);
      prefs.setString('name', response.name);
      prefs.setString('role', response.role.toString());
      prefs.setBool('loggedIn', true);

      if (!mounted) return;

      // A driver/company whose account isn't approved yet (pending,
      // changes_required, or rejected) must not reach the normal app —
      // send them to the status screen instead, on every login, until an
      // admin approves them.
      final isUnapprovedDriver = response.role == 'driver' && response.driverApprovalStatus != 'approved';
      final isUnapprovedCompany = response.role == 'company' && response.companyApprovalStatus != 'approved';

      // Login NEVER shows the OTP code screen — that only ever appears
      // once, immediately after a brand-new sign-up. Email verification
      // status plays no role here; the only thing login checks is whether
      // there are outstanding items (admin approval, documents) — shown
      // via DriverApprovalStatusPage, never a code entry field.
      final destination = isUnapprovedDriver
          ? DriverApprovalStatusPage(
              approvalStatus: response.driverApprovalStatus,
              rejectionReason: response.driverRejectionReason,
              documentIssues: response.driverDocumentIssues,
            )
          : isUnapprovedCompany
              ? DriverApprovalStatusPage(
                  accountType: 'company',
                  approvalStatus: response.companyApprovalStatus,
                  rejectionReason: response.companyRejectionReason,
                )
              : HomeScreen(
                  user: AppUser(
                    name: response.name,
                    email: widget.email,
                    role: response.role,
                    id: response.userId,
                    permissions: response.permissions,
                  ),
                );

      // 2026-08-21: RoleConfirmScreen ("Welcome Back — select your role to
      // continue") used to sit here as an unconditional extra tap for
      // every single login regardless of role — removed on request. Each
      // account has exactly one fixed role, so it never actually let
      // anyone pick anything; it was just an unwanted extra screen.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => destination),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (mounted) Navigator.pop(context, e.message);
    } catch (e) {
      // ApiService.login() already converts network/parsing failures into a
      // friendly ApiException — this only catches anything unexpected that
      // slips past that (see AuthResponse.dart's networkErrorMessage()).
      if (mounted) Navigator.pop(context, networkErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: LightColors.bg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(color: LightColors.gold.withOpacity(0.12), shape: BoxShape.circle),
                child: const Icon(Icons.local_shipping_rounded, color: LightColors.gold, size: 44),
              ),
              const SizedBox(height: 28),
              Text(
                t.loggingInTitle,
                style: const TextStyle(color: LightColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                t.loggingInSubtitle,
                style: const TextStyle(color: LightColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 160,
                child: Row(
                  children: List.generate(
                    3,
                    (i) => Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsetsDirectional.only(end: i < 2 ? 6 : 0),
                        decoration: BoxDecoration(
                          color: i == 0 ? LightColors.gold : LightColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
