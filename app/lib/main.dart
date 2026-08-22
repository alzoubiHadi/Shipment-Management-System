import 'package:app/API/ProfileService.dart';
import 'package:app/Screens/DriverApprovalStatusPage.dart';
import 'package:app/Screens/HomeScreen.dart';
import 'package:app/Screens/LoginScreen.dart';
import 'package:app/models/Appuser.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'l10n/locale_controller.dart';
import 'theme/FmsTheme.dart';

/// Runs in a separate background isolate when a push arrives while the app
/// is backgrounded/terminated — must be a top-level function, and must
/// re-initialize Firebase itself since it doesn't share state with the
/// main isolate. The OS already shows the notification for a simple
/// notification+data payload; this hook exists for data-only pushes that
/// need custom handling.
@pragma('vm-entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  // 2026-08-22: load the persisted language choice (SharedPreferences
  // 'locale' key, same mechanism as token/role/id/...) before the first
  // frame, so a returning Arabic-preferring user doesn't see a flash of
  // English while LocaleController.locale still held its default. See
  // l10n/locale_controller.dart.
  await LocaleController.load();
  runApp(const MyApp());
}

/// Lets code without a BuildContext (like the FCM foreground-message
/// listener in PushNotificationSetup) still show a SnackBar/navigate.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 2026-08-22: rebuilds the whole MaterialApp (and therefore
    // Localizations/Directionality below it) whenever
    // LocaleController.setLocale() runs — e.g. from the language picker in
    // AdminSettingsPage/Profile/CompanyProfileScreen — so switching
    // language takes effect immediately with no app restart. See
    // l10n/locale_controller.dart.
    return ValueListenableBuilder<Locale>(
      valueListenable: LocaleController.locale,
      builder: (context, locale, _) {
        return MaterialApp(
          navigatorKey: rootNavigatorKey,
          title: 'FMS',
          debugShowCheckedModeBanner: false,
          // Central theme so any stock Material widget a screen doesn't
          // explicitly re-skin still falls back to FMS's Navy+Gold identity
          // instead of generic Material defaults. See theme/FmsTheme.dart.
          theme: FmsTheme.lightTheme,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SplashPage(),
        );
      },
    );
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  // Gates the marketing UI below behind a quick session check — LoggingInScreen
  // saves a token/loggedIn flag on success (see its _run()), and a returning,
  // still-logged-in user skips straight to their home screen instead of
  // seeing "Welcome Back!" + Log In again.
  bool _checkingSession = true;

  // Only an explicit AuthenticationException (server said 401 — the token
  // itself is invalid) clears the session. Every other failure — weak/no
  // internet, a Render cold-start timeout, a transient 500 — sets this flag
  // instead and keeps the token intact so the user can just hit Retry — see
  // _checkSession()'s two catch blocks and the offline-retry branch in
  // build().
  bool _sessionCheckFailed = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  /// Mirrors LoggingInScreen's post-login routing (approved → HomeScreen,
  /// unapproved driver/company → DriverApprovalStatusPage) so a resumed
  /// session behaves identically to a fresh login. Calls /me/profile both
  /// to fetch a live approval_status (it may have changed since the token
  /// was issued) and to double as a token-validity check.
  ///
  /// Only a 401 from that call (surfaced as AuthenticationException — see
  /// ProfileService.dart) means the token is actually invalid and the
  /// session should be cleared. Every other failure — no internet, a
  /// timeout, a 5xx — is a network/server problem, not proof the user is
  /// logged out, so the token is left alone and _sessionCheckFailed
  /// drives a Retry UI instead (see build()). This matters even more now
  /// that a driver mid-trip relies on background location tracking
  /// staying authenticated — see DriverLocationReporter.dart.
  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool('loggedIn') ?? false;
    final token = prefs.getString('token');

    if (!loggedIn || token == null || token.isEmpty) {
      _showWelcomeUi();
      return;
    }

    if (mounted) setState(() => _sessionCheckFailed = false);

    try {
      final profile = await ProfileService().fetchMyProfile();
      final role = profile['type']?.toString() ?? prefs.getString('role') ?? '';
      final rawPermissions = profile['permissions'];
      final user = AppUser(
        id: profile['id']?.toString() ?? prefs.getString('id') ?? '',
        name: profile['name']?.toString() ?? prefs.getString('name') ?? '',
        email: profile['email']?.toString() ?? prefs.getString('email') ?? '',
        role: role,
        permissions: rawPermissions is List
            ? List<String>.from(rawPermissions.map((e) => e.toString()))
            : const [],
      );

      final approvalStatus = profile['approval_status']?.toString() ?? 'approved';
      Widget destination;
      if (role == 'driver' && approvalStatus != 'approved') {
        final rawIssues = profile['document_issues'];
        destination = DriverApprovalStatusPage(
          approvalStatus: approvalStatus,
          rejectionReason: profile['rejection_reason']?.toString(),
          documentIssues: rawIssues is List ? List<String>.from(rawIssues.map((e) => e.toString())) : const [],
        );
      } else if (role == 'company' && approvalStatus != 'approved') {
        destination = DriverApprovalStatusPage(
          accountType: 'company',
          approvalStatus: approvalStatus,
          rejectionReason: profile['rejection_reason']?.toString(),
        );
      } else {
        destination = HomeScreen(user: user);
      }

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => destination));
    } on AuthenticationException {
      // Server explicitly rejected the token — this IS a "you're logged
      // out" case, so clear the stored session and fall back to a normal
      // manual login.
      await prefs.clear();
      _showWelcomeUi();
    } catch (_) {
      // Network error, timeout, or a non-401 server error — do NOT touch
      // the stored session. Show a retry state instead of silently
      // logging the user out from underneath them.
      if (!mounted) return;
      setState(() {
        _checkingSession = false;
        _sessionCheckFailed = true;
      });
    }
  }

  Future<void> _retrySessionCheck() async {
    setState(() => _checkingSession = true);
    await _checkSession();
  }

  void _showWelcomeUi() {
    if (!mounted) return;
    setState(() {
      _checkingSession = false;
      _sessionCheckFailed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    if (_checkingSession) {
      // Deliberately minimal (no "Welcome Back!" copy/buttons) — this is
      // only ever on screen for as long as one local prefs read plus, for
      // an already-logged-in user, one quick /me/profile call takes.
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0C),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
        ),
      );
    }

    if (_sessionCheckFailed) {
      // Couldn't reach the server to verify an EXISTING, still-locally-valid
      // session (see _checkSession()'s catch block) — this is deliberately
      // NOT the Welcome/Login screen. The token is untouched; a Retry that
      // succeeds goes straight to Home exactly like a normal resumed
      // session would, with no re-login required.
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0C),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, color: Color(0xFFD4AF37), size: 48),
                const SizedBox(height: 20),
                Text(
                  t.couldntConnectTitle,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  t.couldntConnectBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13.5, height: 1.5),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _retrySessionCheck,
                    icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF0A0A0C)),
                    label: Text(
                      t.commonRetry,
                      style: const TextStyle(color: Color(0xFF0A0A0C), fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // LoginScreen carries the hero image, branding, and the email/password
    // form directly — see LoginScreen.dart's docblock.
    return const LoginScreen();
  }
}