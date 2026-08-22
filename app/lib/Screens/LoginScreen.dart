import 'package:flutter/material.dart';

import '../API/config.dart';
import '../l10n/app_localizations.dart';
import 'LoggingInScreen.dart';
import 'RegisterScreen.dart';
import 'register_shared.dart';

/// Combined Welcome + Login screen (2026-08-18 redesign, per user-provided
/// mockup): replaces the old two-step flow where main.dart's SplashPage
/// showed a dark "Welcome Back!" hero with just a "Log In" button that
/// pushed this screen. Now SplashPage renders this screen directly once the
/// session check finishes (see SplashPage.build()) and the email/password
/// form lives right here under the branding — no extra tap needed.
///
/// Light theme, matching the mockup: hero image (world map + road + truck)
/// with the FMS logo overlaid, "Welcome to FMS" headline, a white card with
/// email/password fields + Remember me + Forgot password, a gold Log In
/// button, a 3-item feature strip, and a Sign Up link at the bottom (not in
/// the mockup screenshot itself, presumably below the fold — kept so the
/// registration flow stays reachable).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _rememberMe = true;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = AppLocalizations.of(context)!.errorFillAllFields);
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final error = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => LoggingInScreen(email: email, password: password)),
    );

    // If LoggingInScreen succeeded it already replaced the whole nav stack,
    // so this widget is gone and `mounted` is false — this branch only
    // runs on failure, when it popped back here with an error message.
    if (mounted) {
      setState(() {
        _loading = false;
        if (error != null) _errorMessage = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: LightColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _HeroHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
                child: Column(
                  children: [
                    Text(
                      t.loginWelcomeTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: LightColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t.loginWelcomeSubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: LightColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: LightColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: LightColors.border),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 18, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: Column(
                        children: [
                          buildLightTextField(
                            controller: _emailCtrl,
                            label: t.emailLabel,
                            hint: t.emailHint,
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: const Icon(Icons.mail_outline, color: LightColors.textMuted, size: 20),
                          ),
                          const SizedBox(height: 16),
                          buildLightTextField(
                            controller: _passCtrl,
                            label: t.passwordLabel,
                            hint: t.passwordHint,
                            obscure: _obscure,
                            prefixIcon: const Icon(Icons.lock_outline, color: LightColors.textMuted, size: 20),
                            suffix: IconButton(
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: LightColors.textMuted,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      onChanged: (v) => setState(() => _rememberMe = v ?? true),
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(t.rememberMe, style: const TextStyle(fontSize: 12.5, color: LightColors.textSecondary)),
                                ],
                              ),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(t.forgotPasswordSnack)),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                    child: Text(t.forgotPassword,
                                        style: const TextStyle(fontSize: 12.5, color: LightColors.gold, fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          if (_errorMessage != null) ...[
                            LightErrorBanner(message: _errorMessage!),
                            const SizedBox(height: 12),
                          ],
                          LightPrimaryButton(
                            label: t.logIn,
                            icon: Icons.login_rounded,
                            color: LightColors.gold,
                            textColor: LightColors.textPrimary,
                            loading: _loading,
                            onPressed: _handleLogin,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: _FeatureItem(
                            icon: Icons.verified_user_rounded,
                            title: t.featureSecureTitle,
                            description: t.featureSecureDesc,
                          ),
                        ),
                        Expanded(
                          child: _FeatureItem(
                            icon: Icons.access_time_filled_rounded,
                            title: t.featureEasyTitle,
                            description: t.featureEasyDesc,
                          ),
                        ),
                        Expanded(
                          child: _FeatureItem(
                            icon: Icons.bar_chart_rounded,
                            title: t.featureReportsTitle,
                            description: t.featureReportsDesc,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Center(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                          },
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 13, color: LightColors.textSecondary),
                              children: [
                                TextSpan(text: '${t.authNoAccount} '),
                                TextSpan(
                                  text: t.authSignUp,
                                  style: const TextStyle(color: LightColors.gold, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ClipPath(
                clipper: _BottomCurveClipper(),
                child: Container(height: 46, color: LightColors.deepNavy),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Top banner: bundled world-map/road/truck image with the FMS logo
/// overlaid, fading into the plain page background at the bottom edge so
/// there's no hard seam before the "Welcome to FMS" heading.
class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/login_background.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 80,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, LightColors.bg],
                ),
              ),
            ),
          ),
          Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset('assets/images/fms_logo.png', height: 148, fit: BoxFit.contain),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  const _FeatureItem({required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: LightColors.gold.withOpacity(0.14), shape: BoxShape.circle),
          child: Icon(icon, color: LightColors.goldMuted, size: 22),
        ),
        const SizedBox(height: 8),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: LightColors.textPrimary)),
        const SizedBox(height: 3),
        Text(description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, color: LightColors.textSecondary, height: 1.3)),
      ],
    );
  }
}

/// Subtle navy wave pinned to the very bottom of the screen, echoing the
/// dark curved footer visible at the bottom edge of the mockup.
class _BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.35);
    path.quadraticBezierTo(size.width * 0.5, size.height, size.width, size.height * 0.35);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
