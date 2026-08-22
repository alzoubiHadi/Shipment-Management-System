import 'package:flutter/material.dart';

import '../API/AdminShipmentService.dart';
import '../API/config.dart';
import '../l10n/app_localizations.dart';
import 'AdminShipmentStatusStyle.dart';

/// Admin Shipments redesign (2026-08-24): opened for a cancelled item —
/// works for both a cancelled Shipment (post-acceptance) and a cancelled
/// ShipmentOffer (cancelled before any driver accepted, so it never became
/// a real Shipment). No map — per the redesign's own point: "no meaning in
/// opening Live Tracking for something there's nothing left to track."
class CancellationReportScreen extends StatefulWidget {
  final String trackingNumber;
  const CancellationReportScreen({super.key, required this.trackingNumber});

  @override
  State<CancellationReportScreen> createState() => _CancellationReportScreenState();
}

class _CancellationReportScreenState extends State<CancellationReportScreen> {
  bool _loading = true;
  String? _error;
  String? _kind;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AdminShipmentService.fetchDetail(widget.trackingNumber);
      if (!mounted) return;
      setState(() {
        _kind = data['kind']?.toString();
        _data = (data['shipment'] ?? data['offer']) as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _fmt(dynamic raw) {
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return raw.toString();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: LightColors.textPrimary),
        title: Text('#${widget.trackingNumber}', style: const TextStyle(color: LightColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final t = AppLocalizations.of(context)!;
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: LightColors.navy));
    }
    if (_error != null || _data == null) {
      return Center(child: Text(_error ?? t.notFoundLabel, style: const TextStyle(color: LightColors.textSecondary)));
    }

    final data = _data!;
    final cancellation = data['cancellation'] as Map<String, dynamic>?;
    final financial = data['financial'] as Map<String, dynamic>?;
    final isShipment = _kind == 'shipment';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Icon(Icons.cancel_rounded, color: LightColors.error, size: 20),
              const SizedBox(width: 6),
              Text(t.cancelledLabel, style: const TextStyle(color: LightColors.error, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 6),
          Text('${data['origin']} → ${data['destination']}',
              style: const TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          _InfoCard(title: t.cancellationSummaryTitle, rows: [
            MapEntry(t.fieldCreated, _fmt(data['created_at'])),
            MapEntry(t.fieldCancelledBy, cancellation?['cancelled_by']?.toString() ?? '—'),
            MapEntry(t.fieldCancelledAt, _fmt(cancellation?['cancelled_at'])),
            MapEntry(t.fieldReason, cancellation?['reason']?.toString() ?? '—'),
            if (isShipment) MapEntry(t.fieldDriverAssigned, (cancellation?['driver_assigned'] == true) ? t.commonYes : t.commonNo),
            if (isShipment) MapEntry(t.fieldStageReached, cancellation?['stage_reached']?.toString() ?? '—'),
          ]),
          if (financial != null && (financial['price_to_client'] != null || financial['price_to_driver'] != null)) ...[
            const SizedBox(height: 16),
            _InfoCard(title: t.financialImpactTitle, rows: [
              MapEntry(t.fieldClientPrice, financial['price_to_client']?.toString() ?? '—'),
              MapEntry(t.fieldDriverPrice, financial['price_to_driver']?.toString() ?? '—'),
            ]),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<MapEntry<String, String>> rows;
  const _InfoCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: LightColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: LightColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 120, child: Text(row.key, style: const TextStyle(color: LightColors.textSecondary, fontSize: 12))),
                  Expanded(child: Text(row.value, style: const TextStyle(color: LightColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
