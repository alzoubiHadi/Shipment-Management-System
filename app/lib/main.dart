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
  /// was issued) and to double as a token-validity check — an expired or
  /// revoked token throws here, and that's treated as "not logged in".
  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool('loggedIn') ?? false;
    final token = prefs.getString('token');

    if (!loggedIn || token == null || token.isEmpty) {
      _showWelcomeUi();
      return;
    }

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
    } catch (_) {
      // Expired/revoked token, or no network on a cold start — fall back to
      // a normal manual login rather than getting stuck on a blank screen.
      await prefs.clear();
      _showWelcomeUi();
    }
  }

  void _showWelcomeUi() {
    if (!mounted) return;
    setState(() => _checkingSession = false);
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

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image (logistics / trucks)
          Image.network(
            'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?w=1200&q=80',
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(color: const Color(0xFF0D0D0D));
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1a1a2e),
                      Color(0xFF16213e),
                      Color(0xFF0f3460)
                    ],
                  ),
                ),
              );
            },
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