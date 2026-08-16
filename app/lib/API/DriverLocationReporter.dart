import 'dart:async';

import 'package:flutter/foundation.dart';
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
        // GPS/location services off at the OS level (not just app
        // permission — the phone's Location toggle itself) — nothing we
        // can do until the driver enables it themselves; the timer above
        // keeps retrying every 30s in case they do mid-session.
        debugPrint('[DriverLocationReporter] location services OFF at OS level');
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
        debugPrint('[DriverLocationReporter] permission denied: $permission');
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

      Position? position;
      try {
        // A hard time limit matters here: without one, getCurrentPosition
        // can hang indefinitely on a device that can't get a fresh GPS
        // fix quickly (weak signal indoors, cold GPS start, no Wi-Fi/cell
        // positioning) — that silently starves every future 30s tick
        // since a new call never even starts while the old one is stuck.
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 20),
          ),
        );
      } catch (e) {
        debugPrint('[DriverLocationReporter] getCurrentPosition failed ($e), trying last known position');
        // Falls back to whatever fix the OS already has cached (from this
        // app or another one) rather than reporting nothing at all — a
        // slightly stale position still beats "no GPS fix" on the map.
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        debugPrint('[DriverLocationReporter] no position available (fresh or cached)');
        return;
      }

      final result = await DriverService.updateMyLocation(
        lat: position.latitude,
        lng: position.longitude,
      );
      debugPrint('[DriverLocationReporter] reported ${position.latitude},${position.longitude} -> $result');
    } catch (e) {
      // Never rethrow — GPS temporarily unavailable, permission revoked
      // mid-session, or a network hiccup must never interrupt the
      // driver's actual workflow (accepting offers, advancing shipment
      // stages, etc). The next 30s tick retries.
      debugPrint('[DriverLocationReporter] report failed: $e');
    }
  }
}
