import 'dart:async';

import 'package:flutter/foundation.dart';

import 'DriverService.dart';

/// Single shared source of truth for the driver's operational
/// `drivers.status` ('available' | 'busy' | 'unavailable') — mirrors
/// `DriverLocationReporter.hasActiveTrip`'s design exactly (same
/// start()/stop() lifecycle from HomeScreen, same periodic-poll shape) so
/// every screen that shows or toggles availability (DriverDashboardScreen's
/// Work Status card, DriverOffersPage's AppBar toggle) reads/writes through
/// this ONE notifier instead of each keeping its own independently-fetched
/// copy.
///
/// Before this existed, Home and "Available Shipments" each fetched their
/// own status once at initState — toggling on one screen left the other
/// showing a stale value until it happened to be reopened. Routing both
/// through this shared ValueNotifier means a change from either screen (or
/// from the periodic poll below noticing the backend flipped it to 'busy'
/// on offer-accept, or back to 'available' on trip completion) is reflected
/// everywhere immediately.
class DriverAvailabilityController {
  static Timer? _timer;

  /// null while unknown/loading. UI treats null as "don't show a control
  /// yet" rather than defaulting to any particular status.
  static final ValueNotifier<String?> status = ValueNotifier<String?>(null);

  static Future<void> start() async {
    if (_timer != null) return; // already running
    await refresh();
    _timer = Timer.periodic(const Duration(seconds: 45), (_) => refresh());
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    status.value = null;
  }

  /// Re-fetches the real status from the server. Safe to call directly too
  /// (e.g. from a pull-to-refresh) without waiting for the next tick.
  static Future<void> refresh() async {
    try {
      status.value = await DriverService().fetchMyAvailabilityStatus();
    } catch (_) {
      // Network hiccup — leave the last known value as-is rather than
      // wiping it to null, same reasoning as DriverLocationReporter's trip
      // check: a transient failure shouldn't visibly blank out the UI.
    }
  }

  /// [newStatus] must be 'available' or 'unavailable' — 'busy' is never
  /// something the driver sets themselves, it's server-driven (offer
  /// accepted / trip completed). Optimistically updates [status] so the UI
  /// responds instantly, then confirms with the server; reverts on failure.
  static Future<Map<String, dynamic>> setStatus(String newStatus) async {
    final previous = status.value;
    status.value = newStatus;

    final result = await DriverService.updateMyStatus(newStatus);

    if (result['success'] != true) {
      status.value = previous;
    }

    return result;
  }
}
