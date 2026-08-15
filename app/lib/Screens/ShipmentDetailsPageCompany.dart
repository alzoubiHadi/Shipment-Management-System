import 'package:flutter/material.dart';
import '../API/config.dart';
import '../models/Shipment.dart';
import 'ShipmentTrackingPage.dart';

class ShipmentDetailsPageCompany extends StatelessWidget {
  final Shipment shipment;

  const ShipmentDetailsPageCompany({
    super.key,
    required this.shipment,
  });

  @override
  Widget build(BuildContext context) {
    final color = shipment.statusColor;

    return Scaffold(
      backgroundColor: AppColors.bg,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.bg,
        title: const Text("Shipment Details"),
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShipmentTrackingPage(
                    shipment: shipment,
                    readOnly: true,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.timeline, color: AppColors.gold),
            label: const Text(
              'View Tracking Timeline',
              style: TextStyle(color: AppColors.gold),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// HEADER (TRACKING + STATUS)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    shipment.trackingNumber,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cream,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      statusLabel(shipment.status),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            /// ROUTE
            _section(
              child: Column(
                children: [
                  _row("Origin", shipment.origin),
                  const Divider(),
                  _row("Destination", shipment.destination),
                ],
              ),
            ),

            const SizedBox(height: 16),

            /// BASIC INFO
            _section(
              child: Column(
                children: [
                  _row("Shipment ID", shipment.id.toString()),
                  _row("Weight", shipment.weight),
                  _row("Description", shipment.description),
                ],
              ),
            ),

            const SizedBox(height: 16),

            /// TIMELINE
            _section(
              child: Column(
                children: [
                  _row("Created", shipment.created_at),
                  _row("Pickup Time", shipment.pickup_time),
                  _row("Delivered At", shipment.delivered_at),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// SECTION WRAPPER
  Widget _section({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }

  /// STRICT ROW (ONLY SHOW WHAT YOU PASS)
  Widget _row(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              title,
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.cream,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}