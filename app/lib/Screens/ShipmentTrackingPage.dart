import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../API/ShipmentServices.dart';
import '../API/config.dart';
import '../models/Shipment.dart';
import 'SignatureCapturePage.dart';

/// Shows the 7-stage tracking timeline for a shipment:
/// 1 heading to pickup, 2 loaded, 3 en route to border, 4 border cleared,
/// 5 arrived at destination, 6 unloaded, 7 delivered (signed).
///
/// When [readOnly] is false (driver assigned to the shipment), a button lets
/// the driver push the shipment to the next stage, ending with a
/// proof-of-delivery signature capture. Admin/company view it as [readOnly].
class ShipmentTrackingPage extends StatefulWidget {
  final Shipment shipment;
  final bool readOnly;

  const ShipmentTrackingPage({
    super.key,
    required this.shipment,
    this.readOnly = false,
  });

  @override
  State<ShipmentTrackingPage> createState() => _ShipmentTrackingPageState();
}

class _ShipmentTrackingPageState extends State<ShipmentTrackingPage> {
  final _service = ShipmentService();
  late Shipment _shipment;
  bool _isUpdating = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _shipment = widget.shipment;

    // Read-only viewers (admin/company) don't cause the stage changes
    // themselves, so poll every few seconds to reflect the driver's
    // progress live without needing to reopen this page.
    if (widget.readOnly) {
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_shipment.currentStage >= 7 || _shipment.trackingNumber.isEmpty) {
      _pollTimer?.cancel();
      return;
    }
    final updated =
        await _service.fetchOneByTrackingNumber(_shipment.trackingNumber);
    if (!mounted || updated == null) return;
    setState(() => _shipment = updated);
    if (updated.currentStage >= 7) _pollTimer?.cancel();
  }

  Future<void> _advance() async {
    setState(() => _isUpdating = true);
    final result = await _service.advanceStage(shipmentId: _shipment.id);
    if (!mounted) return;
    setState(() => _isUpdating = false);

    if (result['success'] == true) {
      setState(() => _shipment = Shipment.fromJson(result['shipment']));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Failed')),
      );
    }
  }

  Future<void> _captureDelivery() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const SignatureCapturePage()),
    );

    if (result == null) return;

    setState(() => _isUpdating = true);
    final response = await _service.deliverShipment(
      shipmentId: _shipment.id,
      podSignatureBase64: result['signature'],
      recipientName: result['recipientName'],
    );
    if (!mounted) return;
    setState(() => _isUpdating = false);

    if (response['success'] == true) {
      setState(() => _shipment = Shipment.fromJson(response['shipment']));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Delivery recorded — awaiting company confirmation before payout'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message']?.toString() ?? 'Failed')),
      );
    }
  }

  Color _deliveryStatusColor(String status) {
    switch (status) {
      case 'awaiting_confirmation':
        return AppColors.gold;
      case 'confirmed':
        return AppColors.success;
      case 'disputed':
        return AppColors.error;
      default:
        return AppColors.muted;
    }
  }

  String _deliveryStatusLabel(String status) {
    switch (status) {
      case 'awaiting_confirmation':
        return 'Awaiting confirmation';
      case 'confirmed':
        return 'Confirmed';
      case 'disputed':
        return 'Disputed';
      default:
        return 'Not delivered';
    }
  }

  /// UC-22: driver flags a field problem on this shipment. Simple
  /// fire-and-forget text log — visible to the owning company and every
  /// admin (ShipmentController::listComments).
  Future<void> _addComment() async {
    final controller = TextEditingController();

    final comment = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Add a comment',
            style: TextStyle(color: AppColors.cream)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: AppColors.cream),
          decoration: const InputDecoration(
            hintText: 'e.g. truck breakdown, road closure...',
            hintStyle: TextStyle(color: AppColors.muted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );

    if (comment == null || comment.isEmpty) return;

    final result = await _service.addShipmentComment(
      shipmentId: _shipment.id,
      comment: comment,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['success'] == true
            ? 'Comment added'
            : (result['message']?.toString() ?? 'Failed to add comment')),
      ),
    );
  }

  String? _timestampFor(int stage) {
    switch (stage) {
      case 1:
        return _shipment.headingToPickupAt;
      case 2:
        return _shipment.loadedAt;
      case 3:
        return _shipment.departedToBorderAt;
      case 4:
        return _shipment.borderClearedAt;
      case 5:
        return _shipment.arrivedAtDestinationAt;
      case 6:
        return _shipment.unloadedAt;
      case 7:
        return _shipment.delivered_at;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _shipment.currentStage;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.cream),
        title: Text(
          _shipment.trackingNumber.isEmpty
              ? 'Shipment Tracking'
              : _shipment.trackingNumber,
          style: const TextStyle(color: AppColors.cream),
        ),
        actions: [
          if (!widget.readOnly)
            IconButton(
              onPressed: _addComment,
              icon: const Icon(Icons.comment_outlined, color: AppColors.cream),
              tooltip: 'Add comment',
            ),
          if (widget.readOnly && current < 7)
            const Padding(
              padding: EdgeInsets.only(left: 16),
              child: Center(
                child: _LiveBadge(),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, color: AppColors.gold),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_shipment.origin} → ${_shipment.destination}',
                    style: const TextStyle(
                      color: AppColors.cream,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          for (int stage = 1; stage <= 7; stage++)
            _StageRow(
              stage: stage,
              label: Shipment.stageLabels[stage]!,
              isDone: stage <= current,
              isActive: stage == current + 1 && current < 7,
              timestamp: _timestampFor(stage),
              isLast: stage == 7,
            ),

          if (current == 7) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Proof of delivery',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _deliveryStatusColor(_shipment.deliveryStatus)
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _deliveryStatusLabel(_shipment.deliveryStatus),
                          style: TextStyle(
                            color: _deliveryStatusColor(_shipment.deliveryStatus),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Received by: ${_shipment.podRecipientName}',
                    style: const TextStyle(color: AppColors.cream, fontSize: 14),
                  ),
                  if (_shipment.podSignature.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Image.memory(
                        base64Decode(_shipment.podSignature),
                        height: 120,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: (widget.readOnly || current == 7)
          ? null
          : Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isUpdating
                      ? null
                      : (current == 6 ? _captureDelivery : _advance),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isUpdating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.bg,
                          ),
                        )
                      : Text(
                          current == 6
                              ? 'Capture proof of delivery'
                              : 'Mark as: ${Shipment.stageLabels[current + 1]}',
                          style: const TextStyle(
                            color: AppColors.bg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
    );
  }
}

/// Small "Live" indicator shown to read-only viewers (admin/company) so
/// they know this screen refreshes itself automatically.
class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Live',
            style: TextStyle(
              color: AppColors.success,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  final int stage;
  final String label;
  final bool isDone;
  final bool isActive;
  final String? timestamp;
  final bool isLast;

  const _StageRow({
    required this.stage,
    required this.label,
    required this.isDone,
    required this.isActive,
    required this.timestamp,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDone
        ? AppColors.success
        : (isActive ? AppColors.gold : AppColors.muted);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(isDone || isActive ? 1 : 0.15),
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Icon(
                  isDone ? Icons.check : Icons.circle,
                  size: isDone ? 16 : 8,
                  color: isDone ? AppColors.bg : color,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isDone ? AppColors.success : AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isDone || isActive
                          ? AppColors.cream
                          : AppColors.muted,
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  if (timestamp != null && timestamp!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      timestamp!,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
