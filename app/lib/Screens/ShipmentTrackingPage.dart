import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';

import '../API/ShipmentServices.dart';
import '../API/config.dart';
import '../models/Shipment.dart';
import 'ShipmentTrackingMapPage.dart';
import 'SignatureCapturePage.dart';

/// Shows the tracking timeline for a shipment — the stage list depends on
/// [Shipment.orderType] (agreed 2026-08-16): internal (domestic) shipments
/// get 6 stages (going to load, loading, to destination, offloading,
/// uploading delivery note, completed); external (cross-border) shipments
/// get 8 (the same, plus "to border"/"crossing the border" in between).
/// The live GPS map is embedded directly at the top of this same screen
/// (no separate tap needed) so it's visible the instant a shipment is
/// opened, with an expand button for a fullscreen view.
///
/// When [readOnly] is false (driver assigned to the shipment), a button lets
/// the driver push the shipment forward one stage at a time up through
/// "uploading delivery note" (a signature capture). The final "Completed"
/// stage is never driver-controlled — it only happens when the company
/// confirms receipt (ShipmentController::confirmDelivery). Admin/company
/// view the whole thing as [readOnly].
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
  final _mapController = MapController();
  late Shipment _shipment;
  bool _isUpdating = false;
  Timer? _pollTimer;
  bool _firstFix = true;

  @override
  void initState() {
    super.initState();
    _shipment = widget.shipment;

    // Poll for every viewer, not just read-only ones: this is also what
    // now keeps the embedded live map (driver's last GPS fix) up to date
    // even on the driver's own screen, not just admin/company's.
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_shipment.currentStage >= _shipment.totalStages ||
        _shipment.trackingNumber.isEmpty) {
      _pollTimer?.cancel();
      return;
    }
    final updated =
        await _service.fetchOneByTrackingNumber(_shipment.trackingNumber);
    if (!mounted || updated == null) return;
    setState(() => _shipment = updated);
    if (updated.currentStage >= updated.totalStages) _pollTimer?.cancel();

    if (updated.driverLastLat != null && updated.driverLastLng != null) {
      final point = ll.LatLng(updated.driverLastLat!, updated.driverLastLng!);
      if (_firstFix) {
        _mapController.move(point, 12);
        _firstFix = false;
      } else {
        _mapController.move(point, _mapController.camera.zoom);
      }
    }
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return 'never';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Per-[Shipment.orderType] stage => raw timestamp string, in display
  /// order — mirrors Shipment::ADVANCE_COLUMNS + delivered_at +
  /// company_confirmed_at on the backend exactly.
  List<String?> get _stageTimestamps => _shipment.orderType == 'external'
      ? [
          _shipment.headingToPickupAt,
          _shipment.loadedAt,
          _shipment.departedToBorderAt,
          _shipment.borderClearedAt,
          _shipment.arrivedAtDestinationAt,
          _shipment.unloadedAt,
          _shipment.delivered_at,
          _shipment.companyConfirmedAt,
        ]
      : [
          _shipment.headingToPickupAt,
          _shipment.loadedAt,
          _shipment.arrivedAtDestinationAt,
          _shipment.unloadedAt,
          _shipment.delivered_at,
          _shipment.companyConfirmedAt,
        ];

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
          backgroundColor: LightColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message']?.toString() ?? 'Failed')),
      );
    }
  }

  Color get _statusColor => switch (_shipment.status) {
        0 => LightColors.gold,
        1 => LightColors.info,
        2 => LightColors.success,
        3 => LightColors.success,
        4 => LightColors.error,
        5 => LightColors.error,
        _ => LightColors.muted,
      };

  Color _deliveryStatusColor(String status) {
    switch (status) {
      case 'awaiting_confirmation':
        return LightColors.gold;
      case 'confirmed':
        return LightColors.success;
      case 'disputed':
        return LightColors.error;
      default:
        return LightColors.muted;
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
        backgroundColor: LightColors.surface,
        title: const Text('Add a comment',
            style: TextStyle(color: LightColors.cream)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: LightColors.cream),
          decoration: const InputDecoration(
            hintText: 'e.g. truck breakdown, road closure...',
            hintStyle: TextStyle(color: LightColors.muted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: LightColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save', style: TextStyle(color: LightColors.gold)),
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
    final timestamps = _stageTimestamps;
    if (stage < 1 || stage > timestamps.length) return null;
    return timestamps[stage - 1];
  }

  @override
  Widget build(BuildContext context) {
    final current = _shipment.currentStage;

    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: LightColors.cream),
        title: Text(
          _shipment.trackingNumber.isEmpty
              ? 'Shipment Tracking'
              : _shipment.trackingNumber,
          style: const TextStyle(color: LightColors.cream),
        ),
        actions: [
          if (!widget.readOnly)
            IconButton(
              onPressed: _addComment,
              icon: const Icon(Icons.comment_outlined, color: LightColors.cream),
              tooltip: 'Add comment',
            ),
          if (widget.readOnly && current < _shipment.totalStages)
            const Padding(
              padding: EdgeInsets.only(left: 16, right: 16),
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
              color: LightColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: LightColors.border, width: 0.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, color: LightColors.gold),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_shipment.origin} → ${_shipment.destination}',
                    style: const TextStyle(
                      color: LightColors.cream,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // 2026-08-17 driver-redesign polish: the overall status
                // ("In Transit", "Delivered"...) used to only be visible by
                // scrolling down to find the active stage in the timeline
                // below — now shown at a glance right next to the route.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel(_shipment.status),
                    style: TextStyle(color: _statusColor, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Embedded live GPS map — visible immediately, no extra tap
          // needed, per the agreed redesign. An expand button opens the
          // same map fullscreen (ShipmentTrackingMapPage) for a closer
          // look.
          _buildEmbeddedMap(),

          const SizedBox(height: 24),

          for (int stage = 1; stage <= _shipment.totalStages; stage++)
            _StageRow(
              stage: stage,
              label: _shipment.stageLabels[stage]!,
              isDone: stage <= current,
              isActive: stage == current + 1 && current < _shipment.totalStages,
              timestamp: _timestampFor(stage),
              isLast: stage == _shipment.totalStages,
            ),

          if (current >= _shipment.driverAdvanceMax + 1) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: LightColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: LightColors.border, width: 0.5),
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
                            color: LightColors.muted,
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
                    style: const TextStyle(color: LightColors.cream, fontSize: 14),
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
      // Hidden once the driver has nothing left to do: either they're
      // read-only (admin/company), or they've already uploaded the
      // delivery note (current stage is driverAdvanceMax+1) and it's now
      // waiting on the company's own "Completed" confirmation.
      bottomNavigationBar:
          (widget.readOnly || current >= _shipment.driverAdvanceMax + 1)
              ? null
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isUpdating
                          ? null
                          : (current == _shipment.driverAdvanceMax
                              ? _captureDelivery
                              : _advance),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LightColors.gold,
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
                                color: LightColors.deepNavy,
                              ),
                            )
                          : Text(
                              current == _shipment.driverAdvanceMax
                                  ? 'Capture proof of delivery'
                                  : 'Mark as: ${_shipment.stageLabels[current + 1]}',
                              style: const TextStyle(
                                color: LightColors.deepNavy,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
    );
  }

  /// Compact live-map card embedded directly in the tracking screen (per
  /// the agreed redesign — no separate tap needed to see it). Falls back
  /// to a placeholder message when the driver hasn't reported a GPS fix
  /// yet. The expand button opens the same data fullscreen.
  Widget _buildEmbeddedMap() {
    final hasFix =
        _shipment.driverLastLat != null && _shipment.driverLastLng != null;
    final point = hasFix
        ? ll.LatLng(_shipment.driverLastLat!, _shipment.driverLastLng!)
        : const ll.LatLng(25.276987, 55.296249); // Dubai — neutral fallback

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          border: Border.all(color: LightColors.border, width: 0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            if (hasFix)
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(initialCenter: point, initialZoom: 12),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.fms.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.local_shipping_rounded,
                            color: LightColors.gold, size: 32),
                      ),
                    ],
                  ),
                  // Mandatory per OpenStreetMap's tile usage policy.
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        'OpenStreetMap',
                        onTap: () => launchUrl(
                            Uri.parse('https://www.openstreetmap.org/copyright')),
                      ),
                    ],
                  ),
                ],
              )
            else
              Container(
                color: LightColors.surface,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(16),
                child: const Text(
                  'No GPS fix yet — updates automatically once the driver reports one',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: LightColors.muted, fontSize: 12),
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: LightColors.surface.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            ShipmentTrackingMapPage(shipment: _shipment)),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.open_in_full,
                        color: LightColors.cream, size: 16),
                  ),
                ),
              ),
            ),
            if (hasFix)
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: LightColors.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Updated ${_timeAgo(_shipment.driverLastLocationAt)}',
                    style: const TextStyle(color: LightColors.muted, fontSize: 10),
                  ),
                ),
              ),
          ],
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
        color: LightColors.success.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: LightColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Live',
            style: TextStyle(
              color: LightColors.success,
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
        ? LightColors.success
        : (isActive ? LightColors.gold : LightColors.muted);

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
                  color: isDone ? Colors.white : color,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isDone ? LightColors.success : LightColors.border,
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
                          ? LightColors.cream
                          : LightColors.muted,
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
                        color: LightColors.muted,
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
