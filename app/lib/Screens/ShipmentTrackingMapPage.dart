import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';

import '../API/ShipmentServices.dart';
import '../API/config.dart';
import '../l10n/app_localizations.dart';
import '../models/Shipment.dart';

/// Live GPS tracking map (OpenStreetMap tiles via flutter_map — no Google
/// Maps API key needed). Shows the assigned driver's last reported
/// position as a marker, polling the same /track endpoint the stage
/// timeline (ShipmentTrackingPage) already uses, since that response
/// already embeds the driver's last_lat/last_lng (CompanyFacingDriverResource
/// on the backend).
class ShipmentTrackingMapPage extends StatefulWidget {
  final Shipment shipment;
  const ShipmentTrackingMapPage({super.key, required this.shipment});

  @override
  State<ShipmentTrackingMapPage> createState() => _ShipmentTrackingMapPageState();
}

class _ShipmentTrackingMapPageState extends State<ShipmentTrackingMapPage> {
  final _service = ShipmentService();
  final _mapController = MapController();
  late Shipment _shipment;
  Timer? _pollTimer;
  bool _firstFix = true;

  @override
  void initState() {
    super.initState();
    _shipment = widget.shipment;
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    final updated = await _service.fetchOneByTrackingNumber(_shipment.trackingNumber);
    if (!mounted || updated == null) return;
    setState(() => _shipment = updated);

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

  String _timeAgo(AppLocalizations t, DateTime? dt) {
    if (dt == null) return t.neverLabel;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return t.timeJustNow;
    if (diff.inMinutes < 60) return t.timeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return t.timeHoursAgo(diff.inHours);
    return t.timeDaysAgo(diff.inDays);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final hasFix = _shipment.driverLastLat != null && _shipment.driverLastLng != null;
    final point = hasFix
        ? ll.LatLng(_shipment.driverLastLat!, _shipment.driverLastLng!)
        : const ll.LatLng(25.276987, 55.296249); // Dubai — neutral fallback center

    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: LightColors.cream),
        title: Text(
          _shipment.trackingNumber.isEmpty ? t.liveTrackingTitle : _shipment.trackingNumber,
          style: const TextStyle(color: LightColors.cream),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: LightColors.surface,
            child: Row(
              children: [
                const Icon(Icons.route_outlined, color: LightColors.gold, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_shipment.origin} → ${_shipment.destination}',
                    style: const TextStyle(color: LightColors.cream, fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  hasFix ? t.updatedAgoLabel(_timeAgo(t, _shipment.driverLastLocationAt)) : t.noGpsFixYet,
                  style: TextStyle(color: hasFix ? LightColors.muted : LightColors.error, fontSize: 11),
                ),
              ],
            ),
          ),
          Expanded(
            child: hasFix
                ? FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: point,
                      initialZoom: 12,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.fms.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: point,
                            width: 44,
                            height: 44,
                            child: const Icon(Icons.local_shipping_rounded, color: LightColors.gold, size: 36),
                          ),
                        ],
                      ),
                      // Mandatory per OpenStreetMap's tile usage policy.
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution(
                            'OpenStreetMap contributors',
                            onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
                          ),
                        ],
                      ),
                    ],
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        t.noGpsPositionYetBody,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: LightColors.muted, fontSize: 13),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
