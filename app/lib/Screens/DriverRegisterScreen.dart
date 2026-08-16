import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../API/AuthResponse.dart';
import '../utils/countries.dart';
import 'OtpVerificationScreen.dart';
import 'register_shared.dart';

// Mirrors DriverDestination::DESTINATIONS on the backend exactly.
const Map<String, String> kDriverDestinationOptions = {
  'internal_uae': 'Internal (UAE)',
  'saudi_arabia': 'Saudi Arabia',
  'oman': 'Oman',
  'kuwait': 'Kuwait',
  'bahrain': 'Bahrain',
  'jordan': 'Jordan',
  'lebanon': 'Lebanon',
  'syria': 'Syria',
  'egypt': 'Egypt',
  'iraq': 'Iraq',
  'yemen': 'Yemen',
};

const List<String> kBloodTypes = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

const String kHealthyOption = 'Healthy / no conditions';
const String kOtherHealthOption = 'Other';

const List<String> kHealthConditionOptions = [
  kHealthyOption,
  'Diabetes',
  'Heart disease',
  'High blood pressure',
  'Epilepsy / seizure disorder',
  'Vision impairment',
  'Hearing impairment',
  'Respiratory condition (e.g. asthma)',
  'Back / spinal issue',
  kOtherHealthOption,
];

// Must mirror Truck::TRUCK_TYPES on the backend exactly.
const List<String> kDriverTruckTypes = [
  '3 Ton pick up',
  '7 Ton pick up',
  '10 Ton pick up',
  'Trailer 40 FT-12M-Open',
  'Trailer 40 FT-12M-Box',
  'Trailer 50 FT-15M-Open',
  'Curtain Trailer 13.5M',
  'Curtain Trailer 15M',
  'Reefer Trailer',
  'Lowbed Trailer - 25 Tons',
  'Car Career',
];

/// UC-3 (revised): full driver sign-up in one form, two sections — driver
/// info (incl. documents, health, destinations) then truck info. All of it
/// is submitted together via ApiService.registerDriver().
class DriverRegisterScreen extends StatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen> {
  // Basic account fields
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _phoneNumberCtrl = TextEditingController();
  final _driverLicenseCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _healthOtherCtrl = TextEditingController();
  final _truckNumberCtrl = TextEditingController();
  final _permitTypeCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  bool _agreed = false;
  String? _errorMessage;

  PasswordStrength _strength = PasswordStrength.none;
  bool _passwordsMatch = true;

  CountryInfo _phoneCountry = kCountries.firstWhere((c) => c.iso2 == 'AE');
  CountryInfo? _nationality;

  PlatformFile? _licenseFile;
  DateTime? _licenseExpiry;
  PlatformFile? _passportFile;
  DateTime? _passportExpiry;
  PlatformFile? _residencyFile;
  DateTime? _residencyExpiry;

  final Set<String> _healthConditions = {};
  String? _bloodType;
  final Set<String> _destinations = {};

  String? _truckType;
  PlatformFile? _truckLicenseFile;
  DateTime? _truckLicenseExpiry;

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
    _phoneNumberCtrl.dispose();
    _driverLicenseCtrl.dispose();
    _ageCtrl.dispose();
    _healthOtherCtrl.dispose();
    _truckNumberCtrl.dispose();
    _permitTypeCtrl.dispose();
    super.dispose();
  }

  // ── Pickers ────────────────────────────────────────────────────────────

  Future<CountryInfo?> _pickCountry(String title) async {
    String query = '';
    return showModalBottomSheet<CountryInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111113),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          final filtered = kCountries
              .where((c) => c.name.toLowerCase().contains(query.toLowerCase()))
              .toList();
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.7,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: Color(0xFFF5F0E8), fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        TextField(
                          autofocus: true,
                          style: const TextStyle(color: Color(0xFFF5F0E8)),
                          decoration: InputDecoration(
                            hintText: 'Search country',
                            hintStyle: const TextStyle(color: Color(0xFF6B6660)),
                            prefixIcon: const Icon(Icons.search, color: Color(0xFF6B6660)),
                            filled: true,
                            fillColor: const Color(0xFF0A0A0C),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          onChanged: (v) => setSheetState(() => query = v),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final c = filtered[i];
                        return ListTile(
                          title: Text(c.name, style: const TextStyle(color: Color(0xFFF5F0E8), fontSize: 14)),
                          trailing: Text('+${c.dialCode}', style: const TextStyle(color: Color(0xFF6B6660))),
                          onTap: () => Navigator.pop(ctx, c),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Future<PlatformFile?> _pickDocumentFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) return result.files.single;
    return null;
  }

  Future<DateTime?> _pickExpiryDate() {
    return showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 15)),
    );
  }

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickMultiSelectSheet({
    required String title,
    required List<String> options,
    required Set<String> selected,
    required void Function(Set<String>) onSaved,
    bool exclusiveFirstOption = false,
  }) async {
    final working = {...selected};
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111113),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title,
                    style: const TextStyle(color: Color(0xFFF5F0E8), fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.5),
                  child: ListView(
                    shrinkWrap: true,
                    children: options.map((opt) {
                      final isSelected = working.contains(opt);
                      return CheckboxListTile(
                        value: isSelected,
                        title: Text(opt, style: const TextStyle(color: Color(0xFFF5F0E8), fontSize: 13)),
                        activeColor: const Color(0xFFD4AF37),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (v) => setSheetState(() {
                          if (exclusiveFirstOption && opt == options.first && v == true) {
                            working
                              ..clear()
                              ..add(opt);
                          } else if (exclusiveFirstOption && v == true) {
                            working
                              ..remove(options.first)
                              ..add(opt);
                          } else if (v == true) {
                            working.add(opt);
                          } else {
                            working.remove(opt);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
                    onPressed: () {
                      onSaved(working);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Done', style: TextStyle(color: Color(0xFF0A0A0C), fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // ── Submit ─────────────────────────────────────────────────────────────

  bool get _isEmailValid => RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(_emailCtrl.text.trim());

  Future<void> _handleRegister() async {
    if (!_agreed) return;

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    final confirm = _confirmCtrl.text;
    final phoneNumber = _phoneNumberCtrl.text.trim();
    final driverLicense = _driverLicenseCtrl.text.trim();
    final ageText = _ageCtrl.text.trim();
    final truckNumber = _truckNumberCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all required fields');
      return;
    }
    if (!_isEmailValid) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }
    if (!isValidLocalPhoneNumber(phoneNumber)) {
      setState(() => _errorMessage = 'Please enter a valid phone number (digits only)');
      return;
    }
    if (_nationality == null) {
      setState(() => _errorMessage = 'Please select your nationality');
      return;
    }
    final age = int.tryParse(ageText);
    if (age == null || age < 18 || age > 65) {
      setState(() => _errorMessage = 'Age must be between 18 and 65');
      return;
    }
    if (driverLicense.isEmpty) {
      setState(() => _errorMessage = 'Please enter your driving license number');
      return;
    }
    if (_licenseFile?.bytes == null || _licenseExpiry == null) {
      setState(() => _errorMessage = 'Please attach your driving license and its expiry date');
      return;
    }
    if (_passportFile?.bytes == null || _passportExpiry == null) {
      setState(() => _errorMessage = 'Please attach your passport and its expiry date');
      return;
    }
    if (_residencyFile?.bytes == null || _residencyExpiry == null) {
      setState(() => _errorMessage = 'Please attach your residency/ID and its expiry date');
      return;
    }
    if (_bloodType == null) {
      setState(() => _errorMessage = 'Please select your blood type');
      return;
    }
    if (_destinations.isEmpty) {
      setState(() => _errorMessage = 'Please pick at least one destination you work on');
      return;
    }
    if (_truckType == null) {
      setState(() => _errorMessage = 'Please select your truck type');
      return;
    }
    if (truckNumber.isEmpty) {
      setState(() => _errorMessage = 'Please enter your truck plate/number');
      return;
    }
    if (_truckLicenseFile?.bytes == null) {
      setState(() => _errorMessage = 'Please attach the vehicle license file');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final healthLabels = _healthConditions.where((h) => h != kOtherHealthOption).toList();
    if (_healthConditions.contains(kOtherHealthOption) && _healthOtherCtrl.text.trim().isNotEmpty) {
      healthLabels.add(_healthOtherCtrl.text.trim());
    }

    try {
      final result = await ApiService.registerDriver(
        name: name,
        email: email,
        password: password,
        passwordConfirmation: confirm,
        phone: '+${_phoneCountry.dialCode}$phoneNumber',
        driverLicense: driverLicense,
        age: age.toString(),
        nationality: _nationality!.name,
        licenseFileBytes: _licenseFile!.bytes!,
        licenseFileName: _licenseFile!.name,
        licenseExpiry: _fmtDate(_licenseExpiry!),
        passportFileBytes: _passportFile!.bytes!,
        passportFileName: _passportFile!.name,
        passportExpiry: _fmtDate(_passportExpiry!),
        residencyFileBytes: _residencyFile!.bytes!,
        residencyFileName: _residencyFile!.name,
        residencyExpiry: _fmtDate(_residencyExpiry!),
        bloodType: _bloodType!,
        healthConditions: healthLabels.isEmpty ? null : healthLabels.join(', '),
        destinations: _destinations.toList(),
        truckNumber: truckNumber,
        truckType: _truckType!,
        truckLicenseFileBytes: _truckLicenseFile!.bytes!,
        truckLicenseFileName: _truckLicenseFile!.name,
        truckLicenseExpiry: _truckLicenseExpiry != null ? _fmtDate(_truckLicenseExpiry!) : null,
        permitType: _permitTypeCtrl.text.trim().isEmpty ? null : _permitTypeCtrl.text.trim(),
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

  // ── UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0C),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFF5F0E8)),
        title: const Text('Driver Sign Up', style: TextStyle(color: Color(0xFFF5F0E8))),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionHeader(title: '1. Driver Information'),
              const SizedBox(height: 14),
              buildAuthTextField(controller: _nameCtrl, label: 'Full name'),
              const SizedBox(height: 14),
              buildAuthTextField(
                controller: _emailCtrl,
                label: 'Email address',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              buildAuthTextField(
                controller: _passCtrl,
                label: 'Password',
                obscure: _obscurePass,
                suffix: IconButton(
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0xFF6B6660), size: 18),
                ),
              ),
              if (_strength != PasswordStrength.none) ...[
                const SizedBox(height: 10),
                PasswordStrengthBar(strength: _strength),
              ],
              const SizedBox(height: 14),
              buildAuthTextField(
                controller: _confirmCtrl,
                label: 'Confirm password',
                obscure: _obscureConfirm,
                hasError: !_passwordsMatch,
                suffix: IconButton(
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0xFF6B6660), size: 18),
                ),
              ),
              if (!_passwordsMatch) ...[
                const SizedBox(height: 6),
                const Text('Passwords do not match', style: TextStyle(fontSize: 11, color: Color(0xFFE57373))),
              ],
              const SizedBox(height: 14),

              // Phone: country code + number
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: InkWell(
                      onTap: () async {
                        final picked = await _pickCountry('Phone country');
                        if (picked != null) setState(() => _phoneCountry = picked);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111113),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF2A2520)),
                        ),
                        child: Text('+${_phoneCountry.dialCode}',
                            style: const TextStyle(color: Color(0xFFF5F0E8), fontSize: 14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: buildAuthTextField(
                      controller: _phoneNumberCtrl,
                      label: 'Phone number',
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              PickerField(
                label: 'Nationality',
                value: _nationality?.name,
                icon: Icons.public,
                onTap: () async {
                  final picked = await _pickCountry('Nationality');
                  if (picked != null) setState(() => _nationality = picked);
                },
              ),
              const SizedBox(height: 14),

              buildAuthTextField(controller: _ageCtrl, label: 'Age (18-65)', keyboardType: TextInputType.number),
              const SizedBox(height: 14),

              buildAuthTextField(controller: _driverLicenseCtrl, label: 'Driving license number'),
              const SizedBox(height: 20),

              const _SubLabel('Driving License'),
              const SizedBox(height: 8),
              _DocumentRow(
                fileName: _licenseFile?.name,
                expiry: _licenseExpiry,
                onPickFile: () async {
                  final f = await _pickDocumentFile();
                  if (f != null) setState(() => _licenseFile = f);
                },
                onPickDate: () async {
                  final d = await _pickExpiryDate();
                  if (d != null) setState(() => _licenseExpiry = d);
                },
              ),
              const SizedBox(height: 16),

              const _SubLabel('Passport'),
              const SizedBox(height: 8),
              _DocumentRow(
                fileName: _passportFile?.name,
                expiry: _passportExpiry,
                onPickFile: () async {
                  final f = await _pickDocumentFile();
                  if (f != null) setState(() => _passportFile = f);
                },
                onPickDate: () async {
                  final d = await _pickExpiryDate();
                  if (d != null) setState(() => _passportExpiry = d);
                },
              ),
              const SizedBox(height: 16),

              const _SubLabel('Residency / ID'),
              const SizedBox(height: 8),
              _DocumentRow(
                fileName: _residencyFile?.name,
                expiry: _residencyExpiry,
                onPickFile: () async {
                  final f = await _pickDocumentFile();
                  if (f != null) setState(() => _residencyFile = f);
                },
                onPickDate: () async {
                  final d = await _pickExpiryDate();
                  if (d != null) setState(() => _residencyExpiry = d);
                },
              ),
              const SizedBox(height: 6),
              const Text(
                'Your account is auto-suspended if any mandatory document expires without a renewal on file.',
                style: TextStyle(fontSize: 11, color: Color(0xFF6B6660)),
              ),
              const SizedBox(height: 20),

              PickerField(
                label: 'Health status',
                value: _healthConditions.isEmpty ? null : _healthConditions.join(', '),
                icon: Icons.health_and_safety_outlined,
                onTap: () => _pickMultiSelectSheet(
                  title: 'Health status',
                  options: kHealthConditionOptions,
                  selected: _healthConditions,
                  exclusiveFirstOption: true,
                  onSaved: (v) => setState(() => _healthConditions
                    ..clear()
                    ..addAll(v)),
                ),
              ),
              if (_healthConditions.contains(kOtherHealthOption)) ...[
                const SizedBox(height: 10),
                buildAuthTextField(controller: _healthOtherCtrl, label: 'Describe the other condition'),
              ],
              const SizedBox(height: 14),

              PickerField(
                label: 'Blood type',
                value: _bloodType,
                icon: Icons.bloodtype_outlined,
                onTap: () async {
                  final picked = await showModalBottomSheet<String>(
                    context: context,
                    backgroundColor: const Color(0xFF111113),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (ctx) => SafeArea(
                      child: Wrap(
                        children: kBloodTypes
                            .map((b) => ListTile(
                                  title: Text(b, style: const TextStyle(color: Color(0xFFF5F0E8))),
                                  onTap: () => Navigator.pop(ctx, b),
                                ))
                            .toList(),
                      ),
                    ),
                  );
                  if (picked != null) setState(() => _bloodType = picked);
                },
              ),
              const SizedBox(height: 14),

              PickerField(
                label: 'Work destinations',
                value: _destinations.isEmpty
                    ? null
                    : _destinations.map((k) => kDriverDestinationOptions[k]).join(', '),
                icon: Icons.map_outlined,
                onTap: () => _pickMultiSelectSheet(
                  title: 'Work destinations',
                  options: kDriverDestinationOptions.keys.toList(),
                  selected: _destinations,
                  onSaved: (v) => setState(() => _destinations
                    ..clear()
                    ..addAll(v)),
                ),
              ),

              const SizedBox(height: 32),
              _SectionHeader(title: '2. Truck Information'),
              const SizedBox(height: 14),

              PickerField(
                label: 'Truck type',
                value: _truckType,
                icon: Icons.local_shipping_outlined,
                onTap: () async {
                  final picked = await showModalBottomSheet<String>(
                    context: context,
                    backgroundColor: const Color(0xFF111113),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (ctx) => SafeArea(
                      child: ListView(
                        shrinkWrap: true,
                        children: kDriverTruckTypes
                            .map((t) => ListTile(
                                  title: Text(t, style: const TextStyle(color: Color(0xFFF5F0E8), fontSize: 13)),
                                  onTap: () => Navigator.pop(ctx, t),
                                ))
                            .toList(),
                      ),
                    ),
                  );
                  if (picked != null) setState(() => _truckType = picked);
                },
              ),
              const SizedBox(height: 14),

              buildAuthTextField(controller: _truckNumberCtrl, label: 'Truck plate / number'),
              const SizedBox(height: 20),

              const _SubLabel('Vehicle License'),
              const SizedBox(height: 8),
              _DocumentRow(
                fileName: _truckLicenseFile?.name,
                expiry: _truckLicenseExpiry,
                onPickFile: () async {
                  final f = await _pickDocumentFile();
                  if (f != null) setState(() => _truckLicenseFile = f);
                },
                onPickDate: () async {
                  final d = await _pickExpiryDate();
                  if (d != null) setState(() => _truckLicenseExpiry = d);
                },
              ),
              const SizedBox(height: 14),

              buildAuthTextField(controller: _permitTypeCtrl, label: 'Permit type (optional)'),

              const SizedBox(height: 26),
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
                        border: Border.all(
                          color: _agreed ? const Color(0xFFD4AF37) : const Color(0xFF3A3530),
                          width: 1.5,
                        ),
                        color: _agreed ? const Color(0xFFD4AF37) : Colors.transparent,
                      ),
                      child: _agreed ? const Icon(Icons.check, size: 13, color: Color(0xFF0A0A0C)) : null,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'I agree to the Terms of Service and Privacy Policy',
                        style: TextStyle(fontSize: 13, color: Color(0xFF6B6660), height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A0F0F),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE57373).withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFE57373), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMessage!, style: const TextStyle(fontSize: 13, color: Color(0xFFE57373))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_agreed && !_loading) ? _handleRegister : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    disabledBackgroundColor: const Color(0xFF1E1C18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A0A0C)),
                        )
                      : Text(
                          'Create account',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _agreed ? const Color(0xFF0A0A0C) : const Color(0xFF4A4540),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: Color(0xFF2A2520))),
      ],
    );
  }
}

class _SubLabel extends StatelessWidget {
  final String text;
  const _SubLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: Color(0xFF6B6660), fontSize: 12, fontWeight: FontWeight.w600));
  }
}

class _DocumentRow extends StatelessWidget {
  final String? fileName;
  final DateTime? expiry;
  final VoidCallback onPickFile;
  final VoidCallback onPickDate;

  const _DocumentRow({
    required this.fileName,
    required this.expiry,
    required this.onPickFile,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: PickerField(
            label: 'Upload (PDF/JPG/PNG)',
            value: fileName,
            icon: Icons.upload_file_outlined,
            onTap: onPickFile,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: PickerField(
            label: 'Expiry date',
            value: expiry == null
                ? null
                : '${expiry!.year}-${expiry!.month.toString().padLeft(2, '0')}-${expiry!.day.toString().padLeft(2, '0')}',
            icon: Icons.event_outlined,
            onTap: onPickDate,
          ),
        ),
      ],
    );
  }
}
