import 'package:flutter/material.dart';

import '../API/ProfileService.dart';
import '../API/config.dart';
import '../models/Appuser.dart';
import '../utils/countries.dart';
import 'register_shared.dart';

/// Driver Phase 5 (2026-08-20): "Personal Information" — edits the same
/// name/phone/email fields ProfileService.updateBasic() already applies
/// immediately for every role (see ProfileController::updateBasic()).
class DriverPersonalInfoPage extends StatefulWidget {
  final AppUser user;
  const DriverPersonalInfoPage({super.key, required this.user});

  @override
  State<DriverPersonalInfoPage> createState() => _DriverPersonalInfoPageState();
}

class _DriverPersonalInfoPageState extends State<DriverPersonalInfoPage> {
  final _service = ProfileService();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  // 2026-08-28: phone editing now uses the same country-code-picker +
  // national-number split as registration (PhoneNumberField) — was a
  // single free-text field, which meant a phone saved through this screen
  // could end up in a different shape than one saved at sign-up.
  // splitPhoneNumber() below parses whatever's already stored back into
  // this pair so the field pre-fills correctly either way.
  CountryInfo _phoneCountry = defaultPhoneCountry;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.name ?? '');
    _emailCtrl = TextEditingController(text: widget.user.email ?? '');
    _phoneCtrl = TextEditingController();
    _loadPhone();
  }

  Future<void> _loadPhone() async {
    try {
      final profile = await _service.fetchMyProfile();
      final (country, national) = splitPhoneNumber(profile['phone']?.toString());
      if (mounted) {
        setState(() {
          _phoneCountry = country;
          _phoneCtrl.text = national;
        });
      }
    } catch (_) {
      // Non-fatal — form still works, phone just starts blank.
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final result = await _service.updateBasic(
      name: _nameCtrl.text.trim(),
      phone: combinePhoneNumber(_phoneCountry, _phoneCtrl.text.trim()),
      email: _emailCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated'), backgroundColor: LightColors.success),
      );
      Navigator.pop(context, true);
    } else {
      setState(() => _error = result['message']?.toString());
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
        title: const Text('Personal Information', style: TextStyle(color: LightColors.cream)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: LightColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: LightColors.error.withOpacity(0.4)),
                ),
                child: Text(_error!, style: const TextStyle(color: LightColors.error, fontSize: 13)),
              ),
            ],
            TextFormField(controller: _nameCtrl, style: const TextStyle(color: LightColors.cream), decoration: _decoration('Full name')),
            const SizedBox(height: 14),
            PhoneNumberField(
              country: _phoneCountry,
              onCountryChanged: (c) => setState(() => _phoneCountry = c),
              numberController: _phoneCtrl,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: LightColors.cream),
              decoration: _decoration('Email'),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: LightColors.gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: LightColors.deepNavy))
                    : const Text('Save Changes', style: TextStyle(color: LightColors.deepNavy, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
