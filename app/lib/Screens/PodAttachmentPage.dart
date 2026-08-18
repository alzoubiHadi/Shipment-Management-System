import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../API/config.dart';

/// Feature (2026-08-25): replaces SignatureCapturePage.dart (now dead code)
/// as the final step before marking a shipment delivered — the driver
/// attaches a proof-of-delivery document (a photo taken on the spot, or any
/// file already on the device: a scanned/photographed delivery note) instead
/// of drawing a signature on-screen. Returns
/// {'fileBytes': Uint8List, 'fileName': String, 'recipientName': String} via
/// Navigator.pop, or null if the driver backs out.
class PodAttachmentPage extends StatefulWidget {
  const PodAttachmentPage({super.key});

  @override
  State<PodAttachmentPage> createState() => _PodAttachmentPageState();
}

class _PodAttachmentPageState extends State<PodAttachmentPage> {
  final _nameController = TextEditingController();
  final _imagePicker = ImagePicker();

  Uint8List? _fileBytes;
  String? _fileName;
  bool _isImage = false;
  bool _isSaving = false;

  Future<void> _takePhoto() async {
    final photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (photo == null) return;

    final bytes = await photo.readAsBytes();
    if (!mounted) return;
    setState(() {
      _fileBytes = bytes;
      _fileName = photo.name.isNotEmpty ? photo.name : 'pod_photo.jpg';
      _isImage = true;
    });
  }

  Future<void> _chooseFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    if (picked.bytes == null) return;

    final ext = (picked.extension ?? '').toLowerCase();
    if (!mounted) return;
    setState(() {
      _fileBytes = picked.bytes;
      _fileName = picked.name;
      _isImage = ext == 'jpg' || ext == 'jpeg' || ext == 'png';
    });
  }

  void _clear() => setState(() {
        _fileBytes = null;
        _fileName = null;
        _isImage = false;
      });

  void _confirm() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the recipient name first')),
      );
      return;
    }
    if (_fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attach a photo or file of the delivery document first')),
      );
      return;
    }

    Navigator.pop(context, {
      'fileBytes': _fileBytes,
      'fileName': _fileName!,
      'recipientName': _nameController.text.trim(),
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: LightColors.textPrimary),
        title: const Text('Proof of Delivery',
            style: TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _nameController,
              style: const TextStyle(color: LightColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Recipient name',
                labelStyle: const TextStyle(color: LightColors.textSecondary),
                filled: true,
                fillColor: LightColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: LightColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: LightColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: LightColors.gold),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Attach the delivery document — photograph it now or upload an existing file',
              style: TextStyle(color: LightColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            if (_fileBytes == null) ...[
              Row(
                children: [
                  Expanded(
                    child: _AttachActionButton(
                      icon: Icons.camera_alt_outlined,
                      label: 'Take Photo',
                      onTap: _takePhoto,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AttachActionButton(
                      icon: Icons.upload_file_outlined,
                      label: 'Choose File',
                      onTap: _chooseFile,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LightColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: LightColors.gold),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isImage)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(_fileBytes!, height: 220, width: double.infinity, fit: BoxFit.cover),
                      )
                    else
                      Container(
                        height: 100,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: LightColors.bg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.picture_as_pdf_outlined, color: LightColors.gold, size: 40),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: LightColors.gold, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _fileName ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: LightColors.textPrimary, fontSize: 12.5),
                          ),
                        ),
                        TextButton(
                          onPressed: _clear,
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28)),
                          child: const Text('Remove', style: TextStyle(color: LightColors.error, fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: LightColors.gold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Confirm delivery',
                  style: TextStyle(color: LightColors.deepNavy, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AttachActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: LightColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: LightColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: LightColors.gold, size: 26),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
