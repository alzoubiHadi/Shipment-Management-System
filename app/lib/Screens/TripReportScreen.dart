import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../API/AdminShipmentService.dart';
import '../API/config.dart';

/// Admin Shipments redesign (2026-08-24): opened for a delivered shipment —
/// turns it into a reviewable trip record (Summary + full stage-by-stage
/// Timeline + Driver & Truck + Proof of Delivery + Financial Summary)
/// instead of just a status label.
class TripReportScreen extends StatefulWidget {
  final String trackingNumber;
  const TripReportScreen({super.key, required this.trackingNumber});

  @override
  State<TripReportScreen> createState() => _TripReportScreenState();
}

class _TripReportScreenState extends State<TripReportScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _shipment;

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
        _shipment = data['shipment'] as Map<String, dynamic>?;
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: LightColors.navy));
    }
    if (_error != null || _shipment == null) {
      return Center(child: Text(_error ?? 'Not found', style: const TextStyle(color: LightColors.textSecondary)));
    }

    final s = _shipment!;
    final stages = (s['stages'] as List? ?? []).cast<Map<String, dynamic>>();
    final driver = s['driver'] as Map<String, dynamic>?;
    final truck = s['truck'] as Map<String, dynamic>?;
    final pod = s['pod'] as Map<String, dynamic>?;
    final financial = s['financial'] as Map<String, dynamic>?;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: LightColors.success, size: 20),
              const SizedBox(width: 6),
              const Text('DELIVERED', style: TextStyle(color: LightColors.success, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 6),
          Text('${s['origin']} → ${s['destination']}',
              style: const TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _StatCard(icon: Icons.route_rounded, label: 'Distance', value: s['distance_km'] != null ? '${s['distance_km']} km' : '—')),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(icon: Icons.timelapse_rounded, label: 'Duration', value: s['duration_label']?.toString() ?? '—')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _StatCard(icon: Icons.upload_rounded, label: 'Pickup Time', value: _fmt(s['pickup_time']))),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(icon: Icons.download_rounded, label: 'Delivery Time', value: _fmt(s['delivered_at']))),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Trip Timeline', style: TextStyle(color: LightColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _VerticalTimeline(stages: stages, fmt: _fmt),
          const SizedBox(height: 24),
          if (driver != null || truck != null) ...[
            _InfoCard(title: 'Driver & Truck', rows: [
              if (driver != null) MapEntry('Driver', driver['name']?.toString() ?? '—'),
              if (driver != null) MapEntry('Phone', driver['phone']?.toString() ?? '—'),
              if (truck != null) MapEntry('Truck', '${truck['truck_type'] ?? ''} • ${truck['truck_number'] ?? ''}'),
            ]),
            const SizedBox(height: 16),
          ],
          if (pod != null) ...[
            _PodCard(pod: pod),
            const SizedBox(height: 16),
          ],
          if (financial != null)
            _InfoCard(title: 'Financial Summary', rows: [
              MapEntry('Client Price', financial['price_to_client']?.toString() ?? '—'),
              MapEntry('Driver Price', financial['price_to_driver']?.toString() ?? '—'),
              MapEntry('Commission', financial['commission']?.toString() ?? '—'),
            ]),
          // Zones / Smart Pricing Engine snapshot (2026-08-27) — only
          // present on shipments created through the zone-based flow; the
          // historical reference this was priced against, for audit.
          if (financial != null && financial['pricing_reference'] != null) ...[
            const SizedBox(height: 16),
            _InfoCard(title: 'Pricing Reference (Smart Pricing Engine)', rows: [
              MapEntry('Historical reference', 'AED ${financial['pricing_reference']}'),
              if (financial['pricing_low'] != null && financial['pricing_high'] != null)
                MapEntry('Typical range', 'AED ${financial['pricing_low']} – ${financial['pricing_high']}'),
              if (financial['pricing_confidence'] != null) MapEntry('Confidence', financial['pricing_confidence'].toString()),
              if (financial['market_adjustment_snapshot'] != null)
                MapEntry('Market adjustment applied', '${financial['market_adjustment_snapshot']}%'),
            ]),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: LightColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: LightColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: LightColors.textSecondary),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: LightColors.textSecondary, fontSize: 11)),
          ]),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: LightColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _VerticalTimeline extends StatelessWidget {
  final List<Map<String, dynamic>> stages;
  final String Function(dynamic) fmt;
  const _VerticalTimeline({required this.stages, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < stages.length; i++)
          _StageRow(stage: stages[i], isLast: i == stages.length - 1, fmt: fmt),
      ],
    );
  }
}

class _StageRow extends StatelessWidget {
  final Map<String, dynamic> stage;
  final bool isLast;
  final String Function(dynamic) fmt;
  const _StageRow({required this.stage, required this.isLast, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final done = stage['done'] == true;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 18, color: done ? LightColors.success : LightColors.border),
              if (!isLast) Expanded(child: Container(width: 2, color: done ? LightColors.success : LightColors.border)),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stage['label']?.toString() ?? '', style: const TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  if (done) Text(fmt(stage['timestamp']), style: const TextStyle(color: LightColors.textSecondary, fontSize: 11.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PodCard extends StatelessWidget {
  final Map<String, dynamic> pod;
  const _PodCard({required this.pod});

  @override
  Widget build(BuildContext context) {
    final documentPath = pod['pod_document_path']?.toString();
    final signature = pod['pod_signature']?.toString();
    final hasDocument = documentPath != null && documentPath.isNotEmpty;
    final ext = hasDocument ? documentPath.split('.').last.toLowerCase() : '';
    final isImageDoc = ext == 'jpg' || ext == 'jpeg' || ext == 'png';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: LightColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: LightColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Proof of Delivery', style: TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Receiver: ${pod['recipient_name'] ?? '—'}', style: const TextStyle(color: LightColors.textSecondary, fontSize: 12.5)),
          if (hasDocument && isImageDoc) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 160,
                width: double.infinity,
                color: Colors.white,
                child: Image.network(
                  storageUrl(documentPath),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text('Document unavailable', style: TextStyle(color: LightColors.textSecondary, fontSize: 11)),
                  ),
                ),
              ),
            ),
          ] else if (hasDocument) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () => launchUrl(Uri.parse(storageUrl(documentPath)), mode: LaunchMode.externalApplication),
              child: const Row(
                children: [
                  Icon(Icons.picture_as_pdf_outlined, color: LightColors.gold, size: 20),
                  SizedBox(width: 6),
                  Text('View delivery document', style: TextStyle(color: LightColors.gold, fontWeight: FontWeight.w600, fontSize: 12.5)),
                ],
              ),
            ),
          ] else if (signature != null && signature.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 120,
                width: double.infinity,
                color: Colors.white,
                child: _SignatureImage(base64Data: signature),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SignatureImage extends StatelessWidget {
  final String base64Data;
  const _SignatureImage({required this.base64Data});

  @override
  Widget build(BuildContext context) {
    try {
      final cleaned = base64Data.contains(',') ? base64Data.split(',').last : base64Data;
      final bytes = base64Decode(cleaned);
      return Image.memory(bytes, fit: BoxFit.contain);
    } catch (_) {
      return const Center(child: Text('Signature unavailable', style: TextStyle(color: LightColors.textSecondary, fontSize: 11)));
    }
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
                  SizedBox(width: 110, child: Text(row.key, style: const TextStyle(color: LightColors.textSecondary, fontSize: 12))),
                  Expanded(child: Text(row.value, style: const TextStyle(color: LightColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
