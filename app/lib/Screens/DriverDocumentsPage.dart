import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../API/DriverService.dart';
import '../API/config.dart';
import '../models/DriverDocument.dart';

/// UC-8: driver uploads/renews their own documents (license, passport,
/// residency, ID card, medical certificate). Append-only on the server —
/// uploading a new one just supersedes the previous "current" version of
/// the same type, it's never deleted.
class DriverDocumentsPage extends StatefulWidget {
  const DriverDocumentsPage({super.key});

  @override
  State<DriverDocumentsPage> createState() => _DriverDocumentsPageState();
}

class _DriverDocumentsPageState extends State<DriverDocumentsPage> {
  late Future<List<DriverDocument>> _documentsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() => _documentsFuture = DriverService.fetchMyDocuments());

  /// Only the current (latest) version of each type is shown as the
  /// "status" row — older versions are still counted so we can show a
  /// small history count, but aren't individually listed here.
  Map<String, DriverDocument?> _currentByType(List<DriverDocument> docs) {
    final map = <String, DriverDocument?>{
      for (final t in kDriverDocumentTypes) t.key: null,
    };
    for (final d in docs) {
      if (d.isCurrent) map[d.type] = d;
    }
    return map;
  }

  Future<void> _openUploadSheet(String type) async {
    PlatformFile? pickedFile;
    DateTime? expiryDate;
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Upload ${driverDocumentTypeLabel(type)}',
                    style: const TextStyle(
                        color: AppColors.cream, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                        withData: true,
                      );
                      if (result != null && result.files.isNotEmpty) {
                        setSheetState(() => pickedFile = result.files.single);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: pickedFile == null ? AppColors.border : AppColors.gold,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            pickedFile == null
                                ? Icons.upload_file_outlined
                                : Icons.check_circle_outline,
                            color: pickedFile == null ? AppColors.muted : AppColors.gold,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              pickedFile?.name ?? 'Choose file (PDF/JPG/PNG)',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: pickedFile == null ? AppColors.muted : AppColors.cream,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now().add(const Duration(days: 365)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 15)),
                      );
                      if (picked != null) setSheetState(() => expiryDate = picked);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_outlined, color: AppColors.muted, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            expiryDate == null
                                ? 'Expiry date (optional)'
                                : '${expiryDate!.year}-${expiryDate!.month.toString().padLeft(2, '0')}-${expiryDate!.day.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: expiryDate == null ? AppColors.muted : AppColors.cream,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                      onPressed: (saving || pickedFile?.bytes == null)
                          ? null
                          : () async {
                              setSheetState(() => saving = true);
                              final result = await DriverService.uploadMyDocument(
                                type: type,
                                fileBytes: pickedFile!.bytes!,
                                fileName: pickedFile!.name,
                                expiryDate: expiryDate,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (!mounted) return;
                              if (result['success'] == true) {
                                _refresh();
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(result['message']?.toString() ?? '')),
                              );
                            },
                      child: saving
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg),
                            )
                          : const Text('Upload', style: TextStyle(color: AppColors.bg, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text('My Documents', style: TextStyle(color: AppColors.cream)),
        iconTheme: const IconThemeData(color: AppColors.cream),
      ),
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<DriverDocument>>(
          future: _documentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.gold));
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('Could not load documents', style: const TextStyle(color: AppColors.error)),
              );
            }

            final currentByType = _currentByType(snapshot.data ?? []);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Missing or expired mandatory documents (license, passport, residency) will block your account from being matched with shipments.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
                ...kDriverDocumentTypes.map((docType) {
                  final current = currentByType[docType.key];
                  final isExpired = current?.isExpired ?? false;
                  final statusColor = current == null
                      ? AppColors.muted
                      : (isExpired ? AppColors.error : AppColors.success);
                  final statusLabel = current == null
                      ? 'Not uploaded'
                      : (isExpired ? 'Expired' : 'On file');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.description_outlined, color: statusColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                docType.label,
                                style: const TextStyle(
                                    color: AppColors.cream, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  if (current?.expiryDate != null) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      'exp. ${current!.expiryDate!.year}-${current.expiryDate!.month.toString().padLeft(2, '0')}-${current.expiryDate!.day.toString().padLeft(2, '0')}',
                                      style: const TextStyle(color: AppColors.muted, fontSize: 11),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _openUploadSheet(docType.key),
                          child: Text(
                            current == null ? 'Upload' : 'Renew',
                            style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}
