import 'package:flutter/material.dart';

import '../API/ProfileService.dart';
import '../API/config.dart';
import '../models/ProfileEditRequest.dart';

/// Document Renewals detail screen (Unified Approvals, 2026-08-22) — shown
/// per the spec's exact review layout: Old Document (file/expiry/status) on
/// top, New Document (file/new expiry/submitted date) below, then
/// Approve | Request Changes.
///
/// Approve calls ProfileController::approve(), which re-evaluates the
/// owner's full compliance server-side via ComplianceService and only
/// clears compliance_status back to 'active' if every document is valid —
/// see Driver::recomputeComplianceStatus()/Company::recomputeComplianceStatus().
/// Request Changes calls reject(), which marks the newly-uploaded document
/// row 'changes_required' without deleting the file, so the owner can see
/// why and re-upload.
class DocumentRenewalReviewScreen extends StatefulWidget {
  final ProfileEditRequest request;

  const DocumentRenewalReviewScreen({super.key, required this.request});

  @override
  State<DocumentRenewalReviewScreen> createState() => _DocumentRenewalReviewScreenState();
}

class _DocumentRenewalReviewScreenState extends State<DocumentRenewalReviewScreen> {
  final _service = ProfileService();
  bool _busy = false;

  /// 2026-08-27 (security review, item 7): renewal documents live in the
  /// driver_documents/truck_documents/company_documents history tables and
  /// moved to the private disk — this builds the right authenticated
  /// download endpoint for whichever table `request.category` points at
  /// and opens it, instead of resolving a plain storage URL.
  Future<void> _openFile(String? documentId) async {
    if (documentId == null || documentId.isEmpty) return;
    final prefix = switch (widget.request.category) {
      'truck_document' => 'truck-documents',
      'company_license' => 'company-documents',
      _ => 'driver-documents',
    };
    await viewSecureFile(context, '$baseUrl/$prefix/$documentId/file');
  }

  Future<void> _approve() async {
    setState(() => _busy = true);
    final result = await _service.approveEditRequest(widget.request.id);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']?.toString() ?? ''), backgroundColor: result['success'] == true ? LightColors.success : LightColors.error),
    );
    if (result['success'] == true) Navigator.pop(context, true);
  }

  Future<void> _requestChanges() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LightColors.surface,
        title: const Text('Request changes', style: TextStyle(color: LightColors.textPrimary, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: reasonCtrl,
          style: const TextStyle(color: LightColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Reason (e.g. blurry photo, wrong document, expired)',
            hintStyle: TextStyle(color: LightColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: LightColors.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send Back', style: TextStyle(color: LightColors.error, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    final result = await _service.rejectEditRequest(widget.request.id, reason: reasonCtrl.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']?.toString() ?? ''), backgroundColor: result['success'] == true ? LightColors.success : LightColors.error),
    );
    if (result['success'] == true) Navigator.pop(context, true);
  }

  String _fmt(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final old = r.oldDocument;
    final newExpiry = r.payload['expiry_date']?.toString();
    final newFile = r.payload['file_path']?.toString();
    final newDocumentId = r.payload['document_id']?.toString();

    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: LightColors.textPrimary),
        title: const Text('Document Renewal', style: TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(r.userName ?? 'User #${r.userId}', style: const TextStyle(color: LightColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(r.documentTypeLabel, style: const TextStyle(color: LightColors.goldMuted, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),

            const Text('Old Document', style: TextStyle(color: LightColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _DocumentCard(
              rows: old == null
                  ? const [MapEntry('Status', 'No previous document on file')]
                  : [
                      MapEntry('Expiry Date', _fmt(old['expiry_date']?.toString())),
                      MapEntry('Status', (old['status']?.toString() ?? '—')),
                    ],
              onPreview: old?['id'] != null ? () => _openFile(old!['id']?.toString()) : null,
            ),
            const SizedBox(height: 20),

            const Text('New Document', style: TextStyle(color: LightColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _DocumentCard(
              rows: [
                MapEntry('New Expiry Date', _fmt(newExpiry)),
                MapEntry('Submitted', _fmt(r.createdAt?.toIso8601String())),
                const MapEntry('Status', 'Pending Review'),
              ],
              onPreview: newFile != null ? () => _openFile(newDocumentId) : null,
            ),
            const SizedBox(height: 28),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _requestChanges,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: LightColors.error,
                      side: const BorderSide(color: LightColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Request Changes'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : _approve,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LightColors.gold,
                      foregroundColor: LightColors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: LightColors.textPrimary))
                        : const Text('Approve', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final List<MapEntry<String, String>> rows;
  final VoidCallback? onPreview;

  const _DocumentCard({required this.rows, this.onPreview});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LightColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LightColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(row.key, style: const TextStyle(color: LightColors.textSecondary, fontSize: 12.5)),
                  ),
                  Expanded(
                    child: Text(row.value, style: const TextStyle(color: LightColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          if (onPreview != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onPreview,
                icon: const Icon(Icons.open_in_new_rounded, size: 16, color: LightColors.goldMuted),
                label: const Text('Preview Document', style: TextStyle(color: LightColors.goldMuted, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
