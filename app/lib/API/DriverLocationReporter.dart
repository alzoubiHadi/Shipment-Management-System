import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'DriverService.dart';

/// UC-21/UC-14: requests location permission and periodically reports the
/// driver's GPS fix to the server (DriverService.updateMyLocation) while
/// the app is open — foreground-only, no background tracking service, per
/// the design already documented on the backend
/// (DriverController::updateLocation). This is what feeds the
/// company/admin-facing live tracking map (ShipmentTrackingPage's embedded
/// map) and the matching proximity score.
///
/// Start from HomeScreen.initState() for driver accounts only, and stop in
/// dispose() — see HomeScreen for the call sites. Safe to call start()
/// more than once (e.g. hot navigation back to HomeScreen); it's a no-op
/// while already running.
class DriverLocationReporter {
  static Timer? _timer;
  static bool _requesting = false;

  static Future<void> start() async {
    if (_timer != null) return; // already running
    await _requestPermissionThenReport();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _reportOnce());
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> _requestPermissionThenReport() async {
    if (_requesting) return;
    _requesting = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        // GPS/location services off at the OS level — nothing we can do
        // until the driver enables it themselves; the timer above will
        // keep retrying every 30s in case they do mid-session.
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        // Driver declined — the rest of the app must keep working
        // normally without live tracking; this is never a hard block.
        return;
      }

      await _reportOnce();
    } finally {
      _requesting = false;
    }
  }

  static Future<void> _reportOnce() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      await DriverService.updateMyLocation(
        lat: position.latitude,
        lng: position.longitude,
      );
    } catch (_) {
      // Silent by design — GPS temporarily unavailable, permission
      // revoked mid-session, or a network hiccup. The next 30s tick
      // retries; this must never interrupt the driver's actual workflow
      // (accepting offers, advancing shipment stages, etc).
    }
  }
}
