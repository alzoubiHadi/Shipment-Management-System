import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../API/DriverService.dart';
import '../API/TruckService.dart';
import '../API/config.dart';
import '../l10n/app_localizations.dart';
import '../l10n/enum_labels.dart';
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

  /// 2026-08-27 (security review, item 7): the truck's license/insurance/
  /// technical-inspection file moved to the private disk — fetched through
  /// the authenticated /trucks/{id}/file/{type} endpoint instead of a
  /// plain storage URL.
  Future<void> _viewFile(String truckId, String type) async {
    await viewSecureFile(context, '$baseUrl/trucks/$truckId/file/$type');
  }

  _ExpiryState _expiryState(AppLocalizations t, DateTime? date) {
    if (date == null) return _ExpiryState('—', LightColors.muted);
    final daysLeft = date.difference(DateTime.now()).inDays;
    if (daysLeft < 0) return _ExpiryState(t.docStatusExpired, LightColors.error);
    if (daysLeft <= 30) return _ExpiryState(t.docStatusExpiringSoon, LightColors.gold);
    return _ExpiryState(t.docStatusValid, LightColors.success);
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
  (String, Color) _documentStatusDisplay(AppLocalizations t, DriverDocument? current, DriverDocument? pending) {
    if (pending?.status == 'changes_required') return (t.docStatusChangesRequired, LightColors.error);
    if (pending?.status == 'pending_review') return (t.statusPendingReview, LightColors.info);
    if (current == null) return (t.docStatusNotUploaded, LightColors.muted);
    return switch (current.status) {
      'expired' => (t.docStatusExpired, LightColors.error),
      'expiring_soon' => (t.docStatusExpiringSoon, LightColors.gold),
      _ => (t.docStatusValid, LightColors.success),
    };
  }

  /// "12d left" / "Expires today" / "3d overdue" — null when there's no
  /// expiry date to compute from at all.
  String? _daysRemainingLabel(AppLocalizations t, DriverDocument? doc) {
    final days = doc?.daysRemaining;
    if (days == null) return null;
    if (days < 0) return t.daysOverdue(-days);
    if (days == 0) return t.expiresToday;
    return t.daysLeft(days);
  }

  Future<void> _openUploadSheet(String type) async {
    final t = AppLocalizations.of(context)!;
    PlatformFile? pickedFile;
    DateTime? expiryDate;
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: LightColors.surface,
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
                    t.uploadDialogTitle(localizedDriverDocType(driverDocumentTypeLabel(type))),
                    style: const TextStyle(
                        color: LightColors.cream, fontSize: 18, fontWeight: FontWeight.w700),
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
                        color: LightColors.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: pickedFile == null ? LightColors.border : LightColors.gold,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            pickedFile == null
                                ? Icons.upload_file_outlined
                                : Icons.check_circle_outline,
                            color: pickedFile == null ? LightColors.muted : LightColors.gold,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              pickedFile?.name ?? t.chooseFileHint,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: pickedFile == null ? LightColors.muted : LightColors.cream,
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
                        color: LightColors.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: LightColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_outlined, color: LightColors.muted, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            expiryDate == null
                                ? t.expiryDateOptionalHint
                                : '${expiryDate!.year}-${expiryDate!.month.toString().padLeft(2, '0')}-${expiryDate!.day.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: expiryDate == null ? LightColors.muted : LightColors.cream,
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
                      style: ElevatedButton.styleFrom(backgroundColor: LightColors.gold),
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
                              child: CircularProgressIndicator(strokeWidth: 2, color: LightColors.deepNavy),
                            )
                          : Text(t.uploadButton, style: const TextStyle(color: LightColors.deepNavy, fontWeight: FontWeight.w600)),
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
    final t = AppLocalizations.of(context)!;
    PlatformFile? pickedFile;
    DateTime? expiryDate;
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: LightColors.surface,
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
                    t.renewDialogTitle(label),
                    style: const TextStyle(color: LightColors.cream, fontSize: 18, fontWeight: FontWeight.w700),
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
                        color: LightColors.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: pickedFile == null ? LightColors.border : LightColors.gold),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            pickedFile == null ? Icons.upload_file_outlined : Icons.check_circle_outline,
                            color: pickedFile == null ? LightColors.muted : LightColors.gold,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              pickedFile?.name ?? t.chooseFileHint,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: pickedFile == null ? LightColors.muted : LightColors.cream, fontSize: 13),
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
                        color: LightColors.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: expiryDate == null ? LightColors.border : LightColors.gold),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_outlined, color: LightColors.muted, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            expiryDate == null
                                ? t.newExpiryDateHint
                                : '${expiryDate!.year}-${expiryDate!.month.toString().padLeft(2, '0')}-${expiryDate!.day.toString().padLeft(2, '0')}',
                            style: TextStyle(color: expiryDate == null ? LightColors.muted : LightColors.cream, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: LightColors.gold),
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
                              child: CircularProgressIndicator(strokeWidth: 2, color: LightColors.deepNavy),
                            )
                          : Text(t.submitForReviewButton, style: const TextStyle(color: LightColors.deepNavy, fontWeight: FontWeight.w600)),
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
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        title: Text(t.myDocumentsLabel, style: const TextStyle(color: LightColors.cream)),
        iconTheme: const IconThemeData(color: LightColors.cream),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _DocTabChip(
                    label: t.driverDocumentsTabLabel,
                    active: _tab == DriverDocTab.driver,
                    onTap: () => setState(() => _tab = DriverDocTab.driver),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DocTabChip(
                    label: t.truckDocumentsTabLabel,
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
      color: LightColors.gold,
      onRefresh: () async => setState(() => _trucksFuture = TruckService().fetchMyTrucks()),
      child: FutureBuilder<List<Truck>>(
        future: _trucksFuture,
        builder: (context, snapshot) {
          final t = AppLocalizations.of(context)!;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: LightColors.gold));
          }
          if (snapshot.hasError) {
            return Center(child: Text(t.couldNotLoadTruckDocs, style: const TextStyle(color: LightColors.error)));
          }

          final trucks = snapshot.data ?? [];
          if (trucks.isEmpty) {
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: Center(child: Text(t.noTruckRegisteredYet, style: const TextStyle(color: LightColors.muted))),
                ),
              ],
            );
          }

          final docs = [
            ('license', t.vehicleLicenseLabel, trucks.first.licenseExpiry, trucks.first.licenseFilePath),
            ('insurance', t.docTypeInsurance, trucks.first.insuranceExpiry, trucks.first.insuranceFilePath),
            ('technical_inspection', t.docTypeTechnicalInspection, trucks.first.technicalInspectionExpiry, trucks.first.technicalInspectionFilePath),
          ];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  t.renewingSubmitsForReviewNote,
                  style: const TextStyle(color: LightColors.muted, fontSize: 12),
                ),
              ),
              for (final (typeKey, label, expiry, path) in docs)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: LightColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: LightColors.border, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: _expiryState(t, expiry).color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.description_outlined, color: _expiryState(t, expiry).color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: const TextStyle(color: LightColors.cream, fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(color: _expiryState(t, expiry).color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                                  child: Text(_expiryState(t, expiry).label,
                                      style: TextStyle(color: _expiryState(t, expiry).color, fontSize: 10, fontWeight: FontWeight.w600)),
                                ),
                                const SizedBox(width: 6),
                                Text(t.expDateLabel(_fmt(expiry)), style: const TextStyle(color: LightColors.muted, fontSize: 11)),
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
                              onPressed: () => _viewFile(trucks.first.id, typeKey),
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28)),
                              child: Text(t.viewButton, style: const TextStyle(color: LightColors.gold, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          TextButton(
                            onPressed: () => _openTruckUploadSheet(typeKey, label),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28)),
                            child: Text(t.renewButton, style: const TextStyle(color: LightColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
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
        color: LightColors.gold,
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<DriverDocument>>(
          future: _documentsFuture,
          builder: (context, snapshot) {
            final t = AppLocalizations.of(context)!;
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: LightColors.gold));
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(t.couldNotLoadDocumentsMsg, style: const TextStyle(color: LightColors.error)),
              );
            }

            final docs = snapshot.data ?? [];
            final currentByType = _currentByType(docs);
            final pendingByType = _pendingByType(docs);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    t.mandatoryDocsBlockNote,
                    style: const TextStyle(color: LightColors.muted, fontSize: 12),
                  ),
                ),
                ...kDriverDocumentTypes.map((docType) {
                  final current = currentByType[docType.key];
                  final pending = pendingByType[docType.key];
                  final (statusLabel, statusColor) = _documentStatusDisplay(t, current, pending);
                  final daysLabel = _daysRemainingLabel(t, current);

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
                      color: LightColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: LightColors.border, width: 0.5),
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
                                localizedDriverDocType(docType.label),
                                style: const TextStyle(
                                    color: LightColors.cream, fontSize: 14, fontWeight: FontWeight.w600),
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
                                      t.expDateLabel(_fmt(current!.expiryDate)),
                                      style: const TextStyle(color: LightColors.muted, fontSize: 11),
                                    ),
                                  if (daysLabel != null)
                                    Text(
                                      daysLabel,
                                      style: TextStyle(
                                        color: (current?.daysRemaining ?? 1) < 0 ? LightColors.error : LightColors.muted,
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
                              current == null ? t.uploadButton : t.renewButton,
                              style: const TextStyle(color: LightColors.gold, fontSize: 12, fontWeight: FontWeight.w600),
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
          color: active ? LightColors.gold : LightColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: active ? LightColors.gold : LightColors.border),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12.5, color: active ? LightColors.deepNavy : LightColors.muted, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }
}

class _ExpiryState {
  final String label;
  final Color color;
  _ExpiryState(this.label, this.color);
}
