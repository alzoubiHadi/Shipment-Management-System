import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../API/AuthResponse.dart';
import '../API/config.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../utils/countries.dart';
import 'DriverApprovalStatusPage.dart';
import 'register_shared.dart';

/// UC-2, step 2 of 2 (2026-08-29 real backend split): everything that used
/// to be steps 2-4 of CompanyRegisterScreen's wizard — company information,
/// company documents, review — now its own screen, reached only after
/// CompanyRegisterScreen (account info) and OTP verification both succeed.
/// Submits via ApiService.completeCompanyRegistration(), which creates the
/// actual Company row the old one-shot register() call used to create.
///
/// The caller (OtpVerificationScreen) is responsible for only ever reaching
/// this screen with a valid Sanctum token already stored — the request
/// below is authenticated.
class CompleteCompanyRegistrationScreen extends StatefulWidget {
  const CompleteCompanyRegistrationScreen({super.key});

  @override
  State<CompleteCompanyRegistrationScreen> createState() => _CompleteCompanyRegistrationScreenState();
}

class _CompleteCompanyRegistrationScreenState extends State<CompleteCompanyRegistrationScreen> {
  final _pageController = PageController();
  int _step = 0;
  static const int _totalSteps = 3;

  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  CountryInfo _phoneCountry = defaultPhoneCountry;

  bool _loading = false;
  String? _errorMessage;

  PlatformFile? _licenseFile;

  @override
  void dispose() {
    _pageController.dispose();
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

  String? _validateStep(int step) {
    final t = AppLocalizations.of(context)!;
    switch (step) {
      case 0: // Company information
        if (!isValidLocalPhoneNumber(_phoneCtrl.text.trim())) return t.validationCompanyPhone;
        if (_addressCtrl.text.trim().isEmpty) return t.validationCompanyAddress;
        return null;
      case 1: // Company documents
        if (_licenseFile?.bytes == null) return t.validationAttachLicense;
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
      _handleSubmit();
      return;
    }
    setState(() => _step++);
    _pageController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  /// See CompleteDriverRegistrationScreen._logout()'s comment — this screen
  /// has no back target from its first page, so it gets its own explicit
  /// "Log out" action instead of leaving the user stuck.
  Future<void> _logout() async {
    // 2026-08-29 (audit item 9): revoke the token server-side too, not just
    // locally — silent on failure by design, see ApiService.logout().
    await ApiService.logout();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SplashPage()),
        (route) => false,
      );
    }
  }

  void _back() {
    if (_step == 0) {
      // See _logout()'s comment — no back target from here.
      return;
    }
    setState(() {
      _step--;
      _errorMessage = null;
    });
    _pageController.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await ApiService.completeCompanyRegistration(
        phone: combinePhoneNumber(_phoneCountry, _phoneCtrl.text.trim()),
        address: _addressCtrl.text.trim(),
        licenseFileBytes: _licenseFile!.bytes!,
        licenseFileName: _licenseFile!.name,
      );

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const DriverApprovalStatusPage(approvalStatus: 'pending', accountType: 'company'),
          ),
          (route) => false,
        );
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = AppLocalizations.of(context)!.errorSubmitGeneric(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> _stepTitles(AppLocalizations t) => [
        t.companyRegStepCompanyTitle,
        t.companyRegStepDocumentsTitle,
        t.stepReviewTitle,
      ];

  List<String> _stepSubtitles(AppLocalizations t) => [
        t.companyRegStepCompanySubtitle,
        t.companyRegStepDocumentsSubtitle,
        t.stepReviewSubtitle,
      ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: LightColors.bg,
        appBar: AppBar(
          backgroundColor: LightColors.bg,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: _step == 0
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back, color: LightColors.textPrimary),
                  onPressed: _loading ? null : _back,
                ),
          actions: [
            TextButton(
              onPressed: _loading ? null : _logout,
              child: const Text('Log Out', style: TextStyle(color: LightColors.textSecondary, fontSize: 13)),
            ),
          ],
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
                    _companyInfoStep(context),
                    _documentsStep(context),
                    _reviewStep(context),
                  ],
                ),
              ),
              _bottomBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pageScaffold(BuildContext context, int stepIndex, List<Widget> children) {
    final t = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_stepTitles(t)[stepIndex],
              style: const TextStyle(color: LightColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(_stepSubtitles(t)[stepIndex], style: const TextStyle(color: LightColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 22),
          ...children,
        ],
      ),
    );
  }

  Widget _companyInfoStep(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return _pageScaffold(context, 0, [
      PhoneNumberField(
        country: _phoneCountry,
        onCountryChanged: (c) => setState(() => _phoneCountry = c),
        numberController: _phoneCtrl,
      ),
      const SizedBox(height: 14),
      buildLightTextField(controller: _addressCtrl, label: t.companyAddressLabel, hint: t.companyAddressHint, maxLines: 3),
    ]);
  }

  Widget _documentsStep(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return _pageScaffold(context, 1, [
      _SubLabel(t.tradeLicenseLabel),
      const SizedBox(height: 8),
      LightPickerField(
        label: t.commonUpload,
        hint: t.commonUploadHintFormats,
        value: _licenseFile?.name,
        icon: Icons.upload_file_outlined,
        onTap: _pickLicenseFile,
      ),
      const SizedBox(height: 14),
      _NoticeBanner(t.documentsNotice),
    ]);
  }

  Widget _reviewStep(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return _pageScaffold(context, 2, [
      _ReviewCard(icon: Icons.apartment_outlined, title: t.reviewCompanyInfoTitle, lines: [
        combinePhoneNumber(_phoneCountry, _phoneCtrl.text.trim()),
        _addressCtrl.text.trim(),
      ]),
      const SizedBox(height: 10),
      _ReviewCard(icon: Icons.folder_open_outlined, title: t.companyRegStepDocumentsTitle, lines: [
        _licenseFile != null ? t.tradeLicenseUploaded : t.noDocumentUploaded,
      ]),
      const SizedBox(height: 16),
      _NoticeBanner(t.reviewCannotEditNotice),
    ]);
  }

  Widget _bottomBar(BuildContext context) {
    final t = AppLocalizations.of(context)!;
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
            label: _step == _totalSteps - 1 ? t.submitForReview : t.commonNext,
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
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11.5, color: LightColors.noteText, height: 1.4))),
        ],
      ),
    );
  }
}
