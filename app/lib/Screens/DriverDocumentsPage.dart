import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../API/DriverService.dart';
import '../API/TruckService.dart';
import '../API/config.dart';
import '../models/DriverDocument.dart';
import '../models/Truck.dart';

enum DriverDocTab { driver, truck }

/// UC-8: driver uploads/renews their own documents (license, passport,
/// residency, ID card, medical certificate). Append-only on the server —
/// uploading a new one just supersedes the previous "current" version of
/// the same type, it's never deleted.
///
/// Driver redesign Phase 4 (2026-08-17 mockup): added a "Truck Documents"
/// tab alongside the original driver-documents list.
///
/// Unified Approvals redesign (2026-08-22): Truck Documents is no longer
/// read-only — TruckController::uploadMyTruckDocument now gives trucks the
/// same always-available renewal path driver documents already had,
/// creating a real TruckDocument row (status='pending_review') plus a
/// ProfileEditRequest that shows up in Admin > Approvals > Document
/// Renewals. (The older `updateMyTruck` edit-during-changes_required path
/// is untouched and still used by ChangesRequiredEditScreen.)
class DriverDocumentsPage extends StatefulWidget {
  final DriverDocTab initialTab;
  const DriverDocumentsPage({super.key, this.initialTab = DriverDocTab.driver});

  @override
  State<DriverDocumentsPage> createState() => _DriverDocumentsPageState();
}

class _DriverDocumentsPageState extends State<DriverDocumentsPage> {
  late Future<List<DriverDocument>> _documentsFuture;
  late Future<List<Truck>> _trucksFuture;
  late DriverDocTab _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _refresh();
    _trucksFuture = TruckService().fetchMyTrucks();
  }

  void _refresh() => setState(() => _documentsFuture = DriverService.fetchMyDocuments());

  Future<void> _viewFile(String? path) async {
    if (path == null || path.isEmpty) return;
    final launched = await launchUrl(Uri.parse(storageUrl(path)), mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open file')));
    }
  }

  _ExpiryState _expiryState(DateTime? date) {
    if (date == null) return _ExpiryState('—', AppColors.muted);
    final daysLeft = date.difference(DateTime.now()).inDays;
    if (daysLeft < 0) return _ExpiryState('Expired', AppColors.error);
    if (daysLeft <= 30) return _ExpiryState('Expires Soon', AppColors.gold);
    return _ExpiryState('Valid', AppColors.success);
  }

  String _fmt(DateTime? d) => d == null ? '—' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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

  /// Compliance/Approval separation feature (2026-08-23): the NOT-current
  /// row (if any) representing a renewal already submitted for this type —
  /// 'pending_review' (awaiting admin) or 'changes_required' (admin asked
  /// for a re-upload). Prefers 'changes_required' if somehow both exist,
  /// since that's the more actionable state.
  Map<String, DriverDocument?> _pendingByType(List<DriverDocument> docs) {
    final map = <String, DriverDocument?>{
      for (final t in kDriverDocumentTypes) t.key: null,
    };
    for (final d in docs) {
      if (d.isCurrent) continue;
      if (d.status != 'pending_review' && d.status != 'changes_required') continue;
      final existing = map[d.type];
      if (existing == null || d.status == 'changes_required') {
        map[d.type] = d;
      }
    }
    return map;
  }

  /// (label, color) for the status chip — pending/changes-required (a
  /// separate, not-current row) takes priority over the current row's own
  /// valid/expiring_soon/expired status, since it's the more actionable
  /// thing to tell the driver about.
  (String, Color) _documentStatusDisplay(DriverDocument? current, DriverDocument? pending) {
    if (pending?.status == 'changes_required') return ('Changes Required', AppColors.error);
    if (pending?.status == 'pending_review') return ('Pending Review', AppColors.info);
    if (current == null) return ('Not Uploaded', AppColors.muted);
    return switch (current.status) {
      'expired' => ('Expired', AppColors.error),
      'expiring_soon' => ('Expiring Soon', AppColors.gold),
      _ => ('Valid', AppColors.success),
    };
  }

  /// "12d left" / "Expires today" / "3d overdue" — null when there's no
  /// expiry date to compute from at all.
  String? _daysRemainingLabel(DriverDocument? doc) {
    final days = doc?.daysRemaining;
    if (days == null) return null;
    if (days < 0) return '${-days}d overdue';
    if (days == 0) return 'Expires today';
    return '${days}d left';
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

  Future<void> _openTruckUploadSheet(String type, String label) async {
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
                    'Renew $label',
                    style: const TextStyle(color: AppColors.cream, fontSize: 18, fontWeight: FontWeight.w700),
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
                        border: Border.all(color: pickedFile == null ? AppColors.border : AppColors.gold),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            pickedFile == null ? Icons.upload_file_outlined : Icons.check_circle_outline,
                            color: pickedFile == null ? AppColors.muted : AppColors.gold,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              pickedFile?.name ?? 'Choose file (PDF/JPG/PNG)',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: pickedFile == null ? AppColors.muted : AppColors.cream, fontSize: 13),
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
                        border: Border.all(color: expiryDate == null ? AppColors.border : AppColors.gold),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_outlined, color: AppColors.muted, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            expiryDate == null
                                ? 'New expiry date'
                                : '${expiryDate!.year}-${expiryDate!.month.toString().padLeft(2, '0')}-${expiryDate!.day.toString().padLeft(2, '0')}',
                            style: TextStyle(color: expiryDate == null ? AppColors.muted : AppColors.cream, fontSize: 13),
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
                      onPressed: (saving || pickedFile?.bytes == null || expiryDate == null)
                          ? null
                          : () async {
                              setSheetState(() => saving = true);
                              final result = await TruckService.uploadMyTruckDocument(
                                type: type,
                                fileBytes: pickedFile!.bytes!,
                                fileName: pickedFile!.name,
                                expiryDate: expiryDate!,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (!mounted) return;
                              if (result['success'] == true) {
                                setState(() => _trucksFuture = TruckService().fetchMyTrucks());
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
                          : const Text('Submit for Review', style: TextStyle(color: AppColors.bg, fontWeight: FontWeight.w600)),
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _DocTabChip(
                    label: 'Driver Documents',
                    active: _tab == DriverDocTab.driver,
                    onTap: () => setState(() => _tab = DriverDocTab.driver),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DocTabChip(
                    label: 'Truck Documents',
                    active: _tab == DriverDocTab.truck,
                    onTap: () => setState(() => _tab = DriverDocTab.truck),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _tab == DriverDocTab.driver ? _buildDriverDocs() : _buildTruckDocs(),
          ),
        ],
      ),
    );
  }

  Widget _buildTruckDocs() {
    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () async => setState(() => _trucksFuture = TruckService().fetchMyTrucks()),
      child: FutureBuilder<List<Truck>>(
        future: _trucksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load truck documents', style: TextStyle(color: AppColors.error)));
          }

          final trucks = snapshot.data ?? [];
          if (trucks.isEmpty) {
            return ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: Text('No truck registered yet', style: TextStyle(color: AppColors.muted))),
                ),
              ],
            );
          }

          final docs = [
            ('license', 'Vehicle License', trucks.first.licenseExpiry, trucks.first.licenseFilePath),
            ('insurance', 'Insurance', trucks.first.insuranceExpiry, trucks.first.insuranceFilePath),
            ('technical_inspection', 'Technical Inspection', trucks.first.technicalInspectionExpiry, trucks.first.technicalInspectionFilePath),
          ];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Renewing a document here submits it for admin review — it applies once approved.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
              for (final (typeKey, label, expiry, path) in docs)
                Container(
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
                        decoration: BoxDecoration(color: _expiryState(expiry).color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.description_outlined, color: _expiryState(expiry).color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: const TextStyle(color: AppColors.cream, fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(color: _expiryState(expiry).color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                                  child: Text(_expiryState(expiry).label,
                                      style: TextStyle(color: _expiryState(expiry).color, fontSize: 10, fontWeight: FontWeight.w600)),
                                ),
                                const SizedBox(width: 6),
                                Text('exp. ${_fmt(expiry)}', style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if ((path ?? '').isNotEmpty)
                            TextButton(
                              onPressed: () => _viewFile(path),
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28)),
                              child: const Text('View', style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          TextButton(
                            onPressed: () => _openTruckUploadSheet(typeKey, label),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28)),
                            child: const Text('Renew', style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDriverDocs() {
    return RefreshIndicator(
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

            final docs = snapshot.data ?? [];
            final currentByType = _currentByType(docs);
            final pendingByType = _pendingByType(docs);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Missing, expired, or expiring-soon mandatory documents (license, passport, residency) will block your account from being matched with shipments until renewed and approved.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
                ...kDriverDocumentTypes.map((docType) {
                  final current = currentByType[docType.key];
                  final pending = pendingByType[docType.key];
                  final (statusLabel, statusColor) = _documentStatusDisplay(current, pending);
                  final daysLabel = _daysRemainingLabel(current);

                  // Renew is shown for a never-uploaded type (as "Upload"),
                  // an expiring/expired current document, or when an admin
                  // has asked for changes on a submitted renewal — not
                  // while a renewal is simply pending_review (nothing to
                  // do until the admin decides) or already valid.
                  final showActionButton = current == null ||
                      current.status == 'expiring_soon' ||
                      current.status == 'expired' ||
                      pending?.status == 'changes_required';

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
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 4,
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
                                  if (current?.expiryDate != null)
                                    Text(
                                      'exp. ${_fmt(current!.expiryDate)}',
                                      style: const TextStyle(color: AppColors.muted, fontSize: 11),
                                    ),
                                  if (daysLabel != null)
                                    Text(
                                      daysLabel,
                                      style: TextStyle(
                                        color: (current?.daysRemaining ?? 1) < 0 ? AppColors.error : AppColors.muted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (showActionButton)
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
      );
  }
}

class _DocTabChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _DocTabChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.gold : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: active ? AppColors.gold : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12.5, color: active ? AppColors.bg : AppColors.muted, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }
}

class _ExpiryState {
  final String label;
  final Color color;
  _ExpiryState(this.label, this.color);
}
