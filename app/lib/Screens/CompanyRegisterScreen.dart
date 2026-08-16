import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../API/AuthResponse.dart';
import '../API/config.dart';
import 'OtpVerificationScreen.dart';
import 'register_shared.dart';

/// UC-2: company self-registration. Rebuilt 2026-08-21 as a 4-step wizard
/// (Account Info → Company Information → Company Documents → Review &
/// Submit) to match the light-theme registration design, light theme
/// styling matching DriverRegisterScreen.
///
/// The full design mockup shows company registration with extra fields
/// this backend doesn't support yet — a structured address (country/
/// emirate/city), trade license number/issuing authority/issue+expiry
/// dates, an authorized contact person, and separate license/memorandum/
/// incorporation/VAT document uploads. Adding all of that is a real
/// backend change (new columns + controller logic), agreed as a
/// follow-up task rather than blocking this pass — for now this wizard
/// just re-splits the fields the backend already accepts (name, email,
/// password, phone, address, one license file) across 4 steps that match
/// the official Company Registration Flow overview (Account Info →
/// Company Information → Company Documents → Review & Submit).
///
/// Same OTP-position deviation as the driver wizard: the mockup shows
/// email OTP verification as its own step before Company Information;
/// this keeps it at the end (after Review & Submit) since splitting
/// account creation into two backend calls is out of scope here too.
class CompanyRegisterScreen extends StatefulWidget {
  const CompanyRegisterScreen({super.key});

  @override
  State<CompanyRegisterScreen> createState() => _CompanyRegisterScreenState();
}

class _CompanyRegisterScreenState extends State<CompanyRegisterScreen> {
  final _pageController = PageController();
  int _step = 0;
  static const int _totalSteps = 4;

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
    _pageController.dispose();
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

  bool get _isEmailValid => RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(_emailCtrl.text.trim());

  String? _validateStep(int step) {
    switch (step) {
      case 0: // Account info
        if (_nameCtrl.text.trim().isEmpty ||
            _emailCtrl.text.trim().isEmpty ||
            _passCtrl.text.isEmpty ||
            _confirmCtrl.text.isEmpty) {
          return 'Please fill in all required fields';
        }
        if (!_isEmailValid) return 'Please enter a valid email address';
        if (_passCtrl.text != _confirmCtrl.text) return 'Passwords do not match';
        if (!_agreed) return 'Please agree to the Terms & Conditions';
        return null;
      case 1: // Company information
        if (_phoneCtrl.text.trim().isEmpty) return 'Please enter your company phone number';
        if (_addressCtrl.text.trim().isEmpty) return 'Please enter your company address';
        return null;
      case 2: // Company documents
        if (_licenseFile?.bytes == null) return 'Please attach your trade license';
        return null;
      default:
        return null;
    }
  }

  void _next() {
    final error = _validateStep(_step);
    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }
    setState(() => _errorMessage = null);
    if (_step == _totalSteps - 1) {
      _handleRegister();
      return;
    }
    setState(() => _step++);
    _pageController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _step--;
      _errorMessage = null;
    });
    _pageController.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _handleRegister() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.register(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        passwordConfirmation: _confirmCtrl.text,
        type: 'company',
        phone: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
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

  static const _stepTitles = [
    'Account Information',
    'Company Information',
    'Company Documents',
    'Review Your Information',
  ];

  static const _stepSubtitles = [
    'Enter your account details',
    'Tell us about your company',
    'All documents are mandatory',
    'Please review all information before submitting',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: LightColors.textPrimary),
          onPressed: _loading ? null : _back,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LightStepProgress(current: _step, total: _totalSteps),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _accountInfoStep(),
                  _companyInfoStep(),
                  _documentsStep(),
                  _reviewStep(),
                ],
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _pageScaffold(int stepIndex, List<Widget> children) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_stepTitles[stepIndex],
              style: const TextStyle(color: LightColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(_stepSubtitles[stepIndex], style: const TextStyle(color: LightColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 22),
          ...children,
        ],
      ),
    );
  }

  Widget _accountInfoStep() {
    return _pageScaffold(0, [
      buildLightTextField(controller: _nameCtrl, label: 'Company Name', hint: 'Global Logistics LLC'),
      const SizedBox(height: 14),
      buildLightTextField(
          controller: _emailCtrl, label: 'Email', hint: 'contact@company.com', keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 14),
      buildLightTextField(
        controller: _passCtrl,
        label: 'Password',
        hint: '••••••••••',
        obscure: _obscurePass,
        suffix: IconButton(
          onPressed: () => setState(() => _obscurePass = !_obscurePass),
          icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: const Color(0xFFA0A4AC), size: 18),
        ),
      ),
      if (_strength != PasswordStrength.none) ...[
        const SizedBox(height: 10),
        PasswordStrengthBar(strength: _strength),
      ],
      const SizedBox(height: 14),
      buildLightTextField(
        controller: _confirmCtrl,
        label: 'Confirm Password',
        hint: '••••••••••',
        obscure: _obscureConfirm,
        hasError: !_passwordsMatch,
        suffix: IconButton(
          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
          icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: const Color(0xFFA0A4AC), size: 18),
        ),
      ),
      if (!_passwordsMatch) ...[
        const SizedBox(height: 6),
        const Text('Passwords do not match', style: TextStyle(fontSize: 11, color: LightColors.error)),
      ],
      const SizedBox(height: 20),
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
                border: Border.all(color: _agreed ? LightColors.gold : LightColors.border, width: 1.5),
                color: _agreed ? LightColors.gold : Colors.transparent,
              ),
              child: _agreed ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'I agree to the Terms & Conditions and Privacy Policy',
                style: TextStyle(fontSize: 13, color: LightColors.textSecondary, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _companyInfoStep() {
    return _pageScaffold(1, [
      buildLightTextField(controller: _phoneCtrl, label: 'Phone Number', hint: '+971 4 123 4567', keyboardType: TextInputType.phone),
      const SizedBox(height: 14),
      buildLightTextField(controller: _addressCtrl, label: 'Company Address', hint: 'Street, city, country', maxLines: 3),
    ]);
  }

  Widget _documentsStep() {
    return _pageScaffold(2, [
      const _SubLabel('Trade License'),
      const SizedBox(height: 8),
      LightPickerField(
        label: 'Upload',
        hint: 'PDF/JPG/PNG',
        value: _licenseFile?.name,
        icon: Icons.upload_file_outlined,
        onTap: _pickLicenseFile,
      ),
      const SizedBox(height: 14),
      const _NoticeBanner('All documents must be clear and valid. Expired documents are not accepted.'),
    ]);
  }

  Widget _reviewStep() {
    return _pageScaffold(3, [
      _ReviewCard(icon: Icons.person_outline, title: 'Account Information', lines: [_nameCtrl.text.trim(), _emailCtrl.text.trim()]),
      const SizedBox(height: 10),
      _ReviewCard(icon: Icons.apartment_outlined, title: 'Company Information', lines: [
        _phoneCtrl.text.trim(),
        _addressCtrl.text.trim(),
      ]),
      const SizedBox(height: 10),
      _ReviewCard(icon: Icons.folder_open_outlined, title: 'Company Documents', lines: [
        _licenseFile != null ? 'Trade license uploaded' : 'No document uploaded',
      ]),
      const SizedBox(height: 16),
      const _NoticeBanner("You won't be able to edit this after submission."),
    ]);
  }

  Widget _bottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_errorMessage != null) ...[
            LightErrorBanner(message: _errorMessage!),
            const SizedBox(height: 12),
          ],
          LightPrimaryButton(
            label: _step == _totalSteps - 1 ? 'Submit for Review' : 'Next',
            loading: _loading,
            onPressed: _next,
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> lines;
  const _ReviewCard({required this.icon, required this.title, required this.lines});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LightColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LightColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: LightColors.goldMuted, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                ...lines.map((l) => Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(l, style: const TextStyle(color: LightColors.textSecondary, fontSize: 12)),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubLabel extends StatelessWidget {
  final String text;
  const _SubLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600));
  }
}

class _NoticeBanner extends StatelessWidget {
  final String text;
  const _NoticeBanner(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: LightColors.pendingBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LightColors.pending.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: LightColors.pending, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11.5, color: Color(0xFF8A6D1F), height: 1.4))),
        ],
      ),
    );
  }
}
