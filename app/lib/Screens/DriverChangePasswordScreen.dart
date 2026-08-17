import 'package:flutter/material.dart';

import '../API/AuthResponse.dart';
import '../API/config.dart';

/// Driver Phase 5 (2026-08-20): "Change Password", dark-themed. Reuses the
/// same ApiService.changePassword() call as CompanyChangePasswordScreen /
/// ForceChangePasswordScreen — previously only wired to the mandatory
/// first-login flow, now exposed here for a driver to change it any time.
class DriverChangePasswordScreen extends StatefulWidget {
  const DriverChangePasswordScreen({super.key});

  @override
  State<DriverChangePasswordScreen> createState() => _DriverChangePasswordScreenState();
}

class _DriverChangePasswordScreenState extends State<DriverChangePasswordScreen> {
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

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: LightColors.muted, fontSize: 13),
      filled: true,
      fillColor: LightColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LightColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LightColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LightColors.gold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: LightColors.cream),
        title: const Text('Change Password', style: TextStyle(color: LightColors.cream)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(controller: _currentCtrl, obscureText: true, style: const TextStyle(color: LightColors.cream), decoration: _decoration('Current Password')),
            const SizedBox(height: 14),
            TextFormField(controller: _passCtrl, obscureText: true, style: const TextStyle(color: LightColors.cream), decoration: _decoration('New Password')),
            const SizedBox(height: 6),
            const Text('Minimum 8 characters, upper & lower case, a number and a symbol.',
                style: TextStyle(fontSize: 11, color: LightColors.muted)),
            const SizedBox(height: 14),
            TextFormField(controller: _confirmCtrl, obscureText: true, style: const TextStyle(color: LightColors.cream), decoration: _decoration('Confirm New Password')),
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LightColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: LightColors.error.withOpacity(0.4)),
                ),
                child: Text(_errorMessage!, style: const TextStyle(color: LightColors.error, fontSize: 13)),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: LightColors.gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: LightColors.deepNavy))
                    : const Text('Update Password', style: TextStyle(color: LightColors.deepNavy, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
