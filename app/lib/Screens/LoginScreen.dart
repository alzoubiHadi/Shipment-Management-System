

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../API/AuthResponse.dart';

import '../models/Appuser.dart';
import 'DriverApprovalStatusPage.dart';
import 'ForceChangePasswordScreen.dart';
import 'HomeScreen.dart';
import 'RegisterScreen.dart';

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

    try {
      final response = await ApiService.login(email: email, password: password);
      print(response);

      // A sub-admin logging in for the first time on their one-time
      // temporary password must set a real one before reaching anything
      // else (UC-7) — no token/prefs are saved as "logged in" yet.
      if (response.mustChangePassword) {
        if (mounted) {
          final prefs = await SharedPreferences.getInstance();
          prefs.setString('token', response.token);
          prefs.setString('email', response.email);
          prefs.setString('id', response.userId);
          prefs.setString('name', response.name);
          prefs.setString('role', response.role.toString());
          prefs.setBool('loggedIn', true);

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => ForceChangePasswordScreen(
                user: AppUser(name: response.name, email: response.email, role: response.role, id: response.userId),
              ),
            ),
            (route) => false,
          );
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      prefs.setString('token', response.token);
      prefs.setString('email', response.email);
      prefs.setString('id', response.userId);
      prefs.setString('name', response.name);
      prefs.setString('role', response.role.toString());
      print(response.role.toString());
      prefs.setBool('loggedIn', true);

      if (mounted) {
        // A driver/company whose account isn't approved yet (pending or
        // rejected) must not reach the normal app — send them to the
        // status screen instead, on every login, until an admin approves
        // them.
        final isUnapprovedDriver = response.role == 'driver' &&
            response.driverApprovalStatus != 'approved';
        final isUnapprovedCompany = response.role == 'company' &&
            response.companyApprovalStatus != 'approved';

        // Navigate to home, clearing the Splash/Login/Register screens from
        // the stack entirely so the browser back button can't land back on
        // them (which looked like being logged out).
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => isUnapprovedDriver
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
                    : HomeScreen(user: AppUser(name: response.name, email: email, role: response.role, id: response.userId),),
          ),
          (route) => false,
        );
      }
    } on ApiException catch (e) {
      // OTP only ever belongs to the sign-up flow (DriverRegisterScreen/
      // CompanyRegisterScreen already push OtpVerificationScreen right
      // after a successful registration) — Login must never send the user
      // into an OTP screen, even if the server reports the account isn't
      // verified yet. Just surface it as a plain error instead.
      if (mounted) {
        setState(() => _errorMessage = e.requiresOtpVerification
            ? 'This account has not completed sign-up verification yet. Please finish registering.'
            : e.message);
      }
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
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFFD4AF37),
                  ),
                  child: const Center(
                    child: Text(
                      'U',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                        color: Color(0xFF0A0A0C),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // Headline
              const Text(
                'Welcome\nback.',
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
                'Sign in to continue',
                style: TextStyle(fontSize: 15, color: Color(0xFF6B6660)),
              ),

              const SizedBox(height: 48),

              // Email field
              _buildTextField(
                controller: _emailCtrl,
                label: 'Email address',
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 14),

              // Password field
              _buildTextField(
                controller: _passCtrl,
                label: 'Password',
                obscure: _obscure,
                suffix: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: const Color(0xFF6B6660),
                    size: 18,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Forgot password
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
                      child: Text(
                        'Forgot password?',
                        style: TextStyle(fontSize: 13, color: Color(0xFFD4AF37)),
                      ),
                    ),
                  ),
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

              // Sign in button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    disabledBackgroundColor: const Color(0xFFD4AF37),
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
                      : const Text(
                    'Sign in',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0A0A0C),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Sign up link
              Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B6660)),
                      children: [
                        TextSpan(text: "Don't have an account? "),
                        TextSpan(
                          text: 'Sign up',
                          style: TextStyle(
                            color: Color(0xFFD4AF37),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
                ),
              ),

              const SizedBox(height: 40),


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
        labelStyle: const TextStyle(color: Color(0xFF4A4540), fontSize: 13),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF111113),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2A2520)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2A2520)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD4AF37)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
    );
  }
}