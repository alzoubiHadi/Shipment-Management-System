import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'DriverService.dart';

/// Background-capable GPS tracker, gated on the driver having an ACTIVE
/// trip (Shipment.status 1/2/5 — see DriverService.fetchCurrentTrip()).
///
/// Design (2026-08-24, replacing the old always-on foreground-only
/// reporter — see git history for that version):
/// - No active trip: nothing runs. No background GPS, Logout stays
///   available (see logout_helper.dart's isDriverLogoutBlocked check).
/// - Active trip: starts a Geolocator.getPositionStream() using
///   platform background settings (AndroidSettings.foregroundNotificationConfig
///   / AppleSettings.allowBackgroundLocationUpdates) so location keeps
///   reporting even with the app backgrounded or the screen off — not
///   just while this screen is on-screen. Logout is blocked for as long
///   as this is true (hasActiveTrip.value == true).
/// - A lightweight trip-status poll runs continuously (works while
///   foregrounded; once background tracking is active the OS keeps the
///   whole process alive for us too, per the platform background
///   settings above, so it keeps polling in the background as well) and
///   automatically stops the position stream the moment the trip leaves
///   1/2/5 (delivered/cancelled), re-enabling Logout.
/// - Offline handling is intentionally simple per spec: no queue/retry
///   store. A failed report or trip-status check is just skipped and
///   retried on the next tick; the server naturally keeps whatever
///   last_lat/last_lng/last_location_at it already has ("last known
///   location") until a report succeeds again.
///
/// Start from HomeScreen.initState() for driver accounts only, and stop
/// in dispose() — see HomeScreen for the call sites. Safe to call
/// start() more than once (e.g. hot navigation back to HomeScreen); it's
/// a no-op while already running.
class DriverLocationReporter {
  static Timer? _tripCheckTimer;
  static StreamSubscription<Position>? _positionStream;
  static bool _startingStream = false;

  /// True while the driver has a trip in status 1/2/5. UI (the "Active
  /// Trip" banner, the Logout button) listens to this directly instead of
  /// re-polling the server itself.
  static final ValueNotifier<bool> hasActiveTrip = ValueNotifier<bool>(false);

  static Future<void> start() async {
    if (_tripCheckTimer != null) return; // already running
    await _checkTripAndSync();
    _tripCheckTimer = Timer.periodic(const Duration(seconds: 45), (_) => _checkTripAndSync());
  }

  static void stop() {
    _tripCheckTimer?.cancel();
    _tripCheckTimer = null;
    _stopStreaming();
    hasActiveTrip.value = false;
  }

  static Future<void> _checkTripAndSync() async {
    try {
      final result = await DriverService.fetchCurrentTrip();
      final active = result['has_active_trip'] == true;
      hasActiveTrip.value = active;

      if (active && _positionStream == null) {
        await _startStreaming();
      } else if (!active && _positionStream != null) {
        debugPrint('[DriverLocationReporter] trip ended — stopping background tracking');
        _stopStreaming();
      }
    } catch (e) {
      // Couldn't reach the server to check trip status — deliberately
      // leave hasActiveTrip and any running stream exactly as they were.
      // Flipping hasActiveTrip to false here on a mere network hiccup
      // would wrongly re-enable Logout mid-trip; the next tick retries.
      debugPrint('[DriverLocationReporter] trip status check failed: $e');
    }
  }

  static Future<void> _startStreaming() async {
    if (_startingStream) return;
    _startingStream = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        // GPS/location services off at the OS level — nothing we can do
        // until the driver enables it themselves; the trip-check timer
        // keeps retrying every 45s in case they do mid-trip.
        debugPrint('[DriverLocationReporter] location services OFF at OS level');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        // Driver declined — the rest of the app must keep working
        // normally without live tracking; this is never a hard block,
        // and it does NOT affect the Logout gate (that's tied purely to
        // trip status, not to whether tracking actually succeeded).
        debugPrint('[DriverLocationReporter] permission denied: $permission');
        return;
      }

      final LocationSettings settings = defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 0,
              intervalDuration: const Duration(seconds: 30),
              // Foreground service + persistent notification — this is
              // what keeps Android delivering location (and keeps our
              // Dart isolate alive) once the app is backgrounded or the
              // screen locks. Without this, Android suspends the app
              // within moments of losing foreground.
              foregroundNotificationConfig: const ForegroundNotificationConfig(
                notificationTitle: 'FMS — Trip in progress',
                notificationText: 'Sharing your location while this trip is active',
                enableWakeLock: true,
              ),
            )
          : AppleSettings(
              accuracy: LocationAccuracy.high,
              activityType: ActivityType.automotiveNavigation,
              distanceFilter: 30,
              pauseLocationUpdatesAutomatically: false,
              showBackgroundLocationIndicator: true,
              // iOS equivalent of the Android foreground service — requires
              // UIBackgroundModes: [location] plus the "Always" location
              // usage-description key in Info.plist.
              allowBackgroundLocationUpdates: true,
            );

      _positionStream = Geolocator.getPositionStream(locationSettings: settings).listen(
        (position) {
          DriverService.updateMyLocation(lat: position.latitude, lng: position.longitude).catchError(
            (e) {
              debugPrint('[DriverLocationReporter] report failed: $e');
              return <String, dynamic>{};
            },
          );
        },
        onError: (Object e) => debugPrint('[DriverLocationReporter] position stream error: $e'),
      );
      debugPrint('[DriverLocationReporter] background tracking started');
    } catch (e) {
      debugPrint('[DriverLocationReporter] failed to start streaming: $e');
    } finally {
      _startingStream = false;
    }
  }

  static void _stopStreaming() {
    _positionStream?.cancel();
    _positionStream = null;
  }
}
