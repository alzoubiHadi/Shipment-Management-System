import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../API/AuthResponse.dart';
import 'OtpVerificationScreen.dart';
import 'register_shared.dart';

/// UC-2: company self-registration. Split out of the old combined
/// RegisterScreen so the driver form (much longer, two sections) doesn't
/// have to share a screen with this simpler one.
class CompanyRegisterScreen extends StatefulWidget {
  const CompanyRegisterScreen({super.key});

  @override
  State<CompanyRegisterScreen> createState() => _CompanyRegisterScreenState();
}

class _CompanyRegisterScreenState extends State<CompanyRegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  bool _agreed = false;
  String? _errorMessage;

  PasswordStrength _strength = PasswordStrength.none;
  bool _passwordsMatch = true;

  PlatformFile? _licenseFile;

  @override
  void initState() {
    super.initState();
    _passCtrl.addListener(() {
      setState(() {
        _strength = evaluatePasswordStrength(_passCtrl.text);
        _passwordsMatch = _confirmCtrl.text.isEmpty || _passCtrl.text == _confirmCtrl.text;
      });
    });
    _confirmCtrl.addListener(() {
      setState(() {
        _passwordsMatch = _confirmCtrl.text.isEmpty || _passCtrl.text == _confirmCtrl.text;
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
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLicenseFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _licenseFile = result.files.single);
    }
  }

  Future<void> _handleRegister() async {
    if (!_agreed) return;

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    final confirm = _confirmCtrl.text;
    final phone = _phoneCtrl.text.trim();
    final address = _addressCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields');
      return;
    }

    if (password != confirm) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    if (_licenseFile == null || _licenseFile!.bytes == null) {
      setState(() => _errorMessage = 'Please attach the company trade license');
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
        type: 'company',
        phone: phone,
        address: address,
        licenseFileBytes: _licenseFile?.bytes,
        licenseFileName: _licenseFile?.name,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OtpVerificationScreen(email: result.email)),
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0C),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFF5F0E8)),
        title: const Text('Company Sign Up', style: TextStyle(color: Color(0xFFF5F0E8))),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildAuthTextField(controller: _nameCtrl, label: 'Company name'),
              const SizedBox(height: 14),
              buildAuthTextField(
                controller: _emailCtrl,
                label: 'Email address',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              buildAuthTextField(
                controller: _passCtrl,
                label: 'Password',
                obscure: _obscurePass,
                suffix: IconButton(
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  icon: Icon(
                    _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: const Color(0xFF6B6660),
                    size: 18,
                  ),
                ),
              ),
              if (_strength != PasswordStrength.none) ...[
                const SizedBox(height: 10),
                PasswordStrengthBar(strength: _strength),
              ],
              const SizedBox(height: 14),
              buildAuthTextField(
                controller: _confirmCtrl,
                label: 'Confirm password',
                obscure: _obscureConfirm,
                hasError: !_passwordsMatch,
                suffix: IconButton(
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: const Color(0xFF6B6660),
                    size: 18,
                  ),
                ),
              ),
              if (!_passwordsMatch) ...[
                const SizedBox(height: 6),
                const Text('Passwords do not match', style: TextStyle(fontSize: 11, color: Color(0xFFE57373))),
              ],
              const SizedBox(height: 14),
              buildAuthTextField(
                controller: _phoneCtrl,
                label: 'Phone number',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),
              buildAuthTextField(controller: _addressCtrl, label: 'Company address (incl. country)'),
              const SizedBox(height: 14),
              PickerField(
                label: 'Attach trade license (PDF/JPG/PNG)',
                value: _licenseFile?.name,
                icon: Icons.upload_file_outlined,
                onTap: _pickLicenseFile,
              ),
              const SizedBox(height: 22),
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
                          color: _agreed ? const Color(0xFFD4AF37) : const Color(0xFF3A3530),
                          width: 1.5,
                        ),
                        color: _agreed ? const Color(0xFFD4AF37) : Colors.transparent,
                      ),
                      child: _agreed ? const Icon(Icons.check, size: 13, color: Color(0xFF0A0A0C)) : null,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'I agree to the Terms of Service and Privacy Policy',
                        style: TextStyle(fontSize: 13, color: Color(0xFF6B6660), height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null) ...[
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
                        child: Text(_errorMessage!, style: const TextStyle(fontSize: 13, color: Color(0xFFE57373))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_agreed && !_loading) ? _handleRegister : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    disabledBackgroundColor: const Color(0xFF1E1C18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A0A0C)),
                        )
                      : Text(
                          'Create account',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _agreed ? const Color(0xFF0A0A0C) : const Color(0xFF4A4540),
                          ),
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
}
