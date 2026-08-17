import 'package:flutter/material.dart';

import '../API/ShipmentOfferService.dart';
import '../API/TruckService.dart';
import '../API/config.dart';
import '../models/ShipmentOffer.dart';
import '../models/Truck.dart';

/// Shared "pick a truck, then accept" flow — used by both the Available
/// Shipments list (Accept button) and the Shipment Details page (Accept
/// Shipment button), so the truck-picker sheet and result handling only
/// live in one place. Returns true if the offer was accepted.
Future<bool> acceptOfferFlow(BuildContext context, ShipmentOffer offer) async {
  final trucks = await TruckService().fetchMyTrucks();

  if (!context.mounted) return false;

  if (trucks.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add a truck in your profile before accepting a job')),
    );
    return false;
  }

  final truck = await showModalBottomSheet<Truck>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Choose the truck for this job', style: TextStyle(color: AppColors.cream, fontWeight: FontWeight.w600)),
          ),
          ...trucks.map((t) => ListTile(
                leading: Icon(t.hasRefrigeration ? Icons.ac_unit : Icons.local_shipping_outlined, color: AppColors.gold),
                title: Text(t.truckNumber, style: const TextStyle(color: AppColors.cream)),
                subtitle: Text(t.truckType, style: const TextStyle(color: AppColors.muted)),
                onTap: () => Navigator.pop(ctx, t),
              )),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (truck == null) return false;

  final result = await ShipmentOfferService.acceptOffer(offerId: offer.id, truckId: int.parse(truck.id));

  if (!context.mounted) return result['success'] == true;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(result['message']?.toString() ?? (result['success'] == true ? 'Job accepted' : 'Failed')),
      backgroundColor: result['success'] == true ? AppColors.success : AppColors.error,
    ),
  );

  return result['success'] == true;
}
