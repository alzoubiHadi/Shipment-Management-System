import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../API/ShipmentServices.dart';
import '../API/config.dart';
import '../models/Shipment.dart';
import 'register_shared.dart';

/// Company redesign Phase 4 (2026-08-17 mockup): the "Proof of Delivery"
/// review screen — shows the driver's captured delivery document + recipient
/// name, and lets the company confirm receipt (pays the driver) or report a
/// problem instead, replacing the plain AlertDialog
/// ShipmentDetailsPageCompany used before.
///
/// Feature (2026-08-25): the driver now attaches a POD photo/file
/// (pod_document_path) instead of drawing a signature. Older shipments
/// delivered before this change may still only have the legacy
/// pod_signature (base64), so this screen shows the document when present
/// and falls back to the signature image otherwise.
class ProofOfDeliveryPage extends StatefulWidget {
  final Shipment shipment;
  const ProofOfDeliveryPage({super.key, required this.shipment});

  @override
  State<ProofOfDeliveryPage> createState() => _ProofOfDeliveryPageState();
}

class _ProofOfDeliveryPageState extends State<ProofOfDeliveryPage> {
  final _service = ShipmentService();
  bool _busy = false;

  Future<void> _confirm() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LightColors.surface,
        title: const Text('Confirm Receipt', style: TextStyle(color: LightColors.textPrimary, fontWeight: FontWeight.w700)),
        content: const Text(
          "Confirming pays the driver immediately for this shipment. Make sure you've reviewed the signature and recipient above first.",
          style: TextStyle(color: LightColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: LightColors.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm', style: TextStyle(color: LightColors.goldMuted, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    final result = await _service.confirmDelivery(shipmentId: widget.shipment.id);
    if (!mounted) return;
    setState(() => _busy = false);

    if (result['success'] == true) {
      final updated = Shipment.fromJson(result['shipment']);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery confirmed — driver has been paid'), backgroundColor: LightColors.success),
      );
      Navigator.pop(context, updated);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Failed')),
      );
    }
  }

  Future<void> _reportProblem() async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LightColors.surface,
        title: const Text('Report a Problem', style: TextStyle(color: LightColors.textPrimary, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          style: const TextStyle(color: LightColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'What went wrong? (missing items, damage, ...)',
            hintStyle: TextStyle(color: LightColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Back', style: TextStyle(color: LightColors.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, reasonCtrl.text.trim()), child: const Text('Submit', style: TextStyle(color: LightColors.error, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;

    setState(() => _busy = true);
    final result = await _service.disputeDelivery(shipmentId: widget.shipment.id, reason: reason);
    if (!mounted) return;
    setState(() => _busy = false);

    if (result['success'] == true) {
      final updated = Shipment.fromJson(result['shipment']);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reported — an admin will review this delivery'), backgroundColor: LightColors.pending),
      );
      Navigator.pop(context, updated);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.shipment;
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: LightColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: LightColors.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row('Recipient', s.podRecipientName.isEmpty ? '—' : s.podRecipientName),
                  const Divider(color: LightColors.border, height: 20),
                  _row('Delivery Date & Time', s.delivered_at.isEmpty ? '—' : s.delivered_at),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Delivery Document', style: TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: LightColors.border)),
              child: _buildPodPreview(s),
            ),
            const SizedBox(height: 28),
            if (s.isAwaitingCompanyConfirmation) ...[
              LightPrimaryButton(label: 'Confirm Delivery', color: LightColors.gold, textColor: LightColors.textPrimary, loading: _busy, onPressed: _confirm),
              const SizedBox(height: 10),
              LightOutlineButton(label: 'Report a Problem', color: LightColors.error, onPressed: _busy ? null : _reportProblem),
            ] else if (s.isDeliveryConfirmed)
              const _StatusNote(icon: Icons.check_circle_rounded, color: LightColors.success, text: 'Delivery confirmed — driver has been paid.')
            else if (s.isDeliveryDisputed)
              const _StatusNote(icon: Icons.error_rounded, color: LightColors.error, text: 'Reported — under admin review.'),
          ],
        ),
      ),
    );
  }

  Widget _buildPodPreview(Shipment s) {
    if (s.podDocumentPath.isNotEmpty) {
      final ext = s.podDocumentPath.split('.').last.toLowerCase();
      final isImage = ext == 'jpg' || ext == 'jpeg' || ext == 'png';
      final url = storageUrl(s.podDocumentPath);
      if (isImage) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            url,
            height: 220,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('Could not load delivery document', style: TextStyle(color: LightColors.textSecondary))),
            ),
          ),
        );
      }
      return InkWell(
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.picture_as_pdf_outlined, color: LightColors.gold, size: 24),
              SizedBox(width: 8),
              Text('View delivery document', style: TextStyle(color: LightColors.gold, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    if (s.podSignature.isNotEmpty) {
      return Image.memory(base64Decode(s.podSignature), height: 160);
    }

    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(child: Text('No delivery document captured', style: TextStyle(color: LightColors.textSecondary))),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 140, child: Text(label, style: const TextStyle(color: LightColors.textSecondary, fontSize: 12.5))),
        Expanded(child: Text(value, style: const TextStyle(color: LightColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600))),
      ],
    );
  }
}

class _StatusNote extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _StatusNote({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
