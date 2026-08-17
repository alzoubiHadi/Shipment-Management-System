import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../API/AuthResponse.dart';
import '../API/config.dart';
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

/// UC-3 (revised 2026-08-19 to match the agreed step-by-step design): a
/// 7-page wizard — Account Info, Driver Info, Documents, Health & Coverage,
/// Truck Info, Truck Documents, Review — submitted all together at the end
/// via ApiService.registerDriver() exactly as before (one atomic
/// request), with the OTP screen shown after that succeeds.
///
/// One deliberate deviation from the design mockup, flagged rather than
/// silently done: the mockup shows email OTP verification as step 3,
/// BEFORE the driver/truck info steps. Moving it there would mean
/// splitting account creation into two separate backend calls (auth-only,
/// then a second authenticated call to fill in the rest) — a real
/// architecture change to a working, tested flow. This keeps OTP as the
/// last step instead (after Review & Submit), which is functionally
/// identical from the driver's point of view — same steps, same data,
/// same one-time code — just verified right after everything is entered
/// rather than in between.
///
/// The "Select Truck from a fleet list" mockup step does not apply here —
/// confirmed 2026-08-19: drivers still register their own truck directly
/// (no shared fleet concept in this system), so that step is just "Truck
/// Info" like before.
class DriverRegisterScreen extends StatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen> {
  final _pageController = PageController();
  int _step = 0;
  static const int _totalSteps = 7;

  // Basic account fields
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _phoneNumberCtrl = TextEditingController();
  final _driverLicenseCtrl = TextEditingController();
  DateTime? _dateOfBirth;
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
  PlatformFile? _licenseBackFile;
  PlatformFile? _passportFile;
  DateTime? _passportExpiry;
  PlatformFile? _residencyFile;
  DateTime? _residencyExpiry;
  PlatformFile? _driverPhotoFile;

  final Set<String> _healthConditions = {};
  String? _bloodType;
  final Set<String> _destinations = {};

  String? _truckType;
  PlatformFile? _truckLicenseFile;
  DateTime? _truckLicenseExpiry;
  PlatformFile? _truckInsuranceFile;
  DateTime? _truckInsuranceExpiry;
  PlatformFile? _truckInspectionFile;
  DateTime? _truckInspectionExpiry;

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
    _pageController.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _phoneNumberCtrl.dispose();
    _driverLicenseCtrl.dispose();
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
      backgroundColor: LightColors.surface,
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
                                color: LightColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        TextField(
                          autofocus: true,
                          style: const TextStyle(color: LightColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Search country',
                            hintStyle: const TextStyle(color: LightColors.textSecondary),
                            prefixIcon: const Icon(Icons.search, color: LightColors.textSecondary),
                            filled: true,
                            fillColor: LightColors.bg,
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
                          title: Text(c.name, style: const TextStyle(color: LightColors.textPrimary, fontSize: 14)),
                          trailing: Text('+${c.dialCode}', style: const TextStyle(color: LightColors.textSecondary)),
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

  Future<PlatformFile?> _pickPhotoFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
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

  /// Bounds the picker itself to dates of birth that land between 18 and
  /// 65 years old today, so it's impossible to pick an out-of-range date
  /// in the first place rather than picking then getting a validation
  /// error.
  Future<DateTime?> _pickDateOfBirth() {
    final now = DateTime.now();
    final maxDob = DateTime(now.year - 18, now.month, now.day);
    final minDob = DateTime(now.year - 65, now.month, now.day);
    return showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: minDob,
      lastDate: maxDob,
    );
  }

  /// Whole years between [dob] and today — the standard "has the birthday
  /// happened yet this year" calculation.
  int _ageFrom(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
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
      backgroundColor: LightColors.surface,
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
                    style: const TextStyle(color: LightColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.5),
                  child: ListView(
                    shrinkWrap: true,
                    children: options.map((opt) {
                      final isSelected = working.contains(opt);
                      return CheckboxListTile(
                        value: isSelected,
                        title: Text(opt, style: const TextStyle(color: LightColors.textPrimary, fontSize: 13)),
                        activeColor: LightColors.gold,
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
                    style: ElevatedButton.styleFrom(backgroundColor: LightColors.gold),
                    onPressed: () {
                      onSaved(working);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Done', style: TextStyle(color: LightColors.textPrimary, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Future<String?> _pickFromList(String title, List<String> options) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: LightColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: options
              .map((t) => ListTile(
                    title: Text(t, style: const TextStyle(color: LightColors.textPrimary, fontSize: 13)),
                    onTap: () => Navigator.pop(ctx, t),
                  ))
              .toList(),
        ),
      ),
    );
  }

  // ── Step navigation ───────────────────────────────────────────────────

  bool get _isEmailValid => RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(_emailCtrl.text.trim());

  String? _validateStep(int step) {
    switch (step) {
      case 0: // Account info
        if (_nameCtrl.text.trim().isEmpty ||
            _emailCtrl.text.trim().isEmpty ||
            _passCtrl.text.isEmpty ||
            _confirmCtrl.text.isEmpty) {
          return 'Please fill in all required fields';
        }
        if (!_isEmailValid) return 'Please enter a valid email address';
        if (_passCtrl.text != _confirmCtrl.text) return 'Passwords do not match';
        if (!_agreed) return 'Please agree to the Terms of Service and Privacy Policy';
        return null;
      case 1: // Driver info
        if (!isValidLocalPhoneNumber(_phoneNumberCtrl.text.trim())) {
          return 'Please enter a valid phone number (digits only)';
        }
        if (_nationality == null) return 'Please select your nationality';
        if (_dateOfBirth == null) return 'Please select your date of birth';
        final age = _ageFrom(_dateOfBirth!);
        if (age < 18 || age > 65) return 'Age must be between 18 and 65';
        if (_driverLicenseCtrl.text.trim().isEmpty) return 'Please enter your driving license number';
        return null;
      case 2: // Documents
        if (_licenseFile?.bytes == null || _licenseExpiry == null) {
          return 'Please attach your driving license (front) and its expiry date';
        }
        if (_passportFile?.bytes == null || _passportExpiry == null) {
          return 'Please attach your passport and its expiry date';
        }
        if (_residencyFile?.bytes == null || _residencyExpiry == null) {
          return 'Please attach your Emirates ID / residency and its expiry date';
        }
        return null;
      case 3: // Health & coverage
        if (_bloodType == null) return 'Please select your blood type';
        if (_destinations.isEmpty) return 'Please pick at least one destination you work on';
        return null;
      case 4: // Truck info
        if (_truckType == null) return 'Please select your truck type';
        if (_truckNumberCtrl.text.trim().isEmpty) return 'Please enter your truck plate/number';
        return null;
      case 5: // Truck documents
        if (_truckLicenseFile?.bytes == null) return 'Please attach the vehicle registration file';
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
      _handleRegister();
      return;
    }
    setState(() => _step++);
    _pageController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _step--;
      _errorMessage = null;
    });
    _pageController.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  // ── Submit ─────────────────────────────────────────────────────────────

  Future<void> _handleRegister() async {
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
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        passwordConfirmation: _confirmCtrl.text,
        phone: '+${_phoneCountry.dialCode}${_phoneNumberCtrl.text.trim()}',
        driverLicense: _driverLicenseCtrl.text.trim(),
        age: _ageFrom(_dateOfBirth!).toString(),
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
        truckNumber: _truckNumberCtrl.text.trim(),
        truckType: _truckType!,
        truckLicenseFileBytes: _truckLicenseFile!.bytes!,
        truckLicenseFileName: _truckLicenseFile!.name,
        truckLicenseExpiry: _truckLicenseExpiry != null ? _fmtDate(_truckLicenseExpiry!) : null,
        permitType: _permitTypeCtrl.text.trim().isEmpty ? null : _permitTypeCtrl.text.trim(),
        licenseBackFileBytes: _licenseBackFile?.bytes,
        licenseBackFileName: _licenseBackFile?.name,
        driverPhotoFileBytes: _driverPhotoFile?.bytes,
        driverPhotoFileName: _driverPhotoFile?.name,
        truckInsuranceFileBytes: _truckInsuranceFile?.bytes,
        truckInsuranceFileName: _truckInsuranceFile?.name,
        truckInsuranceExpiry: _truckInsuranceExpiry != null ? _fmtDate(_truckInsuranceExpiry!) : null,
        truckInspectionFileBytes: _truckInspectionFile?.bytes,
        truckInspectionFileName: _truckInspectionFile?.name,
        truckInspectionExpiry: _truckInspectionExpiry != null ? _fmtDate(_truckInspectionExpiry!) : null,
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
      // Anything that isn't an ApiException (a null-check on a field that
      // slipped past validation, a malformed response, etc.) used to
      // propagate uncaught here — the button's spinner would clear via
      // `finally` but nothing else would happen, which looked exactly like
      // the submission was silently stuck. Always surface *something*.
      if (mounted) setState(() => _errorMessage = 'Something went wrong while submitting: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────

  static const _stepTitles = [
    'Account Information',
    'Driver Information',
    'Driver Documents',
    'Health & Coverage',
    'Truck Information',
    'Truck Documents',
    'Review Your Information',
  ];

  static const _stepSubtitles = [
    'Enter your account details',
    'All fields are mandatory',
    'All documents are mandatory',
    'Tell us about your health and work coverage',
    'Enter your truck details',
    'All documents are mandatory',
    'Please review all information before submitting',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: LightColors.textPrimary),
          onPressed: _loading ? null : _back,
        ),
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
                  _accountInfoStep(),
                  _driverInfoStep(),
                  _documentsStep(),
                  _healthStep(),
                  _truckInfoStep(),
                  _truckDocumentsStep(),
                  _reviewStep(),
                ],
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _pageScaffold(int stepIndex, List<Widget> children) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_stepTitles[stepIndex],
              style: const TextStyle(color: LightColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(_stepSubtitles[stepIndex], style: const TextStyle(color: LightColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 22),
          ...children,
        ],
      ),
    );
  }

  Widget _accountInfoStep() {
    return _pageScaffold(0, [
      buildLightTextField(controller: _nameCtrl, label: 'Full Name', hint: 'Mohamed Ali'),
      const SizedBox(height: 14),
      buildLightTextField(
          controller: _emailCtrl, label: 'Email', hint: 'mohamed.ali@example.com', keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 14),
      buildLightTextField(
        controller: _passCtrl,
        label: 'Password',
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
        label: 'Confirm Password',
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
        const Text('Passwords do not match', style: TextStyle(fontSize: 11, color: LightColors.error)),
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
            const Expanded(
              child: Text(
                'I agree to the Terms & Conditions',
                style: TextStyle(fontSize: 13, color: LightColors.textSecondary, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _driverInfoStep() {
    return _pageScaffold(1, [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Code', style: TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await _pickCountry('Phone country');
                    if (picked != null) setState(() => _phoneCountry = picked);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                    decoration: BoxDecoration(
                      color: LightColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: LightColors.border),
                    ),
                    child: Text('+${_phoneCountry.dialCode}', style: const TextStyle(color: LightColors.textPrimary, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: buildLightTextField(
                controller: _phoneNumberCtrl, label: 'Phone Number', hint: '50 123 4567', keyboardType: TextInputType.phone),
          ),
        ],
      ),
      const SizedBox(height: 14),
      LightPickerField(
        label: 'Nationality',
        value: _nationality?.name,
        hint: 'Select nationality',
        icon: Icons.public,
        onTap: () async {
          final picked = await _pickCountry('Nationality');
          if (picked != null) setState(() => _nationality = picked);
        },
      ),
      const SizedBox(height: 14),
      LightPickerField(
        label: 'Date of Birth',
        hint: '15 / 05 / 1992',
        value: _dateOfBirth == null
            ? null
            : '${_dateOfBirth!.day.toString().padLeft(2, '0')} / ${_dateOfBirth!.month.toString().padLeft(2, '0')} / ${_dateOfBirth!.year}  ·  Age ${_ageFrom(_dateOfBirth!)}',
        icon: Icons.cake_outlined,
        onTap: () async {
          final picked = await _pickDateOfBirth();
          if (picked != null) setState(() => _dateOfBirth = picked);
        },
      ),
      const SizedBox(height: 14),
      buildLightTextField(controller: _driverLicenseCtrl, label: 'Driver License Number', hint: 'D1234567'),
    ]);
  }

  Widget _documentsStep() {
    return _pageScaffold(2, [
      const _SubLabel('Driving license — front'),
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
      const _SubLabel('Driving license — back (optional)'),
      const SizedBox(height: 8),
      LightPickerField(
        label: 'Upload',
        hint: 'PDF/JPG/PNG',
        value: _licenseBackFile?.name,
        icon: Icons.upload_file_outlined,
        onTap: () async {
          final f = await _pickDocumentFile();
          if (f != null) setState(() => _licenseBackFile = f);
        },
      ),
      const SizedBox(height: 16),
      const _SubLabel('Passport (first page)'),
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
      const _SubLabel('Emirates ID / Residency'),
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
      const SizedBox(height: 16),
      const _SubLabel('Driver photo (optional)'),
      const SizedBox(height: 8),
      LightPickerField(
        label: 'Upload',
        hint: 'A clear portrait photo',
        value: _driverPhotoFile?.name,
        icon: Icons.person_outline,
        onTap: () async {
          final f = await _pickPhotoFile();
          if (f != null) setState(() => _driverPhotoFile = f);
        },
      ),
      const SizedBox(height: 14),
      const _NoticeBanner('All documents must be clear and valid. Expired documents are not accepted.'),
    ]);
  }

  Widget _healthStep() {
    return _pageScaffold(3, [
      LightPickerField(
        label: 'Health Status',
        hint: 'Select any conditions',
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
        buildLightTextField(controller: _healthOtherCtrl, label: 'Describe the other condition'),
      ],
      const SizedBox(height: 14),
      LightPickerField(
        label: 'Blood Type',
        hint: 'Select blood type',
        value: _bloodType,
        icon: Icons.bloodtype_outlined,
        onTap: () async {
          final picked = await _pickFromList('Blood type', kBloodTypes);
          if (picked != null) setState(() => _bloodType = picked);
        },
      ),
      const SizedBox(height: 14),
      LightPickerField(
        label: 'Work Destinations',
        hint: 'Countries you operate in',
        value: _destinations.isEmpty ? null : _destinations.map((k) => kDriverDestinationOptions[k]).join(', '),
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
    ]);
  }

  Widget _truckInfoStep() {
    return _pageScaffold(4, [
      LightPickerField(
        label: 'Truck Type',
        hint: 'Select truck type',
        value: _truckType,
        icon: Icons.local_shipping_outlined,
        onTap: () async {
          final picked = await _pickFromList('Truck type', kDriverTruckTypes);
          if (picked != null) setState(() => _truckType = picked);
        },
      ),
      const SizedBox(height: 14),
      buildLightTextField(controller: _truckNumberCtrl, label: 'Truck Plate / Number', hint: 'C 12345'),
      const SizedBox(height: 14),
      buildLightTextField(controller: _permitTypeCtrl, label: 'Permit Type (optional)'),
    ]);
  }

  Widget _truckDocumentsStep() {
    return _pageScaffold(5, [
      const _SubLabel('Vehicle registration'),
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
      const SizedBox(height: 16),
      const _SubLabel('Insurance (optional)'),
      const SizedBox(height: 8),
      _DocumentRow(
        fileName: _truckInsuranceFile?.name,
        expiry: _truckInsuranceExpiry,
        onPickFile: () async {
          final f = await _pickDocumentFile();
          if (f != null) setState(() => _truckInsuranceFile = f);
        },
        onPickDate: () async {
          final d = await _pickExpiryDate();
          if (d != null) setState(() => _truckInsuranceExpiry = d);
        },
      ),
      const SizedBox(height: 16),
      const _SubLabel('Technical inspection (optional)'),
      const SizedBox(height: 8),
      _DocumentRow(
        fileName: _truckInspectionFile?.name,
        expiry: _truckInspectionExpiry,
        onPickFile: () async {
          final f = await _pickDocumentFile();
          if (f != null) setState(() => _truckInspectionFile = f);
        },
        onPickDate: () async {
          final d = await _pickExpiryDate();
          if (d != null) setState(() => _truckInspectionExpiry = d);
        },
      ),
      const SizedBox(height: 14),
      const _NoticeBanner('Make sure the vehicle registration is valid — expired documents are not accepted.'),
    ]);
  }

  Widget _reviewStep() {
    return _pageScaffold(6, [
      _ReviewCard(icon: Icons.person_outline, title: 'Account Information', lines: [_nameCtrl.text.trim(), _emailCtrl.text.trim()]),
      const SizedBox(height: 10),
      _ReviewCard(icon: Icons.badge_outlined, title: 'Driver Information', lines: [
        '${_nationality?.name ?? '—'} · Age ${_dateOfBirth == null ? '—' : _ageFrom(_dateOfBirth!)}',
        'License #${_driverLicenseCtrl.text.trim()}',
      ]),
      const SizedBox(height: 10),
      _ReviewCard(icon: Icons.folder_open_outlined, title: 'Driver Documents', lines: [
        '${[
          _licenseFile,
          _licenseBackFile,
          _passportFile,
          _residencyFile,
          _driverPhotoFile,
        ].where((f) => f != null).length}/5 uploaded',
      ]),
      const SizedBox(height: 10),
      _ReviewCard(icon: Icons.local_shipping_outlined, title: 'Truck Information', lines: [
        '${_truckType ?? '—'} · Plate ${_truckNumberCtrl.text.trim()}',
      ]),
      const SizedBox(height: 10),
      _ReviewCard(icon: Icons.description_outlined, title: 'Truck Documents', lines: [
        '${[_truckLicenseFile, _truckInsuranceFile, _truckInspectionFile].where((f) => f != null).length}/3 uploaded',
      ]),
      const SizedBox(height: 16),
      const _NoticeBanner("You won't be able to edit this after submission."),
    ]);
  }

  Widget _bottomBar() {
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
            label: _step == _totalSteps - 1 ? 'Submit for Review' : 'Next',
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

/// Amber notice box matching the "All documents must be clear and valid..."
/// callouts in the mockups.
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
          child: LightPickerField(
            label: 'Upload',
            hint: 'PDF/JPG/PNG',
            value: fileName,
            icon: Icons.upload_file_outlined,
            onTap: onPickFile,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: LightPickerField(
            label: 'Expiry Date',
            hint: 'dd/mm/yyyy',
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
