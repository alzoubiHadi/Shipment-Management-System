import 'package:app/API/ProfileService.dart';
import 'package:app/Screens/DriverApprovalStatusPage.dart';
import 'package:app/Screens/HomeScreen.dart';
import 'package:app/Screens/LoginScreen.dart';
import 'package:app/Screens/RegisterScreen.dart';
import 'package:app/models/Appuser.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'theme/FmsTheme.dart';

/// Runs in a separate background isolate when a push arrives while the app
/// is backgrounded/terminated — must be a top-level function, and must
/// re-initialize Firebase itself since it doesn't share state with the
/// main isolate. The OS already shows the notification itself in this
/// case (this app doesn't need to do anything extra for a simple
/// notification+data payload); this hook exists for future data-only
/// pushes that need custom handling.
@pragma('vm-entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}

/// Lets code without a BuildContext (like the FCM foreground-message
/// listener in PushNotificationSetup) still show a SnackBar/navigate.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'FMS',
      debugShowCheckedModeBanner: false,
      // FMS design system unification (2026-08-24) — was a bare
      // ColorScheme.fromSeed(seedColor: Colors.blueGrey) with no AppBar/
      // button/input themes at all, so any stock Material widget a screen
      // forgot to re-skin fell back to generic blue-grey Material instead
      // of FMS's Navy+Gold identity. See theme/FmsTheme.dart.
      theme: FmsTheme.lightTheme,
      home: const SplashPage(),
    );
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  // 2026-08-20 fix: this screen used to show unconditionally on every cold
  // start ("Welcome Back!" + Log In button) even for someone who was
  // already logged in — LoggingInScreen saves a token/loggedIn flag on
  // success (see its _run()), but nothing ever read it back on app launch,
  // so every user was forced to log in again every single time they
  // reopened the app. This flag gates the marketing UI below behind a
  // quick session check so a returning, still-logged-in user skips
  // straight to their home screen instead.
  bool _checkingSession = true;

  // 2026-08-24 fix: fetchMyProfile() used to have every failure — expired
  // token, weak/no internet, a Render cold-start timeout, a transient 500
  // — funneled into one catch block that cleared the whole session
  // (prefs.clear()). That meant an active driver losing signal mid-trip,
  // or just hitting a slow server, got silently logged out and dropped
  // back to Login — which is exactly what was reported as "the app logs
  // itself out". Only an explicit AuthenticationException (server said
  // 401 — the token itself is invalid) should ever clear the session now;
  // every other failure sets this flag instead and keeps the token intact
  // so the user can just hit Retry — see _checkSession()'s two catch
  // blocks and the offline-retry branch in build().
  bool _sessionCheckFailed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );

    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

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
      final user = AppUser(
        id: profile['id']?.toString() ?? prefs.getString('id') ?? '',
        name: profile['name']?.toString() ?? prefs.getString('name') ?? '',
        email: profile['email']?.toString() ?? prefs.getString('email') ?? '',
        role: role,
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
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                const Text(
                  "Couldn't connect",
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  "You're still signed in — this just couldn't reach the server. Check your connection and try again.",
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
                    label: const Text(
                      'Retry',
                      style: TextStyle(color: Color(0xFF0A0A0C), fontSize: 15, fontWeight: FontWeight.w700),
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

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image (logistics / trucks). Switched 2026-08-18 from
          // a live Unsplash network fetch to a bundled asset (user-provided
          // brand image: truck on a highway with a world-map graphic) so it
          // always loads instantly and works offline.
          Image.asset(
            'assets/images/login_background.jpg',
            fit: BoxFit.cover,
          ),

          // Dark overlay
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x33000000),
                  Color(0x66000000),
                  Color(0xCC000000),
                  Color(0xF0000000),
                ],
                stops: [0.0, 0.3, 0.65, 1.0],
              ),
            ),
          ),

          // Content — matches the agreed "Welcome Screen" design
          // (2026-08-19): centered hexagon truck mark + wordmark, "Welcome
          // Back!" headline, Log In (filled) + Create New Account
          // (outline) stacked buttons, version tag pinned to the bottom.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  FadeTransition(
                    opacity: _fadeIn,
                    child: SlideTransition(
                      position: _slideUp,
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset(
                              'assets/images/fms_logo.png',
                              width: 140,
                              height: 140,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                  FadeTransition(
                    opacity: _fadeIn,
                    child: SlideTransition(
                      position: _slideUp,
                      child: Column(
                        children: [
                          const Text(
                            'Welcome Back!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Sign in to your account to continue managing your shipments.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                                );
                              },
                              icon: const Icon(Icons.login_rounded, size: 18, color: Color(0xFF0A0A0C)),
                              label: const Text(
                                'Log In',
                                style: TextStyle(
                                  color: Color(0xFF0A0A0C),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD4AF37),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const RegisterScreen()),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white30),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text(
                                'Create New Account',
                                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  FadeTransition(
                    opacity: _fadeIn,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'v1.0.0',
                        style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}