import 'package:flutter/material.dart';

import '../API/ProfileService.dart';
import '../API/config.dart';

/// Driver Phase 5 (2026-08-20): "Bank Details" — kept to the three fields
/// a finance team actually needs to action a manual payout (bank_name,
/// bank_account_holder, bank_iban — new columns on drivers, see the
/// 2026_08_20_000101 migration). No automated payout flow reads these yet;
/// this is reference info for whoever processes payouts.
class DriverBankDetailsPage extends StatefulWidget {
  const DriverBankDetailsPage({super.key});

  @override
  State<DriverBankDetailsPage> createState() => _DriverBankDetailsPageState();
}

class _DriverBankDetailsPageState extends State<DriverBankDetailsPage> {
  final _service = ProfileService();
  final _bankNameCtrl = TextEditingController();
  final _holderCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await _service.fetchMyProfile();
      if (!mounted) return;
      setState(() {
        _bankNameCtrl.text = profile['bank_name']?.toString() ?? '';
        _holderCtrl.text = profile['bank_account_holder']?.toString() ?? '';
        _ibanCtrl.text = profile['bank_iban']?.toString() ?? '';
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _bankNameCtrl.dispose();
    _holderCtrl.dispose();
    _ibanCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final result = await _service.updateBankDetails(
      bankName: _bankNameCtrl.text.trim(),
      bankAccountHolder: _holderCtrl.text.trim(),
      bankIban: _ibanCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bank details updated'), backgroundColor: AppColors.success),
      );
      Navigator.pop(context, true);
    } else {
      setState(() => _error = result['message']?.toString());
    }
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.gold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.cream),
        title: const Text('Bank Details', style: TextStyle(color: AppColors.cream)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.gold.withOpacity(0.25)),
                    ),
                    child: const Text(
                      'These details are used by our finance team to send your payouts. Double-check them before saving.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                    ),
                  ),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error.withOpacity(0.4)),
                      ),
                      child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                    ),
                  ],
                  TextFormField(controller: _bankNameCtrl, style: const TextStyle(color: AppColors.cream), decoration: _decoration('Bank name')),
                  const SizedBox(height: 14),
                  TextFormField(controller: _holderCtrl, style: const TextStyle(color: AppColors.cream), decoration: _decoration('Account holder name')),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _ibanCtrl,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(color: AppColors.cream),
                    decoration: _decoration('IBAN / Account number'),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg))
                          : const Text('Save Bank Details', style: TextStyle(color: AppColors.bg, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
