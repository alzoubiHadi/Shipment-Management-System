import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';

import '../API/AdminShipmentService.dart';
import '../API/config.dart';
import '../l10n/app_localizations.dart';
import 'AdminShipmentStatusStyle.dart';

/// Admin Shipments redesign (2026-08-24): opened for an active shipment
/// (assigned/pickup/loaded/in transit) — map-first layout with the pickup
/// point, driver's current location, and destination (when known), a
/// vertical stage timeline, and collapsible Details/Driver&Truck/Company/
/// Cargo/Financial sections (collapsed by default, per the mockup's "don't
/// show everything open" note). Single fetch + pull-to-refresh rather than
/// the driver-facing screen's 6s polling — this is an admin monitoring
/// view, not the in-progress driver UI, so live-polling overhead isn't
/// worth it here.
class LiveShipmentTrackingScreen extends StatefulWidget {
  final String trackingNumber;
  const LiveShipmentTrackingScreen({super.key, required this.trackingNumber});

  @override
  State<LiveShipmentTrackingScreen> createState() => _LiveShipmentTrackingScreenState();
}

class _LiveShipmentTrackingScreenState extends State<LiveShipmentTrackingScreen> {
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

  String _agoLabel(AppLocalizations t, dynamic raw) {
    final dt = DateTime.tryParse(raw?.toString() ?? '');
    if (dt == null) return t.noUpdateYet;
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inMinutes < 1) return t.timeJustNow;
    if (diff.inMinutes < 60) return t.minAgoFull(diff.inMinutes);
    if (diff.inHours < 24) return t.timeHoursAgo(diff.inHours);
    return t.timeDaysAgo(diff.inDays);
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
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded, color: LightColors.textSecondary))],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final t = AppLocalizations.of(context)!;
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: LightColors.navy));
    }
    if (_error != null || _shipment == null) {
      return Center(child: Text(_error ?? t.notFoundLabel, style: const TextStyle(color: LightColors.textSecondary)));
    }

    final s = _shipment!;
    final driver = s['driver'] as Map<String, dynamic>?;
    final truck = s['truck'] as Map<String, dynamic>?;
    final company = s['company'] as Map<String, dynamic>?;
    final financial = s['financial'] as Map<String, dynamic>?;
    final stages = (s['stages'] as List? ?? []).cast<Map<String, dynamic>>();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMap(t, s, driver),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: LightColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: LightColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('${s['origin']} → ${s['destination']}',
                          style: const TextStyle(color: LightColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                    AdminStatusPill(label: s['status_label']?.toString() ?? '', statusGroup: 'active'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(t.lastLocationUpdateLabel(_agoLabel(t, driver?['last_location_at'])),
                    style: const TextStyle(color: LightColors.textSecondary, fontSize: 11.5)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(t.shipmentProgressTitle, style: const TextStyle(color: LightColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _VerticalTimeline(stages: stages, fmt: _fmt),
          const SizedBox(height: 8),
          _Section(
            title: t.sectionShipmentDetails,
            children: [
              _row(t.addShipmentReviewWeight, s['weight']?.toString() ?? '—'),
              _row(t.fieldOrderType, s['order_type']?.toString() ?? '—'),
              _row(t.addShipmentReviewDescription, s['description']?.toString() ?? '—'),
              _row(t.fieldNeedsPermit, s['needs_permit'] == true ? t.commonYes : t.commonNo),
              _row(t.addShipmentReviewHazardous, s['is_hazardous'] == true ? t.commonYes : t.commonNo),
              _row(t.addShipmentReviewFragile, s['is_fragile'] == true ? t.commonYes : t.commonNo),
            ],
          ),
          if (driver != null || truck != null)
            _Section(
              title: t.driverAndTruckTitle,
              children: [
                if (driver != null) _row(t.fieldDriverLabel, driver['name']?.toString() ?? '—'),
                if (driver != null) _row(t.fieldPhone, driver['phone']?.toString() ?? '—'),
                if (driver != null) _row(t.fieldRating, driver['rating']?.toString() ?? '—'),
                if (truck != null) _row(t.fieldTruck, '${truck['truck_type'] ?? ''} • ${truck['truck_number'] ?? ''}'),
              ],
            ),
          if (company != null)
            _Section(
              title: t.companySectionTitle,
              children: [
                _row(t.fieldName, company['name']?.toString() ?? '—'),
                _row(t.fieldPhone, company['phone']?.toString() ?? '—'),
              ],
            ),
          if (financial != null)
            _Section(
              title: t.financialSummaryTitle,
              children: [
                _row(t.fieldClientPrice, financial['price_to_client']?.toString() ?? '—'),
                _row(t.fieldDriverPrice, financial['price_to_driver']?.toString() ?? '—'),
                _row(t.fieldCommission, financial['commission']?.toString() ?? '—'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: LightColors.textSecondary, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(color: LightColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildMap(AppLocalizations t, Map<String, dynamic> s, Map<String, dynamic>? driver) {
    final points = <ll.LatLng>[];
    final markers = <Marker>[];

    void addPoint(dynamic lat, dynamic lng, IconData icon, Color color) {
      final la = double.tryParse('$lat');
      final lo = double.tryParse('$lng');
      if (la == null || lo == null) return;
      final point = ll.LatLng(la, lo);
      points.add(point);
      markers.add(Marker(point: point, width: 36, height: 36, child: Icon(icon, color: color, size: 30)));
    }

    addPoint(s['origin_lat'], s['origin_lng'], Icons.trip_origin, LightColors.navy);
    addPoint(driver?['last_lat'], driver?['last_lng'], Icons.local_shipping_rounded, LightColors.gold);
    addPoint(s['destination_lat'], s['destination_lng'], Icons.flag_rounded, LightColors.error);

    final center = points.isNotEmpty ? points[points.length ~/ 2] : const ll.LatLng(25.276987, 55.296249);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 220,
        decoration: BoxDecoration(border: Border.all(color: LightColors.border), borderRadius: BorderRadius.circular(14)),
        child: points.isEmpty
            ? Container(
                color: LightColors.surface,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(16),
                child: Text(t.noLocationDataYet,
                    textAlign: TextAlign.center, style: const TextStyle(color: LightColors.textSecondary, fontSize: 12)),
              )
            : FlutterMap(
                options: MapOptions(initialCenter: center, initialZoom: 6),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.fms.app'),
                  if (points.length > 1)
                    PolylineLayer(polylines: [Polyline(points: points, color: LightColors.navy, strokeWidth: 3)]),
                  MarkerLayer(markers: markers),
                  RichAttributionWidget(attributions: [
                    TextSourceAttribution('OpenStreetMap', onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright'))),
                  ]),
                ],
              ),
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
      children: [for (int i = 0; i < stages.length; i++) _StageRow(stage: stages[i], isLast: i == stages.length - 1, fmt: fmt)],
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
                  size: 18, color: done ? LightColors.navy : LightColors.border),
              if (!isLast) Expanded(child: Container(width: 2, color: done ? LightColors.navy : LightColors.border)),
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

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: LightColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: LightColors.border)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(title, style: const TextStyle(color: LightColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700)),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: children,
        ),
      ),
    );
  }
}
