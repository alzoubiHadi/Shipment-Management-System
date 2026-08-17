import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../API/ProfileService.dart';
import '../API/config.dart';
import '../utils/countries.dart';
import 'DriverDestinationsPage.dart';
import 'DriverDocumentsPage.dart';
import 'DriverRegisterScreen.dart' show kBloodTypes, kDriverTruckTypes;
import 'register_shared.dart';

/// Task #57 — a real "Changes Required" edit screen, replacing the old
/// quick-links-only version of this flow. Lets a driver/company fix
/// whatever an admin flagged directly here: driver info, truck info +
/// documents (driver), or company info + trade license (company), then
/// resubmit for review. Loads current values from GET /me/profile so the
/// form starts pre-filled instead of blank.
///
/// Only reachable while approval_status == 'changes_required' — the
/// underlying endpoints (updateDriverInfo/updateCompanyInfo/updateMyTruck)
/// enforce this server-side too.
class ChangesRequiredEditScreen extends StatefulWidget {
  final String accountType; // 'driver' | 'company'
  final String? rejectionReason;
  final List<String> documentIssues;

  const ChangesRequiredEditScreen({
    super.key,
    required this.accountType,
    this.rejectionReason,
    this.documentIssues = const [],
  });

  @override
  State<ChangesRequiredEditScreen> createState() => _ChangesRequiredEditScreenState();
}

class _ChangesRequiredEditScreenState extends State<ChangesRequiredEditScreen> {
  final _service = ProfileService();
  bool get _isCompany => widget.accountType == 'company';

  bool _loadingProfile = true;
  String? _loadError;
  String? _driverUserId;

  // Driver fields
  final _nationalityCtrl = TextEditingController();
  CountryInfo? _nationality;
  DateTime? _dateOfBirth;
  final _licenseCtrl = TextEditingController();
  String? _bloodType;
  final _healthCtrl = TextEditingController();
  bool _savingDriverInfo = false;

  // Truck fields
  final _truckNumberCtrl = TextEditingController();
  String? _truckType;
  final _permitTypeCtrl = TextEditingController();
  DateTime? _permitExpiry;
  DateTime? _truckLicenseExpiry;
  DateTime? _insuranceExpiry;
  DateTime? _inspectionExpiry;
  PlatformFile? _truckLicenseFile;
  PlatformFile? _insuranceFile;
  PlatformFile? _inspectionFile;
  bool _savingTruck = false;

  // Company fields
  final _companyNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  PlatformFile? _companyLicenseFile;
  DateTime? _companyLicenseExpiry;
  bool _savingCompanyInfo = false;
  bool _savingLicense = false;

  bool _resubmitting = false;
  String? _banner;
  bool _bannerIsError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nationalityCtrl.dispose();
    _licenseCtrl.dispose();
    _healthCtrl.dispose();
    _truckNumberCtrl.dispose();
    _permitTypeCtrl.dispose();
    _companyNameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null || v is! String || v.isEmpty) return null;
    return DateTime.tryParse(v);
  }

  Future<void> _load() async {
    setState(() {
      _loadingProfile = true;
      _loadError = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      _driverUserId = prefs.getString('id');

      final profile = await _service.fetchMyProfile();

      if (_isCompany) {
        _companyNameCtrl.text = (profile['name'] ?? '').toString();
        _phoneCtrl.text = (profile['phone'] ?? '').toString();
        _addressCtrl.text = (profile['address'] ?? '').toString();
      } else {
        final nationalityName = profile['nationality']?.toString();
        if (nationalityName != null && nationalityName.isNotEmpty) {
          try {
            _nationality = kCountries.firstWhere((c) => c.name == nationalityName);
          } catch (_) {
            _nationality = null;
          }
        }
        // The backend only stores a plain integer age, not a date of
        // birth — reconstruct an approximate DOB (today's month/day, N
        // years back) so the picker starts somewhere sensible; this
        // round-trips to the exact same age if left untouched.
        final storedAge = int.tryParse((profile['age'] ?? '').toString());
        if (storedAge != null) {
          final now = DateTime.now();
          _dateOfBirth = DateTime(now.year - storedAge, now.month, now.day);
        }
        _licenseCtrl.text = (profile['driver_license'] ?? '').toString();
        _bloodType = profile['blood_type']?.toString();
        _healthCtrl.text = (profile['health_conditions'] ?? '').toString();

        final truck = profile['truck'];
        if (truck is Map) {
          _truckNumberCtrl.text = (truck['truck_number'] ?? '').toString();
          _truckType = truck['truck_type']?.toString();
          _permitTypeCtrl.text = (truck['permit_type'] ?? '').toString();
          _permitExpiry = _parseDate(truck['permit_expiry']);
          _truckLicenseExpiry = _parseDate(truck['license_expiry']);
          _insuranceExpiry = _parseDate(truck['insurance_expiry']);
          _inspectionExpiry = _parseDate(truck['technical_inspection_expiry']);
        }
      }
    } catch (e) {
      _loadError = 'Could not load your current information: $e';
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int _ageFrom(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

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

  Future<DateTime?> _pickDate(DateTime? initial) {
    return showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 15)),
    );
  }

  Future<PlatformFile?> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) return result.files.single;
    return null;
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

  Future<CountryInfo?> _pickCountry() {
    String query = '';
    return showModalBottomSheet<CountryInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LightColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          final filtered = kCountries.where((c) => c.name.toLowerCase().contains(query.toLowerCase())).toList();
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.7,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    autofocus: true,
                    style: const TextStyle(color: LightColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search country',
                      prefixIcon: const Icon(Icons.search, color: LightColors.textSecondary),
                      filled: true,
                      fillColor: LightColors.bg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onChanged: (v) => setSheetState(() => query = v),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => ListTile(
                      title: Text(filtered[i].name, style: const TextStyle(color: LightColors.textPrimary, fontSize: 14)),
                      onTap: () => Navigator.pop(ctx, filtered[i]),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _showBanner(String message, {bool isError = false}) {
    setState(() {
      _banner = message;
      _bannerIsError = isError;
    });
  }

  Future<void> _saveDriverInfo() async {
    setState(() => _savingDriverInfo = true);
    final fields = <String, dynamic>{
      if (_nationality != null) 'nationality': _nationality!.name,
      if (_dateOfBirth != null) 'age': _ageFrom(_dateOfBirth!),
      if (_licenseCtrl.text.trim().isNotEmpty) 'driver_license': _licenseCtrl.text.trim(),
      if (_bloodType != null) 'blood_type': _bloodType,
      'health_conditions': _healthCtrl.text.trim(),
    };
    final result = await _service.updateDriverInfo(fields);
    if (!mounted) return;
    setState(() => _savingDriverInfo = false);
    _showBanner(result['message']?.toString() ?? '', isError: result['success'] != true);
  }

  Future<void> _saveTruck() async {
    if (_driverUserId == null) return;
    setState(() => _savingTruck = true);

    final fields = <String, String>{
      if (_truckNumberCtrl.text.trim().isNotEmpty) 'truck_number': _truckNumberCtrl.text.trim(),
      if (_truckType != null) 'truck_type': _truckType!,
      if (_permitTypeCtrl.text.trim().isNotEmpty) 'permit_type': _permitTypeCtrl.text.trim(),
      if (_permitExpiry != null) 'permit_expiry': _fmtDate(_permitExpiry!),
      if (_truckLicenseExpiry != null) 'license_expiry': _fmtDate(_truckLicenseExpiry!),
      if (_insuranceExpiry != null) 'insurance_expiry': _fmtDate(_insuranceExpiry!),
      if (_inspectionExpiry != null) 'technical_inspection_expiry': _fmtDate(_inspectionExpiry!),
    };
    final files = <String, MapEntry<Uint8List, String>>{};
    if (_truckLicenseFile?.bytes != null) {
      files['license_file'] = MapEntry(_truckLicenseFile!.bytes!, _truckLicenseFile!.name);
    }
    if (_insuranceFile?.bytes != null) {
      files['insurance_file'] = MapEntry(_insuranceFile!.bytes!, _insuranceFile!.name);
    }
    if (_inspectionFile?.bytes != null) {
      files['technical_inspection_file'] = MapEntry(_inspectionFile!.bytes!, _inspectionFile!.name);
    }

    final result = await _service.updateMyTruck(
      driverUserId: _driverUserId!,
      fields: fields,
      files: files,
    );
    if (!mounted) return;
    setState(() => _savingTruck = false);
    _showBanner(result['message']?.toString() ?? '', isError: result['success'] != true);
  }

  Future<void> _saveCompanyInfo() async {
    setState(() => _savingCompanyInfo = true);
    final fields = <String, dynamic>{
      if (_companyNameCtrl.text.trim().isNotEmpty) 'name': _companyNameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
    };
    final result = await _service.updateCompanyInfo(fields);
    if (!mounted) return;
    setState(() => _savingCompanyInfo = false);
    _showBanner(result['message']?.toString() ?? '', isError: result['success'] != true);
  }

  Future<void> _pickCompanyLicense() async {
    if (_companyLicenseExpiry == null) {
      _showBanner('Select the trade license expiry date first', isError: true);
      return;
    }
    final f = await _pickFile();
    if (f == null || f.bytes == null) return;
    setState(() {
      _companyLicenseFile = f;
      _savingLicense = true;
    });
    final result = await _service.submitCompanyLicense(
      fileBytes: f.bytes!,
      fileName: f.name,
      expiryDate: _fmtDate(_companyLicenseExpiry!),
    );
    if (!mounted) return;
    setState(() => _savingLicense = false);
    _showBanner(result['message']?.toString() ?? '', isError: result['success'] != true);
  }

  Future<void> _resubmit() async {
    setState(() => _resubmitting = true);
    final result = _isCompany
        ? await _service.resubmitCompanyApplication()
        : await _service.resubmitDriverApplication();
    if (!mounted) return;
    setState(() => _resubmitting = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submitted for review — please log in again to see your status')),
      );
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context, true);
    } else {
      _showBanner(result['message']?.toString() ?? 'Could not resubmit', isError: true);
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
        title: const Text('Update Application', style: TextStyle(color: LightColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: _loadingProfile
            ? const Center(child: CircularProgressIndicator(color: LightColors.gold))
            : _loadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_loadError!, textAlign: TextAlign.center, style: const TextStyle(color: LightColors.error)),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if ((widget.rejectionReason ?? '').isNotEmpty || widget.documentIssues.isNotEmpty) ...[
                          _ReasonCard(reason: widget.rejectionReason, issues: widget.documentIssues),
                          const SizedBox(height: 20),
                        ],
                        if (_banner != null) ...[
                          _bannerIsError ? LightErrorBanner(message: _banner!) : _SuccessBanner(message: _banner!),
                          const SizedBox(height: 16),
                        ],
                        if (_isCompany) ..._companySections() else ..._driverSections(),
                        const SizedBox(height: 28),
                        LightPrimaryButton(
                          label: 'Resubmit for Review',
                          color: LightColors.gold,
                          textColor: LightColors.textPrimary,
                          loading: _resubmitting,
                          onPressed: _resubmit,
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  List<Widget> _driverSections() {
    return [
      const _SectionTitle('Driver Information'),
      const SizedBox(height: 12),
      LightPickerField(
        label: 'Nationality',
        hint: 'Select nationality',
        value: _nationality?.name,
        icon: Icons.public,
        onTap: () async {
          final picked = await _pickCountry();
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
      buildLightTextField(controller: _licenseCtrl, label: 'Driver License Number'),
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
      buildLightTextField(controller: _healthCtrl, label: 'Health Conditions (optional)', maxLines: 3),
      const SizedBox(height: 14),
      LightPrimaryButton(label: 'Save Driver Information', loading: _savingDriverInfo, onPressed: _saveDriverInfo),

      const SizedBox(height: 28),
      const _SectionTitle('Documents & Destinations'),
      const SizedBox(height: 12),
      _LinkCard(
        icon: Icons.folder_open_rounded,
        label: 'Update documents',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverDocumentsPage())),
      ),
      const SizedBox(height: 10),
      _LinkCard(
        icon: Icons.map_outlined,
        label: 'Update work destinations',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverDestinationsPage())),
      ),

      const SizedBox(height: 28),
      const _SectionTitle('Truck Information'),
      const SizedBox(height: 12),
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
      buildLightTextField(controller: _truckNumberCtrl, label: 'Truck Plate / Number'),
      const SizedBox(height: 14),
      buildLightTextField(controller: _permitTypeCtrl, label: 'Permit Type (optional)'),
      const SizedBox(height: 14),
      LightPickerField(
        label: 'Permit Expiry',
        hint: 'dd/mm/yyyy',
        value: _permitExpiry == null ? null : _fmtDate(_permitExpiry!),
        icon: Icons.event_outlined,
        onTap: () async {
          final d = await _pickDate(_permitExpiry);
          if (d != null) setState(() => _permitExpiry = d);
        },
      ),

      const SizedBox(height: 20),
      const _SubLabel2('Vehicle registration'),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: LightPickerField(
              label: 'Upload',
              hint: 'PDF/JPG/PNG (optional)',
              value: _truckLicenseFile?.name,
              icon: Icons.upload_file_outlined,
              onTap: () async {
                final f = await _pickFile();
                if (f != null) setState(() => _truckLicenseFile = f);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: LightPickerField(
              label: 'Expiry',
              hint: 'dd/mm/yyyy',
              value: _truckLicenseExpiry == null ? null : _fmtDate(_truckLicenseExpiry!),
              icon: Icons.event_outlined,
              onTap: () async {
                final d = await _pickDate(_truckLicenseExpiry);
                if (d != null) setState(() => _truckLicenseExpiry = d);
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      const _SubLabel2('Insurance'),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: LightPickerField(
              label: 'Upload',
              hint: 'PDF/JPG/PNG (optional)',
              value: _insuranceFile?.name,
              icon: Icons.upload_file_outlined,
              onTap: () async {
                final f = await _pickFile();
                if (f != null) setState(() => _insuranceFile = f);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: LightPickerField(
              label: 'Expiry',
              hint: 'dd/mm/yyyy',
              value: _insuranceExpiry == null ? null : _fmtDate(_insuranceExpiry!),
              icon: Icons.event_outlined,
              onTap: () async {
                final d = await _pickDate(_insuranceExpiry);
                if (d != null) setState(() => _insuranceExpiry = d);
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      const _SubLabel2('Technical inspection'),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: LightPickerField(
              label: 'Upload',
              hint: 'PDF/JPG/PNG (optional)',
              value: _inspectionFile?.name,
              icon: Icons.upload_file_outlined,
              onTap: () async {
                final f = await _pickFile();
                if (f != null) setState(() => _inspectionFile = f);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: LightPickerField(
              label: 'Expiry',
              hint: 'dd/mm/yyyy',
              value: _inspectionExpiry == null ? null : _fmtDate(_inspectionExpiry!),
              icon: Icons.event_outlined,
              onTap: () async {
                final d = await _pickDate(_inspectionExpiry);
                if (d != null) setState(() => _inspectionExpiry = d);
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      LightPrimaryButton(label: 'Save Truck Information', loading: _savingTruck, onPressed: _saveTruck),
    ];
  }

  List<Widget> _companySections() {
    return [
      const _SectionTitle('Company Information'),
      const SizedBox(height: 12),
      buildLightTextField(controller: _companyNameCtrl, label: 'Company Name'),
      const SizedBox(height: 14),
      buildLightTextField(controller: _phoneCtrl, label: 'Phone Number', keyboardType: TextInputType.phone),
      const SizedBox(height: 14),
      buildLightTextField(controller: _addressCtrl, label: 'Company Address', maxLines: 3),
      const SizedBox(height: 14),
      LightPrimaryButton(label: 'Save Company Information', loading: _savingCompanyInfo, onPressed: _saveCompanyInfo),

      const SizedBox(height: 28),
      const _SectionTitle('Company Documents'),
      const SizedBox(height: 12),
      LightPickerField(
        label: 'Trade License Expiry',
        hint: 'dd/mm/yyyy',
        value: _companyLicenseExpiry == null ? null : _fmtDate(_companyLicenseExpiry!),
        icon: Icons.event_outlined,
        onTap: () async {
          final d = await _pickDate(_companyLicenseExpiry);
          if (d != null) setState(() => _companyLicenseExpiry = d);
        },
      ),
      const SizedBox(height: 14),
      LightPickerField(
        label: 'Trade License',
        hint: _savingLicense ? 'Uploading…' : 'PDF/JPG/PNG',
        value: _companyLicenseFile?.name,
        icon: Icons.upload_file_outlined,
        onTap: _savingLicense ? () {} : _pickCompanyLicense,
      ),
    ];
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w800));
  }
}

class _SubLabel2 extends StatelessWidget {
  final String text;
  const _SubLabel2(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600));
  }
}

class _LinkCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _LinkCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: LightColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: LightColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: LightColors.goldMuted, size: 18),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(color: LightColors.textPrimary, fontSize: 14))),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFA0A4AC)),
          ],
        ),
      ),
    );
  }
}

class _ReasonCard extends StatelessWidget {
  final String? reason;
  final List<String> issues;
  const _ReasonCard({required this.reason, required this.issues});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LightColors.pendingBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LightColors.pending.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reason from Admin', style: TextStyle(color: Color(0xFF8A6D1F), fontSize: 13, fontWeight: FontWeight.w700)),
          if (reason != null && reason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(reason!, style: const TextStyle(color: Color(0xFF8A6D1F), fontSize: 13, height: 1.4)),
          ],
          if (issues.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...issues.map((i) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('•  $i', style: const TextStyle(color: Color(0xFF8A6D1F), fontSize: 13)),
                )),
          ],
        ],
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  final String message;
  const _SuccessBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: LightColors.successBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LightColors.success.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: LightColors.success, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13, color: LightColors.success))),
        ],
      ),
    );
  }
}
