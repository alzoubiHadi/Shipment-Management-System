import 'package:flutter/material.dart';

import '../API/DriverService.dart';
import '../API/ShipmentOfferService.dart';
import '../API/TruckService.dart';
import '../API/config.dart';
import '../models/Driver.dart';
import '../models/ShipmentOffer.dart';
import '../models/Truck.dart';
import '../utils/logout_helper.dart';

/// Admin screen: shows every shipment offer logged by companies, its current
/// status, and how many drivers are eligible for it right now. Offers are
/// created by companies themselves now (UC-11, self-service) — this screen
/// is for oversight plus the two admin-only actions the workflow still
/// needs: setting a manual price (UC-13, CRM) and manually assigning an
/// escalated offer to a driver (UC-17, Super Admin).
class ShipmentOffersAdminPage extends StatefulWidget {
  const ShipmentOffersAdminPage({super.key});

  @override
  State<ShipmentOffersAdminPage> createState() =>
      _ShipmentOffersAdminPageState();
}

class _ShipmentOffersAdminPageState extends State<ShipmentOffersAdminPage> {
  final _service = ShipmentOfferService();
  late Future<List<ShipmentOffer>> _offersFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _offersFuture = _service.fetchAllOffers();
    });
  }

  Future<void> _cancelOffer(ShipmentOffer offer) async {
    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cancel offer', style: TextStyle(color: AppColors.cream)),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          style: const TextStyle(color: AppColors.cream),
          decoration: const InputDecoration(
            hintText: 'Reason for cancellation',
            hintStyle: TextStyle(color: AppColors.muted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, reasonController.text.trim()),
            child: const Text('Confirm', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty) return;

    final ok = await ShipmentOfferService.cancelOffer(
      offerId: offer.id,
      reason: reason,
    );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offer cancelled')),
      );
      _refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not cancel the offer')),
      );
    }
  }

  /// CRM Admin: set price_to_driver / price_to_client for an offer stuck
  /// awaiting manual pricing (UC-13).
  Future<void> _setManualPrice(ShipmentOffer offer) async {
    final driverPriceController = TextEditingController();
    final clientPriceController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Set manual price', style: TextStyle(color: AppColors.cream)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: driverPriceController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.cream),
              decoration: const InputDecoration(
                labelText: 'Price to driver (AED)',
                labelStyle: TextStyle(color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: clientPriceController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.cream),
              decoration: const InputDecoration(
                labelText: 'Price to client (AED)',
                labelStyle: TextStyle(color: AppColors.muted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final priceToDriver = double.tryParse(driverPriceController.text.trim());
    final priceToClient = double.tryParse(clientPriceController.text.trim());

    if (priceToDriver == null || priceToClient == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid numeric prices')),
      );
      return;
    }

    final result = await ShipmentOfferService.manualPrice(
      offerId: offer.id,
      priceToDriver: priceToDriver,
      priceToClient: priceToClient,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? ''),
        backgroundColor:
            result['success'] == true ? AppColors.success : AppColors.error,
      ),
    );
    if (result['success'] == true) _refresh();
  }

  /// Super Admin: push a new matching round right now instead of waiting
  /// for the scheduled timeout.
  Future<void> _rematch(ShipmentOffer offer) async {
    final result = await ShipmentOfferService.rematch(offer.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? ''),
        backgroundColor:
            result['success'] == true ? AppColors.success : AppColors.error,
      ),
    );
    if (result['success'] == true) _refresh();
  }

  /// Super Admin: hand-assign an escalated offer (every eligible driver
  /// exhausted) to a chosen driver + one of that driver's trucks (UC-17).
  Future<void> _assignDriver(ShipmentOffer offer) async {
    final driverService = DriverService();
    final truckService = TruckService();

    List<Driver> drivers;
    try {
      drivers = await driverService.fetchDriver();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load drivers: $e')),
      );
      return;
    }

    if (!mounted) return;

    Driver? selectedDriver;
    Truck? selectedTruck;
    List<Truck> driverTrucks = [];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Assign driver',
                style: TextStyle(color: AppColors.cream)),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Driver>(
                    initialValue: selectedDriver,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: AppColors.cream),
                    decoration: const InputDecoration(
                      labelText: 'Driver',
                      labelStyle: TextStyle(color: AppColors.muted),
                    ),
                    items: drivers
                        .map((d) => DropdownMenuItem(
                              value: d,
                              child: Text('${d.name} (${d.status})'),
                            ))
                        .toList(),
                    onChanged: (d) async {
                      setDialogState(() {
                        selectedDriver = d;
                        selectedTruck = null;
                        driverTrucks = [];
                      });
                      if (d == null) return;
                      try {
                        final trucks =
                            await truckService.fetchTrucksForDriver(d.user_id);
                        setDialogState(() => driverTrucks = trucks);
                      } catch (_) {
                        setDialogState(() => driverTrucks = []);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Truck>(
                    initialValue: selectedTruck,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: AppColors.cream),
                    decoration: const InputDecoration(
                      labelText: 'Truck',
                      labelStyle: TextStyle(color: AppColors.muted),
                    ),
                    items: driverTrucks
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text('${t.truckNumber} — ${t.truckType}'),
                            ))
                        .toList(),
                    onChanged: (t) => setDialogState(() => selectedTruck = t),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.muted)),
              ),
              TextButton(
                onPressed: (selectedDriver == null || selectedTruck == null)
                    ? null
                    : () => Navigator.pop(context, {
                          'driver': selectedDriver,
                          'truck': selectedTruck,
                        }),
                child: const Text('Assign',
                    style: TextStyle(color: AppColors.gold)),
              ),
            ],
          );
        },
      ),
    );

    if (result == null) return;

    final driver = result['driver'] as Driver;
    final truck = result['truck'] as Truck;

    final assignResult = await ShipmentOfferService.assignDriver(
      offerId: offer.id,
      driverId: int.parse(driver.id),
      truckId: int.parse(truck.id),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(assignResult['message']?.toString() ?? ''),
        backgroundColor: assignResult['success'] == true
            ? AppColors.success
            : AppColors.error,
      ),
    );
    if (assignResult['success'] == true) _refresh();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return AppColors.success;
      case 'cancelled':
      case 'expired':
        return AppColors.muted;
      case 'awaiting_manual_price':
        return AppColors.gold;
      case 'escalated':
        return AppColors.error;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text('Shipment Offers', style: TextStyle(color: AppColors.cream)),
        iconTheme: const IconThemeData(color: AppColors.cream),
        actions: [logoutAction(context)],
      ),
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<ShipmentOffer>>(
          future: _offersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              );
            }
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Could not load offers',
                  style: TextStyle(color: AppColors.error),
                ),
              );
            }

            final offers = snapshot.data ?? [];
            if (offers.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: Text(
                        'No offers yet. Companies create these themselves.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: offers.length,
              itemBuilder: (context, index) {
                final offer = offers[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${offer.origin} → ${offer.destination}',
                              style: const TextStyle(
                                color: AppColors.cream,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _statusColor(offer.status).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              offer.status,
                              style: TextStyle(
                                color: _statusColor(offer.status),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        offer.companyName.isEmpty
                            ? 'Client unknown'
                            : offer.companyName,
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${offer.requiredTruckType} · ${offer.orderType}'
                        '${offer.needsPermit ? " · permit" : ""}'
                        '${offer.isHazardous ? " · hazardous" : ""}'
                        '${offer.isFragile ? " · fragile" : ""}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                      if (offer.priceToClient.isNotEmpty && offer.priceToClient != '0') ...[
                        const SizedBox(height: 4),
                        Text(
                          'Price to client: ${offer.priceToClient} AED'
                          '${offer.pricingMode != null ? " (${offer.pricingMode})" : ""}',
                          style: const TextStyle(color: AppColors.gold, fontSize: 12),
                        ),
                      ],
                      if (offer.status == 'pending') ...[
                        const SizedBox(height: 6),
                        Text(
                          '${offer.eligibleDriversCount} eligible driver(s) right now',
                          style: const TextStyle(
                              color: AppColors.gold, fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 4,
                        children: [
                          if (offer.isAwaitingManualPrice)
                            TextButton(
                              onPressed: () => _setManualPrice(offer),
                              child: const Text('Set Price',
                                  style: TextStyle(
                                      color: AppColors.gold, fontSize: 12)),
                            ),
                          if (offer.isPending)
                            TextButton(
                              onPressed: () => _rematch(offer),
                              child: const Text('Rematch',
                                  style: TextStyle(
                                      color: AppColors.info, fontSize: 12)),
                            ),
                          if (offer.isEscalated)
                            TextButton(
                              onPressed: () => _assignDriver(offer),
                              child: const Text('Assign Driver',
                                  style: TextStyle(
                                      color: AppColors.gold, fontSize: 12)),
                            ),
                          if (offer.isPending ||
                              offer.isAwaitingManualPrice ||
                              offer.isEscalated)
                            TextButton(
                              onPressed: () => _cancelOffer(offer),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: AppColors.error, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
