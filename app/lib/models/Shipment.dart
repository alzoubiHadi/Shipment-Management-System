import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../API/config.dart';

class Shipment {
  final int id;
  final int? driverId;
  final String trackingNumber;
  final String origin;
  final String destination;
  final String weight;
  final String description;
  final int status;
  final String pickup_time;
  final String delivered_at;
  final String created_at;

  // 'internal' (domestic, 6 stages) or 'external' (cross-border, 8
  // stages) — determines which of the two tracking timelines below
  // applies (see stageLabels / driverAdvanceMax / totalStages). Mirrors
  // Shipment::order_type on the backend, defaulted the same way.
  final String orderType;

  // Tracking timeline (stage numbering/meaning depends on orderType —
  // see stageLabels getter below; internal has 6 stages, external has 8).
  final int currentStage;
  final String headingToPickupAt;
  final String loadedAt;
  final String departedToBorderAt;
  final String borderClearedAt;
  final String arrivedAtDestinationAt;
  final String unloadedAt;
  final String podSignature;
  final String podRecipientName;
  // 2026-08-25: proof-of-delivery document (photo or file) — replaces
  // podSignature for shipments delivered after this change. podSignature
  // is kept above purely for older shipments that still only have one.
  final String podDocumentPath;
  // Set only once the company confirms receipt (the final "Completed"
  // stage) — mirrors company_confirmed_at on the backend.
  final String companyConfirmedAt;

  // UC-20: not_delivered -> awaiting_confirmation -> confirmed | disputed.
  // Separate from [status] (the coarse overall lifecycle status) — this is
  // specifically the driver-delivered/company-confirmed handoff.
  final String deliveryStatus;
  final String disputeReason;

  // Only populated when this Shipment came from the /track endpoint
  // (ShipmentService.fetchOneByTrackingNumber), which embeds a whitelisted
  // driver resource including live GPS coordinates — see
  // CompanyFacingDriverResource on the backend. Null on every other
  // shipment-list endpoint, which don't send a nested 'driver' object.
  final String? driverName;
  final double? driverLastLat;
  final double? driverLastLng;
  final DateTime? driverLastLocationAt;

  Shipment({
    required this.id,
    this.driverId,
    required this.trackingNumber,
    required this.origin,
    required this.destination,
    required this.weight,
    required this.description,
    required this.status,
    required this.pickup_time,
    required this.delivered_at,
    required this.created_at,
    this.orderType = 'internal',
    this.currentStage = 0,
    this.headingToPickupAt = '',
    this.loadedAt = '',
    this.departedToBorderAt = '',
    this.borderClearedAt = '',
    this.arrivedAtDestinationAt = '',
    this.unloadedAt = '',
    this.podSignature = '',
    this.podRecipientName = '',
    this.podDocumentPath = '',
    this.companyConfirmedAt = '',
    this.deliveryStatus = 'not_delivered',
    this.disputeReason = '',
    this.driverName,
    this.driverLastLat,
    this.driverLastLng,
    this.driverLastLocationAt,
  });

  bool get isAwaitingCompanyConfirmation => deliveryStatus == 'awaiting_confirmation';
  bool get isDeliveryConfirmed => deliveryStatus == 'confirmed';
  bool get isDeliveryDisputed => deliveryStatus == 'disputed';

  // Two tracking timelines, keyed by orderType — mirrors
  // Shipment::STAGE_LABELS on the backend exactly (agreed 2026-08-16).
  // Internal (domestic) shipments skip the two border stages; external
  // (cross-border) keep them. The last two stages in both lists are
  // never advanced by the driver directly: "Uploading delivery note" is
  // the proof-of-delivery signature capture, "Completed" only happens
  // when the company confirms receipt.
  static const Map<String, Map<int, String>> _stageLabelsByType = {
    'internal': {
      1: 'Going to load',
      2: 'Loading',
      3: 'To destination',
      4: 'Offloading',
      5: 'Uploading delivery note',
      6: 'Completed',
    },
    'external': {
      1: 'Going to load',
      2: 'Loading',
      3: 'To border',
      4: 'Crossing the border',
      5: 'To destination',
      6: 'Offloading',
      7: 'Uploading delivery note',
      8: 'Completed',
    },
  };

  /// This shipment's stage labels, in order, for its own [orderType].
  Map<int, String> get stageLabels =>
      _stageLabelsByType[orderType] ?? _stageLabelsByType['internal']!;

  /// Total stage count for this shipment (6 for internal, 8 for external).
  int get totalStages => stageLabels.length;

  /// Last stage number the driver advances through one tap at a time —
  /// the stage right after this is the delivery-note upload, handled by
  /// a dedicated action (signature capture), not the plain "next stage"
  /// button. Mirrors Shipment::driverAdvanceMaxFor() on the backend.
  int get driverAdvanceMax => totalStages - 2;

  factory Shipment.fromJson(Map<String, dynamic> json) {
    final driver = json['driver'] is Map ? Map<String, dynamic>.from(json['driver']) : null;

    return Shipment(
      id: json['id'] ?? 0,
      driverId: json['driver_id'] is int
          ? json['driver_id']
          : int.tryParse(json['driver_id']?.toString() ?? ''),
      trackingNumber: json['tracking_number']?.toString() ?? '',
      origin: json['origin']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      weight: json['weight']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      pickup_time: json['pickup_time']?.toString() ?? '',
      delivered_at: json['delivered_at']?.toString() ?? '',
      created_at: json['created_at']?.toString() ?? '',
      status: json['status'] ?? 0,
      orderType: json['order_type']?.toString() ?? 'internal',
      currentStage: json['current_stage'] is int
          ? json['current_stage']
          : int.tryParse(json['current_stage']?.toString() ?? '') ?? 0,
      headingToPickupAt: json['heading_to_pickup_at']?.toString() ?? '',
      loadedAt: json['loaded_at']?.toString() ?? '',
      departedToBorderAt: json['departed_to_border_at']?.toString() ?? '',
      borderClearedAt: json['border_cleared_at']?.toString() ?? '',
      arrivedAtDestinationAt:
          json['arrived_at_destination_at']?.toString() ?? '',
      unloadedAt: json['unloaded_at']?.toString() ?? '',
      podSignature: json['pod_signature']?.toString() ?? '',
      podRecipientName: json['pod_recipient_name']?.toString() ?? '',
      podDocumentPath: json['pod_document_path']?.toString() ?? '',
      deliveryStatus: json['delivery_status']?.toString() ?? 'not_delivered',
      disputeReason: json['dispute_reason']?.toString() ?? '',
      companyConfirmedAt: json['company_confirmed_at']?.toString() ?? '',
      driverName: driver?['name']?.toString(),
      driverLastLat: driver?['last_lat'] != null ? double.tryParse(driver!['last_lat'].toString()) : null,
      driverLastLng: driver?['last_lng'] != null ? double.tryParse(driver!['last_lng'].toString()) : null,
      driverLastLocationAt: driver?['last_location_at'] != null
          ? DateTime.tryParse(driver!['last_location_at'].toString())
          : null,
    );
  }

  // Derive display properties from status
  // 2026-08-27: was still reading the old dark `AppColors` palette — every
  // other status/badge color in the app reads from `LightColors` now (see
  // FMS design-system unification), so this was the one place a shipment
  // status chip could render in the wrong (dark) palette against the app's
  // light backgrounds. Swapped to the equivalent `LightColors` tokens.
  Color get statusColor {
    switch (status) {
      case 2:
        return LightColors.success;
      case 1:
        return LightColors.info;
      case 0:
        return LightColors.gold;
      case 3:
        return LightColors.error;
      case 5:
        return LightColors.cream;
      default:
        return LightColors.muted;
    }
  }

  IconData get icon {
    switch (status) {
      case 2:
        return Icons.check_circle_rounded;
      case 1:
        return Icons.local_shipping_rounded;
      case 0:
        return Icons.access_time_rounded;
      case 3:
        return Icons.warning_amber_rounded;
      case 5:
        return Icons.warning_amber_sharp;
      default:
        return Icons.help_outline_rounded;
    }
  }
}
