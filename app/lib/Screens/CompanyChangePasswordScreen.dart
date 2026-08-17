import 'package:flutter/material.dart';

import '../API/AuthResponse.dart';
import '../API/config.dart';
import 'register_shared.dart';

/// Self-service password change (Company Profile → Change Password),
/// light-themed. Reuses the same ApiService.changePassword() call
/// ForceChangePasswordScreen uses for the mandatory first-login flow —
/// that endpoint isn't gated to "forced" changes, just not previously
/// exposed anywhere else in the app.
class CompanyChangePasswordScreen extends StatefulWidget {
  const CompanyChangePasswordScreen({super.key});

  @override
  State<CompanyChangePasswordScreen> createState() => _CompanyChangePasswordScreenState();
}

class _CompanyChangePasswordScreenState extends State<CompanyChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_currentCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields');
      return;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await ApiService.changePassword(
        currentPassword: _currentCtrl.text,
        password: _passCtrl.text,
        passwordConfirmation: _confirmCtrl.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated'), backgroundColor: LightColors.success),
        );
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
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
        title: const Text('Change Password', style: TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            buildLightTextField(controller: _currentCtrl, label: 'Current Password', obscure: true),
            const SizedBox(height: 14),
            buildLightTextField(controller: _passCtrl, label: 'New Password', obscure: true),
            const SizedBox(height: 6),
            const Text('Minimum 8 characters, upper & lower case, a number and a symbol.',
                style: TextStyle(fontSize: 11, color: LightColors.textSecondary)),
            const SizedBox(height: 14),
            buildLightTextField(controller: _confirmCtrl, label: 'Confirm New Password', obscure: true),
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              LightErrorBanner(message: _errorMessage!),
            ],
            const SizedBox(height: 24),
            LightPrimaryButton(label: 'Update Password', loading: _loading, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
