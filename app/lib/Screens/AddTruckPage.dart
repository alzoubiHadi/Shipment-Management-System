import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../API/TruckService.dart';
import '../API/config.dart';

class AddTruckPage extends StatefulWidget {
  const AddTruckPage({super.key});

  @override
  State<AddTruckPage> createState() => _AddTruckPageState();
}

class _AddTruckPageState extends State<AddTruckPage> {
  final _formKey = GlobalKey<FormState>();
  final _truckNumberController = TextEditingController();

  // Must be one of the 11 fixed types the backend accepts (Truck::TRUCK_TYPES).
  String? _truckType;
  bool _hasRefrigeration = false;
  bool _isSaving = false;
  String? _errorMessage;

  PlatformFile? _licenseFile;

  @override
  void dispose() {
    _truckNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickLicenseFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true, // required for Flutter Web — no filesystem path there
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() => _licenseFile = result.files.single);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_truckType == null) {
      setState(() => _errorMessage = 'Please select a truck type');
      return;
    }

    if (_licenseFile == null || _licenseFile!.bytes == null) {
      setState(() => _errorMessage = 'Please attach the vehicle license file');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final result = await TruckService.addMyTruck(
      truckNumber: _truckNumberController.text.trim(),
      truckType: _truckType!,
      hasRefrigeration: _hasRefrigeration,
      licenseFileBytes: _licenseFile!.bytes,
      licenseFileName: _licenseFile!.name,
    );

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (result['success'] == true) {
      Navigator.pop(context, true);
    } else {
      setState(() => _errorMessage = result['message']?.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.cream),
        title: const Text(
          'Add Truck',
          style: TextStyle(color: AppColors.cream),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: AppColors.error.withOpacity(0.4)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                        color: AppColors.error, fontSize: 13),
                  ),
                ),
              ],
              TextFormField(
                controller: _truckNumberController,
                style: const TextStyle(color: AppColors.cream),
                decoration: _decoration('Truck number'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _truckType,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: AppColors.cream, fontSize: 14),
                decoration: _decoration('Truck type'),
                items: kTruckTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _truckType = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: SwitchListTile(
                  value: _hasRefrigeration,
                  onChanged: (v) => setState(() => _hasRefrigeration = v),
                  title: const Text(
                    'Has refrigeration',
                    style: TextStyle(color: AppColors.cream, fontSize: 14),
                  ),
                  activeColor: AppColors.gold,
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _pickLicenseFile,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _licenseFile == null ? AppColors.border : AppColors.gold,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _licenseFile == null
                            ? Icons.upload_file_outlined
                            : Icons.check_circle_outline,
                        color: _licenseFile == null ? AppColors.muted : AppColors.gold,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _licenseFile?.name ?? 'Attach vehicle license (PDF/JPG/PNG)',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _licenseFile == null ? AppColors.muted : AppColors.cream,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.bg,
                          ),
                        )
                      : const Text(
                          'Save Truck',
                          style: TextStyle(
                            color: AppColors.bg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.gold),
      ),
    );
  }
}
