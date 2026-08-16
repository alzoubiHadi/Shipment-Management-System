
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../API/AuthResponse.dart';
import 'OtpVerificationScreen.dart';

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
  final _addressCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  bool _agreed = false;
  // Every driver is an independent operator now — there is no more
  // "internal Albatrans fleet" distinction. The only choice left at
  // sign-up is which kind of account this is.
  String _accountType = 'driver'; // 'driver' or 'company'
  String? _errorMessage;

  // Company trade/commercial license file (required for company sign-up).
  PlatformFile? _licenseFile;

  Future<void> _pickLicenseFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true, // required for Flutter Web — no filesystem path there
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() => _licenseFile = result.files.single);
    }
  }

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
    _addressCtrl.dispose();
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
    final address = _addressCtrl.text.trim();

    final missingRequiredField = name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        (_accountType == 'driver' && driverLicense.isEmpty);

    if (missingRequiredField) {
      setState(() => _errorMessage = 'Please fill in all fields');
      return;
    }

    if (_accountType == 'company' &&
        (_licenseFile == null || _licenseFile!.bytes == null)) {
      setState(() => _errorMessage = 'Please attach the company trade license');
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
      final result = await ApiService.register(
        name: name,
        email: email,
        password: password,
        passwordConfirmation: confirm,
        type: _accountType,
        phone: phone,
        driverLicense: _accountType == 'driver' ? driverLicense : null,
        address: _accountType == 'company' ? address : null,
        licenseFileBytes: _accountType == 'company' ? _licenseFile?.bytes : null,
        licenseFileName: _accountType == 'company' ? _licenseFile?.name : null,
      );

      if (mounted) {
        // Registration no longer logs the user in directly — the email
        // must be verified with the OTP code we just sent (UC-4) before an
        // access token is issued.
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(email: result.email),
          ),
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

              const SizedBox(height: 32),

              // Account type — driver or company. Every driver is now an
              // independent operator (no internal/external fleet split).
              Row(
                children: [
                  Expanded(child: _TypeChip(
                    label: 'Driver',
                    selected: _accountType == 'driver',
                    onTap: () => setState(() => _accountType = 'driver'),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _TypeChip(
                    label: 'Company',
                    selected: _accountType == 'company',
                    onTap: () => setState(() => _accountType = 'company'),
                  )),
                ],
              ),

              const SizedBox(height: 24),

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

              if (_accountType == 'driver') ...[
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _driverLicenseCtrl,
                  label: 'Driver license number',
                ),
              ],

              if (_accountType == 'company') ...[
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _addressCtrl,
                  label: 'Company address',
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _pickLicenseFile,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111113),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _licenseFile == null
                            ? const Color(0xFF2A2520)
                            : const Color(0xFFD4AF37),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _licenseFile == null
                              ? Icons.upload_file_outlined
                              : Icons.check_circle_outline,
                          color: _licenseFile == null
                              ? const Color(0xFF6B6660)
                              : const Color(0xFFD4AF37),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _licenseFile?.name ?? 'Attach trade license (PDF/JPG/PNG)',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _licenseFile == null
                                  ? const Color(0xFF6B6660)
                                  : const Color(0xFFF5F0E8),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

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

// ─── Account Type Chip ─────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? const Color(0xFFD4AF37) : const Color(0xFF111113),
          border: Border.all(
            color: selected ? const Color(0xFFD4AF37) : const Color(0xFF2A2520),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFF0A0A0C) : const Color(0xFF6B6660),
          ),
        ),
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