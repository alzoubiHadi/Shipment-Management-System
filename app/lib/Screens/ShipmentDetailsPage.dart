import 'package:flutter/material.dart';
import '../API/ShipmentServices.dart';
import '../API/config.dart';
import '../models/Shipment.dart';

class ShipmentDetailsPage extends StatefulWidget {
  final Shipment shipment;

  const ShipmentDetailsPage({super.key, required this.shipment});

  @override
  State<ShipmentDetailsPage> createState() => _ShipmentDetailsPageState();
}

class _ShipmentDetailsPageState extends State<ShipmentDetailsPage> {
  late int selectedStatus;

  final Map<int, String> statuses = {
    0: 'Pending',
    1: 'Picked Up',
    2: 'In Transit',
    3: 'Delivered',
    4: 'Cancelled',
    5: 'New',
  };

  @override
  void initState() {
    super.initState();
    selectedStatus = widget.shipment.status;
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.shipment.statusColor;

    return Scaffold(
      backgroundColor: AppColors.bg,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.bg,
        title: const Text("Shipment Details"),
      ),

      bottomNavigationBar: widget.shipment.status == 5
          ? Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () async {
                  final service = ShipmentService();

                  bool res = await service.acceptShipment(
                    shipmentId: widget.shipment.id,
                    status: 1, // Accepted -> Pending
                  );

                  if (res) {
                    setState(() {
                      selectedStatus = 0;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Shipment accepted"),
                      ),
                    );
                  }
                },
                child: const Text("Accept"),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () async {
                  final service = ShipmentService();

                  bool res = await service.refuseShipment(
                    shipmentId: widget.shipment.id,
                    status: 0, // Cancelled
                  );

                  if (res) {
                    setState(() {
                      selectedStatus = 4;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Shipment refused"),
                      ),
                    );
                  }
                },
                child: const Text("Refuse"),
              ),
            ),
          ],
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text("Update Status"),
            onPressed: () async {
              final service = ShipmentService();

              bool res = await service.updateShipmentStatus(
                shipmentId: widget.shipment.id,
                status: selectedStatus.toString(),
              );

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    res ? "Saved successfully" : "Failed to update",
                  ),
                ),
              );
            },
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// Tracking Header
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
                    widget.shipment.trackingNumber,
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
                      color: color.withOpacity(.15),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      statuses[selectedStatus]!,
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

            /// Route Card
            _section(
              child: Column(
                children: [
                  _routeRow(
                    Icons.location_on,
                    "Origin",
                    widget.shipment.origin,
                  ),

                  const Divider(),

                  _routeRow(
                    Icons.flag,
                    "Destination",
                    widget.shipment.destination,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            /// Shipment Info
            _section(
              child: Column(
                children: [
                  _info("Shipment ID", widget.shipment.id.toString()),
                  _info("Weight", widget.shipment.weight),
                  _info("Description", widget.shipment.description),
                ],
              ),
            ),

            const SizedBox(height: 16),

            /// Timeline
            _section(
              child: Column(
                children: [
                  _info("Created", widget.shipment.created_at ?? "-"),
                  _info("Pickup Time", widget.shipment.pickup_time ?? "-"),
                  _info("Delivered At", widget.shipment.delivered_at ?? "-"),
                ],
              ),
            ),

            const SizedBox(height: 16),

            /// Status Update
            _section(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Change Status",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 12),

                  DropdownButtonFormField<int>(
                    value: selectedStatus,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: statuses.entries.map((e) {
                      return DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v == null) return;

                      setState(() {
                        selectedStatus = v;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _info(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(title, style: const TextStyle(color: AppColors.muted)),
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

  Widget _routeRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.gold),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.cream,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
