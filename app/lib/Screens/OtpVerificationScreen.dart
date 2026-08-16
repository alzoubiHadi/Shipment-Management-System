import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../API/AuthResponse.dart';
import '../API/config.dart';
import '../models/Appuser.dart';
import 'DriverApprovalStatusPage.dart';
import 'HomeScreen.dart';

/// UC-4: shown right after register() to collect the 6-digit email OTP
/// code. Verification is what actually issues the API token — registration
/// itself no longer does.
class OtpVerificationScreen extends StatefulWidget {
  final String email;

  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  bool _resending = false;
  String? _errorMessage;
  String? _infoMessage;
  int _resendCooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 30);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCooldown <= 1) {
        t.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  Future<void> _handleVerify() async {
    final code = _codeCtrl.text.trim();
    if (code.length < 4) {
      setState(() => _errorMessage = 'Enter the code we emailed you');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final response =
          await ApiService.verifyOtp(email: widget.email, otpCode: code);

      final prefs = await SharedPreferences.getInstance();
      prefs.setString('token', response.token);
      prefs.setString('email', response.email);
      prefs.setString('id', response.userId);
      prefs.setString('name', response.name);
      prefs.setString('role', response.role.toString());
      prefs.setBool('loggedIn', true);

      if (!mounted) return;

      final isUnapprovedDriver =
          response.role == 'driver' && response.driverApprovalStatus != 'approved';
      final isUnapprovedCompany =
          response.role == 'company' && response.companyApprovalStatus != 'approved';

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
                  : HomeScreen(
                      user: AppUser(
                        name: response.name,
                        email: response.email,
                        role: response.role,
                        id: response.userId,
                      ),
                    ),
        ),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleResend() async {
    setState(() {
      _resending = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      await ApiService.resendOtp(email: widget.email);
      if (mounted) {
        setState(() => _infoMessage = 'A new code has been sent to ${widget.email}');
        _startCooldown();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: const Color(0xFFD4AF37).withOpacity(0.12),
                  ),
                  child: const Icon(Icons.mark_email_read_outlined,
                      color: Color(0xFFD4AF37), size: 32),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Verify your\nemail.',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w300,
                  color: AppColors.cream,
                  height: 1.1,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'We sent a 6-digit code to ${widget.email}',
                style: const TextStyle(fontSize: 14, color: AppColors.muted),
              ),
              const SizedBox(height: 36),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(
                  color: AppColors.cream,
                  fontSize: 24,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  counterText: '',
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(_errorMessage!,
                    style: const TextStyle(fontSize: 13, color: Color(0xFFE57373))),
              ],
              if (_infoMessage != null) ...[
                const SizedBox(height: 14),
                Text(_infoMessage!,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF81C784))),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _handleVerify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF0A0A0C)))
                      : const Text('Verify',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0A0A0C))),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: (_resending || _resendCooldown > 0) ? null : _handleResend,
                  child: Text(
                    _resendCooldown > 0
                        ? 'Resend code in ${_resendCooldown}s'
                        : 'Resend code',
                    style: const TextStyle(color: Color(0xFFD4AF37)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
