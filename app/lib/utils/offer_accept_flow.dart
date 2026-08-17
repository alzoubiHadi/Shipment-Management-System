import 'package:flutter/material.dart';

import '../API/ShipmentOfferService.dart';
import '../API/config.dart';
import '../models/ShipmentOffer.dart';

/// Shared "confirm, then accept" flow — used by both the Available
/// Shipments list (Accept button) and the Shipment Details page (Accept
/// Shipment button), so the confirmation dialog and result handling only
/// live in one place. Returns true if the offer was accepted.
///
/// No more truck picker here (2026-08-21): under the Driver 1<->1 Truck
/// rule a driver only ever has one registered truck, so there was never a
/// real choice to make — the backend now resolves and validates the
/// driver's own linked truck automatically on accept.
Future<bool> acceptOfferFlow(BuildContext context, ShipmentOffer offer) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Accept this job?', style: TextStyle(color: AppColors.cream)),
      content: Text(
        '${offer.origin} -> ${offer.destination}',
        style: const TextStyle(color: AppColors.muted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Accept', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );

  if (confirmed != true) return false;
  if (!context.mounted) return false;

  final result = await ShipmentOfferService.acceptOffer(offerId: offer.id);

  if (!context.mounted) return result['success'] == true;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(result['message']?.toString() ?? (result['success'] == true ? 'Job accepted' : 'Failed')),
      backgroundColor: result['success'] == true ? AppColors.success : AppColors.error,
    ),
  );

  return result['success'] == true;
}
