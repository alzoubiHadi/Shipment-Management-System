
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../API/AuthResponse.dart';
import '../models/Appuser.dart';
import 'DriverApprovalStatusPage.dart';
import 'HomeScreen.dart';

// ─── Password Strength ────────────────────────────────────────────────────────

enum PasswordStrength { none, weak, fair, strong }

PasswordStrength _evaluate(String p) {
  if (p.isEmpty) return PasswordStrength.none;
  int score = 0;
  if (p.length >= 8) score++;
  if (p.length >= 12) score++;
  if (RegExp(r'[A-Z]').hasMatch(p)) score++;
  if (RegExp(r'[0-9]').hasMatch(p)) score++;
  if (RegExp(r'[!@#\$&*~%^]').hasMatch(p)) score++;
  if (score <= 1) return PasswordStrength.weak;
  if (score <= 3) return PasswordStrength.fair;
  return PasswordStrength.strong;
}

// ─── Register Screen ──────────────────────────────────────────────────────────

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _driverLicenseCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  bool _agreed = false;
  // The one checkbox that decides internal vs. external: is this driver's
  // truck already registered under Albatrans' own fleet?
  bool _isAlbatransFleet = false;
  String? _errorMessage;

  PasswordStrength _strength = PasswordStrength.none;
  bool _passwordsMatch = true;

  @override
  void initState() {
    super.initState();
    _passCtrl.addListener(() {
      setState(() {
        _strength = _evaluate(_passCtrl.text);
        _passwordsMatch =
            _confirmCtrl.text.isEmpty || _passCtrl.text == _confirmCtrl.text;
      });
    });
    _confirmCtrl.addListener(() {
      setState(() {
        _passwordsMatch =
            _confirmCtrl.text.isEmpty || _passCtrl.text == _confirmCtrl.text;
      });
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _phoneCtrl.dispose();
    _driverLicenseCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_agreed) return;

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    final confirm = _confirmCtrl.text;
    final phone = _phoneCtrl.text.trim();
    final driverLicense = _driverLicenseCtrl.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        driverLicense.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields');
      return;
    }

    if (password != confirm) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.register(
        name: name,
        email: email,
        password: password,
        phone: phone,
        driverLicense: driverLicense,
        isAlbatransFleet: _isAlbatransFleet,
      );

      final prefs = await SharedPreferences.getInstance();
      prefs.setString('token', response.token);
      prefs.setString('email', response.email);
      prefs.setString('id', response.userId);
      prefs.setString('name', response.name);
      prefs.setString('role', response.role.toString());
      prefs.setBool('loggedIn', true);

      if (mounted) {
        // Every self-registered driver starts out 'pending' — send them to
        // the status screen instead of straight into the app, since there's
        // nothing for them to do yet until an admin approves them.
        final isUnapprovedDriver = response.role == 'driver' &&
            response.driverApprovalStatus != 'approved';

        // Clear Splash/Login/Register from the stack entirely so the
        // browser back button can't land back on them.
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => isUnapprovedDriver
                ? DriverApprovalStatusPage(
                    approvalStatus: response.driverApprovalStatus,
                    rejectionReason: response.driverRejectionReason,
                    documentIssues: response.driverDocumentIssues,
                  )
                : HomeScreen(
                    user: AppUser(
                      name: response.name,
                      email: email,
                      role: response.role,
                      id: response.userId,
                    ),
                  ),
          ),
          (route) => false,
        );
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFFD4AF37),
                  ),
                  child: const Center(
                    child: Text(
                      'U',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w300,
                        color: Color(0xFF0A0A0C),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 44),

              // Headline
              const Text(
                'Create your\naccount.',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w300,
                  color: Color(0xFFF5F0E8),
                  height: 1.1,
                  letterSpacing: -1,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Join us — it only takes a moment',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B6660)),
              ),

              const SizedBox(height: 44),

              // Fields
              _buildTextField(controller: _nameCtrl, label: 'Full name'),
              const SizedBox(height: 14),
              _buildTextField(
                controller: _emailCtrl,
                label: 'Email address',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              _buildTextField(
                controller: _passCtrl,
                label: 'Password',
                obscure: _obscurePass,
                suffix: IconButton(
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  icon: Icon(
                    _obscurePass
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF6B6660),
                    size: 18,
                  ),
                ),
              ),

              // Strength bar
              if (_strength != PasswordStrength.none) ...[
                const SizedBox(height: 10),
                _StrengthBar(strength: _strength),
              ],

              const SizedBox(height: 14),

              _buildTextField(
                controller: _confirmCtrl,
                label: 'Confirm password',
                obscure: _obscureConfirm,
                hasError: !_passwordsMatch,
                suffix: IconButton(
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF6B6660),
                    size: 18,
                  ),
                ),
              ),

              if (!_passwordsMatch) ...[
                const SizedBox(height: 6),
                const Text(
                  'Passwords do not match',
                  style: TextStyle(fontSize: 11, color: Color(0xFFE57373)),
                ),
              ],

              const SizedBox(height: 14),

              _buildTextField(
                controller: _phoneCtrl,
                label: 'Phone number',
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 14),

              _buildTextField(
                controller: _driverLicenseCtrl,
                label: 'Driver license number',
              ),

              const SizedBox(height: 22),

              // Internal vs. external — the only thing that separates the
              // two: is this truck already part of Albatrans' own fleet?
              GestureDetector(
                onTap: () =>
                    setState(() => _isAlbatransFleet = !_isAlbatransFleet),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _isAlbatransFleet
                              ? const Color(0xFFD4AF37)
                              : const Color(0xFF3A3530),
                          width: 1.5,
                        ),
                        color: _isAlbatransFleet
                            ? const Color(0xFFD4AF37)
                            : Colors.transparent,
                      ),
                      child: _isAlbatransFleet
                          ? const Icon(Icons.check,
                              size: 13, color: Color(0xFF0A0A0C))
                          : null,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'My truck is registered under Albatrans’ own fleet',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B6660),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Terms checkbox
              GestureDetector(
                onTap: () => setState(() => _agreed = !_agreed),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _agreed
                              ? const Color(0xFFD4AF37)
                              : const Color(0xFF3A3530),
                          width: 1.5,
                        ),
                        color: _agreed
                            ? const Color(0xFFD4AF37)
                            : Colors.transparent,
                      ),
                      child: _agreed
                          ? const Icon(Icons.check,
                          size: 13, color: Color(0xFF0A0A0C))
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B6660),
                              height: 1.5),
                          children: [
                            TextSpan(text: 'I agree to the '),
                            TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(color: Color(0xFFD4AF37)),
                            ),
                            TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(color: Color(0xFFD4AF37)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Inside the Column, just above the sign in button:

              if (_errorMessage != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A0F0F),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE57373).withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFE57373), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 13, color: Color(0xFFE57373)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Register button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_agreed && !_loading) ? _handleRegister : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    disabledBackgroundColor: const Color(0xFF1E1C18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF0A0A0C),
                    ),
                  )
                      : Text(
                    'Create account',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _agreed
                          ? const Color(0xFF0A0A0C)
                          : const Color(0xFF4A4540),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Sign in link
              Center(
                child: RichText(
                  text: TextSpan(
                    style:
                    const TextStyle(fontSize: 14, color: Color(0xFF6B6660)),
                    children: [
                      const TextSpan(text: 'Already have an account? '),
                      TextSpan(
                        text: 'Sign in',
                        style: const TextStyle(color: Color(0xFFD4AF37)),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    bool hasError = false,
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Color(0xFFF5F0E8), fontSize: 15),
      cursorColor: const Color(0xFFD4AF37),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: hasError ? const Color(0xFFE57373) : const Color(0xFF4A4540),
          fontSize: 13,
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF111113),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2A2520)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: hasError ? const Color(0xFFE57373) : const Color(0xFF2A2520),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: hasError ? const Color(0xFFE57373) : const Color(0xFFD4AF37),
          ),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
    );
  }
}

// ─── Password Strength Bar ────────────────────────────────────────────────────

class _StrengthBar extends StatelessWidget {
  final PasswordStrength strength;
  const _StrengthBar({required this.strength});

  Color get _color => switch (strength) {
    PasswordStrength.weak => const Color(0xFFE57373),
    PasswordStrength.fair => const Color(0xFFFFB74D),
    PasswordStrength.strong => const Color(0xFF81C784),
    _ => Colors.transparent,
  };

  String get _label => switch (strength) {
    PasswordStrength.weak => 'Weak',
    PasswordStrength.fair => 'Fair',
    PasswordStrength.strong => 'Strong',
    _ => '',
  };

  int get _filled => switch (strength) {
    PasswordStrength.weak => 1,
    PasswordStrength.fair => 2,
    PasswordStrength.strong => 3,
    _ => 0,
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...List.generate(3, (i) => Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 3,
            margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: i < _filled ? _color : const Color(0xFF2A2520),
            ),
          ),
        )),
        const SizedBox(width: 10),
        Text(_label, style: TextStyle(fontSize: 11, color: _color)),
      ],
    );
  }
}