import 'package:flutter/material.dart';

import '../API/config.dart';
import 'LoggingInScreen.dart';
import 'RegisterScreen.dart';
import 'register_shared.dart';

/// Login-design screen 2 ("Log In"). Light theme, matching the mockup:
/// white background, back arrow, black bold heading, email/password
/// fields with icons, gold "Forgot password?" link, gold "Log In" button,
/// gold "Sign Up" link. The actual API call and all of the post-login
/// routing now lives in LoggingInScreen (design screen 3, "Logging you
/// in...").
///
/// No Google/Apple sign-in here (2026-08-21: removed on request — not
/// wired up and not wanted right now). Re-add later behind the same
/// "coming soon" pattern once there's an actual backend for it (see task
/// #51/#52).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
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
      setState(() => _errorMessage = 'Please fill in all fields');
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
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: LightColors.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Log In',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: LightColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Welcome back! Please enter your credentials to access your account.',
                style: TextStyle(fontSize: 13, color: LightColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 28),
              buildLightTextField(
                controller: _emailCtrl,
                label: 'Email',
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.mail_outline, color: Color(0xFFA0A4AC), size: 20),
              ),
              const SizedBox(height: 16),
              buildLightTextField(
                controller: _passCtrl,
                label: 'Password',
                hint: '••••••••••',
                obscure: _obscure,
                prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFA0A4AC), size: 20),
                suffix: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: const Color(0xFFA0A4AC),
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Contact your admin to reset your password')),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Text('Forgot Password?', style: TextStyle(fontSize: 13, color: LightColors.gold, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_errorMessage != null) ...[
                LightErrorBanner(message: _errorMessage!),
                const SizedBox(height: 12),
              ],
              LightPrimaryButton(
                label: 'Log In',
                icon: Icons.login_rounded,
                color: LightColors.gold,
                textColor: LightColors.textPrimary,
                loading: _loading,
                onPressed: _handleLogin,
              ),
              const SizedBox(height: 24),
              Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                    },
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(fontSize: 14, color: LightColors.textSecondary),
                        children: [
                          TextSpan(text: "Don't have an account? "),
                          TextSpan(
                            text: 'Sign Up',
                            style: TextStyle(color: LightColors.gold, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
