import 'package:flutter/material.dart';

import '../API/AuthResponse.dart';
import '../API/config.dart';
import '../models/Appuser.dart';
import 'HomeScreen.dart';

/// UC-7: shown right after a sub-admin's first login on a one-time
/// temporary password (users.must_change_password == true). They cannot
/// reach any other screen until they set a real password.
class ForceChangePasswordScreen extends StatefulWidget {
  final AppUser user;

  const ForceChangePasswordScreen({super.key, required this.user});

  @override
  State<ForceChangePasswordScreen> createState() => _ForceChangePasswordScreenState();
}

class _ForceChangePasswordScreenState extends State<ForceChangePasswordScreen> {
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

  Future<void> _handleSubmit() async {
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }
    if (_currentCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields');
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
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen(user: widget.user)),
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
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Set a new\npassword.',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w300,
                  color: AppColors.cream,
                  height: 1.1,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'For security, you must set your own password before continuing.',
                style: TextStyle(fontSize: 14, color: AppColors.muted),
              ),
              const SizedBox(height: 32),
              _field(_currentCtrl, 'Temporary password'),
              const SizedBox(height: 14),
              _field(_passCtrl, 'New password'),
              const SizedBox(height: 6),
              const Text(
                'Minimum 8 characters, upper & lower case, a number and a symbol.',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              _field(_confirmCtrl, 'Confirm new password'),
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(_errorMessage!,
                    style: const TextStyle(fontSize: 13, color: Color(0xFFE57373))),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A0A0C)))
                      : const Text('Update password',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0A0A0C))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      obscureText: true,
      style: const TextStyle(color: AppColors.cream, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF4A4540), fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF111113),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2A2520)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
    );
  }
}
