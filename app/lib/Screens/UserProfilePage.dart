import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../API/ProfileService.dart';
import '../API/config.dart';
import '../models/Appuser.dart';
import '../models/ProfileEditRequest.dart';
import 'DriverDestinationsPage.dart';
import 'DriverDocumentsPage.dart';

/// Reached by tapping the user's name in the top app bar (any role).
/// Admin: avatar + basic info only. Driver/Company: also links into their
/// documents/destinations/license renewal, all of which are material to
/// eligibility and therefore go through admin approval before they apply
/// — see the "My requests" section below for the review status.
class UserProfilePage extends StatefulWidget {
  final AppUser user;
  const UserProfilePage({super.key, required this.user});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _service = ProfileService();
  late Future<Map<String, dynamic>> _profileFuture;
  late Future<List<ProfileEditRequest>> _requestsFuture;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _savingBasic = false;
  bool _uploadingAvatar = false;
  bool _submittingLicense = false;
  String? _avatarPath;

  bool get _isDriver => widget.user.role.toLowerCase() == 'driver';
  bool get _isCompany => widget.user.role.toLowerCase() == 'company';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _profileFuture = _service.fetchMyProfile().then((data) {
        _nameCtrl.text = data['name']?.toString() ?? '';
        _phoneCtrl.text = data['phone']?.toString() ?? '';
        _emailCtrl.text = data['email']?.toString() ?? '';
        _avatarPath = data['avatar_path']?.toString();
        return data;
      });
      if (_isDriver || _isCompany) {
        _requestsFuture = _service.fetchMyEditRequests();
      } else {
        _requestsFuture = Future.value(<ProfileEditRequest>[]);
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty || result.files.single.bytes == null) return;

    setState(() => _uploadingAvatar = true);
    final r = await _service.uploadAvatar(
      fileBytes: result.files.single.bytes!,
      fileName: result.files.single.name,
    );
    if (!mounted) return;
    setState(() => _uploadingAvatar = false);
    if (r['success'] == true) {
      setState(() => _avatarPath = r['avatar_path']?.toString());
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(r['message']?.toString() ?? '')),
    );
  }

  Future<void> _saveBasic() async {
    setState(() => _savingBasic = true);
    final r = await _service.updateBasic(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _savingBasic = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(r['message']?.toString() ?? '')),
    );
  }

  Future<void> _renewLicense() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || result.files.single.bytes == null) return;

    setState(() => _submittingLicense = true);
    final r = await _service.submitCompanyLicense(
      fileBytes: result.files.single.bytes!,
      fileName: result.files.single.name,
    );
    if (!mounted) return;
    setState(() => _submittingLicense = false);
    if (r['success'] == true) _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(r['message']?.toString() ?? '')),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.gold;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.cream),
        title: const Text('My Profile', style: TextStyle(color: AppColors.cream)),
      ),
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async => _refresh(),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.gold));
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('Could not load profile', style: const TextStyle(color: AppColors.error)),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: InkWell(
                    onTap: _uploadingAvatar ? null : _pickAvatar,
                    borderRadius: BorderRadius.circular(50),
                    child: Stack(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surfaceHigh,
                            border: Border.all(color: AppColors.gold.withOpacity(0.4), width: 1.5),
                            image: _avatarPath != null
                                ? DecorationImage(image: NetworkImage(storageUrl(_avatarPath!)), fit: BoxFit.cover)
                                : null,
                          ),
                          child: _avatarPath == null
                              ? const Icon(Icons.person_outline, color: AppColors.muted, size: 40)
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                            child: _uploadingAvatar
                                ? const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg),
                                  )
                                : const Icon(Icons.camera_alt_outlined, size: 15, color: AppColors.bg),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _field('Name', _nameCtrl),
                const SizedBox(height: 12),
                _field('Phone', _phoneCtrl, keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _field('Email', _emailCtrl, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 16),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                    onPressed: _savingBasic ? null : _saveBasic,
                    child: _savingBasic
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg),
                          )
                        : const Text('Save', style: TextStyle(color: AppColors.bg, fontWeight: FontWeight.w600)),
                  ),
                ),

                if (_isDriver) ...[
                  const SizedBox(height: 28),
                  const _SectionLabel('Eligibility'),
                  const SizedBox(height: 10),
                  _NavTile(
                    icon: Icons.description_outlined,
                    title: 'My Documents',
                    subtitle: 'Renew an expiring license, passport or residency',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverDocumentsPage())),
                  ),
                  const SizedBox(height: 8),
                  _NavTile(
                    icon: Icons.public_outlined,
                    title: 'Work Destinations',
                    subtitle: 'Change the countries you cover',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverDestinationsPage())),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'Changes to your documents or destinations need admin review before they apply.',
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                  ),
                ],

                if (_isCompany) ...[
                  const SizedBox(height: 28),
                  const _SectionLabel('Eligibility'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Trade License', style: TextStyle(color: AppColors.cream, fontWeight: FontWeight.w600, fontSize: 14)),
                              SizedBox(height: 3),
                              Text('Submit a renewed copy — applies once approved', style: TextStyle(color: AppColors.muted, fontSize: 11)),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _submittingLicense ? null : _renewLicense,
                          child: _submittingLicense
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold))
                              : const Text('Renew', style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_isDriver || _isCompany) ...[
                  const SizedBox(height: 28),
                  const _SectionLabel('My Requests'),
                  const SizedBox(height: 10),
                  FutureBuilder<List<ProfileEditRequest>>(
                    future: _requestsFuture,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
                        );
                      }
                      final items = snap.data ?? [];
                      if (items.isEmpty) {
                        return const Text('No submitted changes yet', style: TextStyle(color: AppColors.muted, fontSize: 12));
                      }
                      return Column(
                        children: items.map((r) {
                          final color = _statusColor(r.status);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border, width: 0.5),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(r.categoryLabel, style: const TextStyle(color: AppColors.cream, fontSize: 13)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                  child: Text(r.status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.cream),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.muted),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.gold, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppColors.cream, fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
