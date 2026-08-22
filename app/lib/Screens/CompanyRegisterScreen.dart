import 'package:flutter/material.dart';

import '../API/AuthResponse.dart';
import '../API/config.dart';
import '../l10n/app_localizations.dart';
import 'OtpVerificationScreen.dart';
import 'register_shared.dart';

/// UC-2, step 1 of 2 (2026-08-29 real backend split): collects just the
/// account fields (name/email/password) and submits them via
/// ApiService.registerAccount(), then goes straight to OtpVerificationScreen
/// — the company cannot reach the rest of registration (company info,
/// license) before OTP succeeds. That remaining data is collected by
/// CompleteCompanyRegistrationScreen, reached only after OtpVerification-
/// Screen routes there on success.
///
/// This used to be a 4-step wizard (Account Info -> Company Information ->
/// Company Documents -> Review & Submit) that submitted everything at the
/// end, with OTP last — a deliberate, documented deviation from the mockup
/// (which wanted OTP right after this step) because splitting it required a
/// real backend change. That backend change (CompanyController::
/// completeRegistration) now exists, so this matches the mockup again:
/// Account Info -> OTP -> rest of the form.
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

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  bool _agreed = false;
  String? _errorMessage;

  PasswordStrength _strength = PasswordStrength.none;
  bool _passwordsMatch = true;

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
    super.dispose();
  }

  bool get _isEmailValid => RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(_emailCtrl.text.trim());

  String? _validate(AppLocalizations t) {
    if (_nameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _passCtrl.text.isEmpty ||
        _confirmCtrl.text.isEmpty) {
      return t.validationFillRequired;
    }
    if (!_isEmailValid) return t.validationInvalidEmail;
    if (_passCtrl.text != _confirmCtrl.text) return t.passwordsDoNotMatch;
    if (!_agreed) return t.validationAgreeTerms;
    return null;
  }

  Future<void> _handleRegister() async {
    final t = AppLocalizations.of(context)!;
    final error = _validate(t);
    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.registerAccount(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        passwordConfirmation: _confirmCtrl.text,
        type: 'company',
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OtpVerificationScreen(email: result.email)),
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: LightColors.textPrimary),
          onPressed: _loading ? null : () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(t.stepAccountInfoTitle,
                        style: const TextStyle(color: LightColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(t.stepAccountInfoSubtitle, style: const TextStyle(color: LightColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 22),
                    buildLightTextField(controller: _nameCtrl, label: t.companyNameLabel, hint: t.companyNameHint),
                    const SizedBox(height: 14),
                    buildLightTextField(
                        controller: _emailCtrl,
                        label: t.emailLabel,
                        hint: t.companyEmailHint,
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 14),
                    buildLightTextField(
                      controller: _passCtrl,
                      label: t.passwordLabel,
                      hint: '••••••••••',
                      obscure: _obscurePass,
                      suffix: IconButton(
                        onPressed: () => setState(() => _obscurePass = !_obscurePass),
                        icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: LightColors.textMuted, size: 18),
                      ),
                    ),
                    if (_strength != PasswordStrength.none) ...[
                      const SizedBox(height: 10),
                      PasswordStrengthBar(strength: _strength),
                    ],
                    const SizedBox(height: 14),
                    buildLightTextField(
                      controller: _confirmCtrl,
                      label: t.confirmPasswordLabel,
                      hint: '••••••••••',
                      obscure: _obscureConfirm,
                      hasError: !_passwordsMatch,
                      suffix: IconButton(
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: LightColors.textMuted, size: 18),
                      ),
                    ),
                    if (!_passwordsMatch) ...[
                      const SizedBox(height: 6),
                      Text(t.passwordsDoNotMatch, style: const TextStyle(fontSize: 11, color: LightColors.error)),
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
                          Expanded(
                            child: Text(
                              t.companyAgreeTerms,
                              style: const TextStyle(fontSize: 13, color: LightColors.textSecondary, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_errorMessage != null) ...[
                    LightErrorBanner(message: _errorMessage!),
                    const SizedBox(height: 12),
                  ],
                  LightPrimaryButton(
                    label: t.commonNext,
                    loading: _loading,
                    onPressed: _handleRegister,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// _ReviewCard, _SubLabel and _NoticeBanner moved to
// CompleteCompanyRegistrationScreen.dart along with the steps that use them
// (company info through review) — see that file.
