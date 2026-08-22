import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../API/AuthResponse.dart';
import '../API/config.dart';
import '../l10n/app_localizations.dart';
import '../l10n/enum_labels.dart';
import '../main.dart';
import '../utils/countries.dart';
import 'DriverApprovalStatusPage.dart';
import 'DriverRegisterScreen.dart' show kDriverDestinationOptions, kBloodTypes, kHealthyOption, kOtherHealthOption, kHealthConditionOptions, kDriverTruckTypes;
import 'register_shared.dart';

/// UC-3, step 2 of 2 (2026-08-29 real backend split): everything that used
/// to be steps 2-7 of DriverRegisterScreen's wizard — driver info,
/// documents, health & coverage, truck info, truck documents, review — now
/// its own screen, reached only after DriverRegisterScreen (account info)
/// and OTP verification both succeed. Submits via
/// ApiService.completeDriverRegistration(), which creates the actual
/// Driver+DriverDocument+DriverDestination+Truck rows the old one-shot
/// register() call used to create all at once.
///
/// The caller (OtpVerificationScreen) is responsible for only ever reaching
/// this screen with a valid Sanctum token already stored — every request
/// below is authenticated.
class CompleteDriverRegistrationScreen extends StatefulWidget {
  const CompleteDriverRegistrationScreen({super.key});

  @override
  State<CompleteDriverRegistrationScreen> createState() => _CompleteDriverRegistrationScreenState();
}

class _CompleteDriverRegistrationScreenState extends State<CompleteDriverRegistrationScreen> {
  final _pageController = PageController();
  int _step = 0;
  static const int _totalSteps = 6;

  final _phoneNumberCtrl = TextEditingController();
  final _driverLicenseCtrl = TextEditingController();
  DateTime? _dateOfBirth;
  final _healthOtherCtrl = TextEditingController();
  final _truckNumberCtrl = TextEditingController();
  final _permitTypeCtrl = TextEditingController();

  bool _loading = false;
  String? _errorMessage;

  CountryInfo _phoneCountry = defaultPhoneCountry;
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
  void dispose() {
    _pageController.dispose();
    _phoneNumberCtrl.dispose();
    _driverLicenseCtrl.dispose();
    _healthOtherCtrl.dispose();
    _truckNumberCtrl.dispose();
    _permitTypeCtrl.dispose();
    super.dispose();
  }

  // ── Pickers ────────────────────────────────────────────────────────────

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
    String Function(String)? labelBuilder,
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
                        title: Text(labelBuilder == null ? opt : labelBuilder(opt),
                            style: const TextStyle(color: LightColors.textPrimary, fontSize: 13)),
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
                    child: Text(AppLocalizations.of(context)!.commonDone,
                        style: const TextStyle(color: LightColors.textPrimary, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Future<String?> _pickFromList(String title, List<String> options, {String Function(String)? labelBuilder}) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: LightColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: options
              .map((opt) => ListTile(
                    title: Text(labelBuilder == null ? opt : labelBuilder(opt),
                        style: const TextStyle(color: LightColors.textPrimary, fontSize: 13)),
                    onTap: () => Navigator.pop(ctx, opt),
                  ))
              .toList(),
        ),
      ),
    );
  }

  // ── Step navigation ───────────────────────────────────────────────────

  String? _validateStep(int step) {
    final t = AppLocalizations.of(context)!;
    switch (step) {
      case 0: // Driver info
        if (!isValidLocalPhoneNumber(_phoneNumberCtrl.text.trim())) {
          return t.driverValidationPhone;
        }
        if (_nationality == null) return t.driverValidationNationality;
        if (_dateOfBirth == null) return t.driverValidationDob;
        final age = _ageFrom(_dateOfBirth!);
        if (age < 18 || age > 65) return t.driverValidationAge;
        if (_driverLicenseCtrl.text.trim().isEmpty) return t.driverValidationLicenseNumber;
        return null;
      case 1: // Documents
        if (_licenseFile?.bytes == null || _licenseExpiry == null) {
          return t.driverValidationLicenseDoc;
        }
        if (_passportFile?.bytes == null || _passportExpiry == null) {
          return t.driverValidationPassportDoc;
        }
        if (_residencyFile?.bytes == null || _residencyExpiry == null) {
          return t.driverValidationResidencyDoc;
        }
        return null;
      case 2: // Health & coverage
        if (_bloodType == null) return t.driverValidationBloodType;
        if (_destinations.isEmpty) return t.driverValidationDestinations;
        return null;
      case 3: // Truck info
        if (_truckType == null) return t.driverValidationTruckType;
        if (_truckNumberCtrl.text.trim().isEmpty) return t.driverValidationTruckPlate;
        return null;
      case 4: // Truck documents
        if (_truckLicenseFile?.bytes == null) return t.driverValidationVehicleRegDoc;
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
      _handleSubmit();
      return;
    }
    setState(() => _step++);
    _pageController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  /// This screen only exists after account creation + OTP already
  /// succeeded, and its first page has no Navigator.pop target (going back
  /// to the account/OTP screens would re-trigger already-completed steps).
  /// Without this, a driver who registered with the wrong email/account
  /// would be permanently stuck here with no way out — so unlike every
  /// other screen in the app, this one gets its own explicit "Log out"
  /// action instead of relying on a back button.
  Future<void> _logout() async {
    // 2026-08-29 (audit item 9): revoke the token server-side too, not just
    // locally — silent on failure by design, see ApiService.logout().
    await ApiService.logout();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SplashPage()),
        (route) => false,
      );
    }
  }

  void _back() {
    if (_step == 0) {
      // See _logout()'s comment — no back target from here.
      return;
    }
    setState(() {
      _step--;
      _errorMessage = null;
    });
    _pageController.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  // ── Submit ─────────────────────────────────────────────────────────────

  Future<void> _handleSubmit() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final healthLabels = _healthConditions.where((h) => h != kOtherHealthOption).toList();
    if (_healthConditions.contains(kOtherHealthOption) && _healthOtherCtrl.text.trim().isNotEmpty) {
      healthLabels.add(_healthOtherCtrl.text.trim());
    }

    try {
      await ApiService.completeDriverRegistration(
        phone: combinePhoneNumber(_phoneCountry, _phoneNumberCtrl.text.trim()),
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
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const DriverApprovalStatusPage(approvalStatus: 'pending', accountType: 'driver'),
          ),
          (route) => false,
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

  // ── UI ─────────────────────────────────────────────────────────────────

  List<String> _stepTitles(AppLocalizations t) => [
        t.driverRegStepDriverTitle,
        t.driverRegStepDocumentsTitle,
        t.driverRegStepHealthTitle,
        t.driverRegStepTruckTitle,
        t.driverRegStepTruckDocsTitle,
        t.stepReviewTitle,
      ];

  List<String> _stepSubtitles(AppLocalizations t) => [
        t.driverRegStepDriverSubtitle,
        t.driverRegStepDocumentsSubtitle,
        t.driverRegStepHealthSubtitle,
        t.driverRegStepTruckSubtitle,
        t.driverRegStepTruckDocsSubtitle,
        t.stepReviewSubtitle,
      ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // See _back()'s comment — there's no safe screen behind this one.
      canPop: false,
      child: Scaffold(
        backgroundColor: LightColors.bg,
        appBar: AppBar(
          backgroundColor: LightColors.bg,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: _step == 0
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back, color: LightColors.textPrimary),
                  onPressed: _loading ? null : _back,
                ),
          actions: [
            // Matches DriverApprovalStatusPage's own un-localized "Log Out"
            // button (see that file) — kept consistent rather than adding a
            // new ARB key for one word right now.
            TextButton(
              onPressed: _loading ? null : _logout,
              child: const Text('Log Out', style: TextStyle(color: LightColors.textSecondary, fontSize: 13)),
            ),
          ],
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
                    _driverInfoStep(context),
                    _documentsStep(context),
                    _healthStep(context),
                    _truckInfoStep(context),
                    _truckDocumentsStep(context),
                    _reviewStep(context),
                  ],
                ),
              ),
              _bottomBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pageScaffold(BuildContext context, int stepIndex, List<Widget> children) {
    final t = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_stepTitles(t)[stepIndex],
              style: const TextStyle(color: LightColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(_stepSubtitles(t)[stepIndex], style: const TextStyle(color: LightColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 22),
          ...children,
        ],
      ),
    );
  }

  Widget _driverInfoStep(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return _pageScaffold(context, 0, [
      PhoneNumberField(
        country: _phoneCountry,
        onCountryChanged: (c) => setState(() => _phoneCountry = c),
        numberController: _phoneNumberCtrl,
      ),
      const SizedBox(height: 14),
      LightPickerField(
        label: t.nationalityLabel,
        value: _nationality?.name,
        hint: t.nationalityHint,
        icon: Icons.public,
        onTap: () async {
          final picked = await pickCountrySheet(context, t.nationalityTitle);
          if (picked != null) setState(() => _nationality = picked);
        },
      ),
      const SizedBox(height: 14),
      LightPickerField(
        label: t.dateOfBirthLabel,
        hint: t.dateOfBirthHint,
        value: _dateOfBirth == null
            ? null
            : '${_dateOfBirth!.day.toString().padLeft(2, '0')} / ${_dateOfBirth!.month.toString().padLeft(2, '0')} / ${_dateOfBirth!.year}  ·  ${t.ageLabel} ${_ageFrom(_dateOfBirth!)}',
        icon: Icons.cake_outlined,
        onTap: () async {
          final picked = await _pickDateOfBirth();
          if (picked != null) setState(() => _dateOfBirth = picked);
        },
      ),
      const SizedBox(height: 14),
      buildLightTextField(controller: _driverLicenseCtrl, label: t.driverLicenseNumberLabel, hint: t.driverLicenseNumberHint),
    ]);
  }

  Widget _documentsStep(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return _pageScaffold(context, 1, [
      _SubLabel(t.docLicenseFront),
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
      _SubLabel(t.docLicenseBack),
      const SizedBox(height: 8),
      LightPickerField(
        label: t.commonUpload,
        hint: t.commonUploadHintFormats,
        value: _licenseBackFile?.name,
        icon: Icons.upload_file_outlined,
        onTap: () async {
          final f = await _pickDocumentFile();
          if (f != null) setState(() => _licenseBackFile = f);
        },
      ),
      const SizedBox(height: 16),
      _SubLabel(t.docPassport),
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
      _SubLabel(t.docResidency),
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
      _SubLabel(t.docDriverPhoto),
      const SizedBox(height: 8),
      LightPickerField(
        label: t.commonUpload,
        hint: t.docDriverPhotoHint,
        value: _driverPhotoFile?.name,
        icon: Icons.person_outline,
        onTap: () async {
          final f = await _pickPhotoFile();
          if (f != null) setState(() => _driverPhotoFile = f);
        },
      ),
      const SizedBox(height: 14),
      _NoticeBanner(t.documentsNotice),
    ]);
  }

  Widget _healthStep(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return _pageScaffold(context, 2, [
      LightPickerField(
        label: t.healthStatusLabel,
        hint: t.healthStatusHint,
        value: _healthConditions.isEmpty ? null : _healthConditions.map(localizedHealthCondition).join(', '),
        icon: Icons.health_and_safety_outlined,
        onTap: () => _pickMultiSelectSheet(
          title: t.healthStatusTitle,
          options: kHealthConditionOptions,
          selected: _healthConditions,
          exclusiveFirstOption: true,
          labelBuilder: localizedHealthCondition,
          onSaved: (v) => setState(() => _healthConditions
            ..clear()
            ..addAll(v)),
        ),
      ),
      if (_healthConditions.contains(kOtherHealthOption)) ...[
        const SizedBox(height: 10),
        buildLightTextField(controller: _healthOtherCtrl, label: t.describeOtherCondition),
      ],
      const SizedBox(height: 14),
      LightPickerField(
        label: t.bloodTypeLabel,
        hint: t.bloodTypeHint,
        value: _bloodType,
        icon: Icons.bloodtype_outlined,
        onTap: () async {
          final picked = await _pickFromList(t.bloodTypeTitle, kBloodTypes);
          if (picked != null) setState(() => _bloodType = picked);
        },
      ),
      const SizedBox(height: 14),
      LightPickerField(
        label: t.workDestinationsLabel,
        hint: t.workDestinationsHint,
        value: _destinations.isEmpty
            ? null
            : _destinations.map((k) => localizedDestination(k, kDriverDestinationOptions[k] ?? k)).join(', '),
        icon: Icons.map_outlined,
        onTap: () => _pickMultiSelectSheet(
          title: t.workDestinationsTitle,
          options: kDriverDestinationOptions.keys.toList(),
          selected: _destinations,
          labelBuilder: (key) => localizedDestination(key, kDriverDestinationOptions[key] ?? key),
          onSaved: (v) => setState(() => _destinations
            ..clear()
            ..addAll(v)),
        ),
      ),
    ]);
  }

  Widget _truckInfoStep(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return _pageScaffold(context, 3, [
      LightPickerField(
        label: t.truckTypeLabel,
        hint: t.truckTypeHint,
        value: _truckType == null ? null : localizedTruckType(_truckType!),
        icon: Icons.local_shipping_outlined,
        onTap: () async {
          final picked = await _pickFromList(t.truckTypeTitle, kDriverTruckTypes, labelBuilder: localizedTruckType);
          if (picked != null) setState(() => _truckType = picked);
        },
      ),
      const SizedBox(height: 14),
      buildLightTextField(controller: _truckNumberCtrl, label: t.truckPlateLabel, hint: t.truckPlateHint),
      const SizedBox(height: 14),
      buildLightTextField(controller: _permitTypeCtrl, label: t.permitTypeLabel),
    ]);
  }

  Widget _truckDocumentsStep(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return _pageScaffold(context, 4, [
      _SubLabel(t.docVehicleReg),
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
      _SubLabel(t.docInsurance),
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
      _SubLabel(t.docInspection),
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
      _NoticeBanner(t.truckDocsNotice),
    ]);
  }

  Widget _reviewStep(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return _pageScaffold(context, 5, [
      _ReviewCard(icon: Icons.badge_outlined, title: t.reviewDriverInfoTitle, lines: [
        '${_nationality?.name ?? '—'} · ${t.ageLabel} ${_dateOfBirth == null ? '—' : _ageFrom(_dateOfBirth!)}',
        t.licenseNumberPrefix(_driverLicenseCtrl.text.trim()),
      ]),
      const SizedBox(height: 10),
      _ReviewCard(icon: Icons.folder_open_outlined, title: t.reviewDriverDocsTitle, lines: [
        t.uploadedCountOfTotal(
          [
            _licenseFile,
            _licenseBackFile,
            _passportFile,
            _residencyFile,
            _driverPhotoFile,
          ].where((f) => f != null).length,
          5,
        ),
      ]),
      const SizedBox(height: 10),
      _ReviewCard(icon: Icons.local_shipping_outlined, title: t.reviewTruckInfoTitle, lines: [
        '${_truckType == null ? '—' : localizedTruckType(_truckType!)} · ${t.truckPlateLabel} ${_truckNumberCtrl.text.trim()}',
      ]),
      const SizedBox(height: 10),
      _ReviewCard(icon: Icons.description_outlined, title: t.reviewTruckDocsTitle, lines: [
        t.uploadedCountOfTotal([_truckLicenseFile, _truckInsuranceFile, _truckInspectionFile].where((f) => f != null).length, 3),
      ]),
      const SizedBox(height: 16),
      _NoticeBanner(t.reviewCannotEditNotice),
    ]);
  }

  Widget _bottomBar(BuildContext context) {
    final t = AppLocalizations.of(context)!;
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
            label: _step == _totalSteps - 1 ? t.submitForReview : t.commonNext,
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
    final t = AppLocalizations.of(context)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: LightPickerField(
            label: t.commonUpload,
            hint: t.commonUploadHintFormats,
            value: fileName,
            icon: Icons.upload_file_outlined,
            onTap: onPickFile,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: LightPickerField(
            label: t.expiryDateLabel,
            hint: t.expiryDateHint,
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
