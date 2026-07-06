import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../API/config.dart';

class Shipment {
  final int id;
  final String trackingNumber;
  final String origin;
  final String destination;
  final String weight;
  final String description;
  final int status;
  final String pickup_time;
  final String delivered_at;
  final String created_at;

  // 7-stage tracking timeline
  final int currentStage;
  final String headingToPickupAt;
  final String loadedAt;
  final String departedToBorderAt;
  final String borderClearedAt;
  final String arrivedAtDestinationAt;
  final String unloadedAt;
  final String podSignature;
  final String podRecipientName;

  Shipment({
    required this.id,
    required this.trackingNumber,
    required this.origin,
    required this.destination,
    required this.weight,
    required this.description,
    required this.status,
    required this.pickup_time,
    required this.delivered_at,
    required this.created_at,
    this.currentStage = 0,
    this.headingToPickupAt = '',
    this.loadedAt = '',
    this.departedToBorderAt = '',
    this.borderClearedAt = '',
    this.arrivedAtDestinationAt = '',
    this.unloadedAt = '',
    this.podSignature = '',
    this.podRecipientName = '',
  });

  static const stageLabels = <int, String>{
    1: 'Heading to pickup',
    2: 'Loaded',
    3: 'En route to border',
    4: 'Border cleared',
    5: 'Arrived at destination',
    6: 'Unloaded',
    7: 'Delivered (signed)',
  };

  factory Shipment.fromJson(Map<String, dynamic> json) {
    return Shipment(
      id: json['id'] ?? 0,
      trackingNumber: json['tracking_number']?.toString() ?? '',
      origin: json['origin']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      weight: json['weight']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      pickup_time: json['pickup_time']?.toString() ?? '',
      delivered_at: json['delivered_at']?.toString() ?? '',
      created_at: json['created_at']?.toString() ?? '',
      status: json['status'] ?? 0,
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
    );
  }

  // Derive display properties from status
  Color get statusColor {
    switch (status) {
      case 2:
        return AppColors.success;
      case 1:
        return AppColors.info;
      case 0:
        return AppColors.gold;
      case 3:
        return AppColors.error;
        case 5:
          return AppColors.cream;
      default:
        return AppColors.muted;
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
