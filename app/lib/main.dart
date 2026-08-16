import 'package:app/Screens/LoginScreen.dart';
import 'package:app/Screens/RegisterScreen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
      ),
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

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Icon(
                              Icons.local_shipping_rounded,
                              color: Color(0xFF0A0A0C),
                              size: 48,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'SHIPMENT',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                            ),
                          ),
                          RichText(
                            textAlign: TextAlign.center,
                            text: const TextSpan(
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                              ),
                              children: [
                                TextSpan(text: 'MANAGEMENT ', style: TextStyle(color: Colors.white70)),
                                TextSpan(text: 'SYSTEM', style: TextStyle(color: Color(0xFFD4AF37))),
                              ],
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