import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../API/DriverService.dart';
import '../API/ShipmentOfferService.dart';
import '../API/TruckService.dart';
import '../API/config.dart';
import '../models/ShipmentOffer.dart';
import '../models/Truck.dart';

/// Driver screen: shows the offers this driver currently qualifies for, and
/// lets them accept one by picking one of their own registered trucks.
class DriverOffersPage extends StatefulWidget {
  const DriverOffersPage({super.key});

  @override
  State<DriverOffersPage> createState() => _DriverOffersPageState();
}

class _DriverOffersPageState extends State<DriverOffersPage> {
  final _offerService = ShipmentOfferService();
  final _truckService = TruckService();
  final _driverService = DriverService();
  late Future<List<ShipmentOffer>> _offersFuture;
  bool _isAccepting = false;

  // UC-10: driver's own "available for work" toggle. null while loading.
  bool? _isAvailable;
  bool _isUpdatingAvailability = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadMyStatus();
  }

  void _refresh() {
    setState(() {
      _offersFuture = _offerService.fetchAvailableOffers();
    });
  }

  Future<void> _loadMyStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('id');
      final drivers = await _driverService.fetchDriver();
      final me = drivers.where((d) => d.user_id == userId).toList();
      if (!mounted || me.isEmpty) return;
      setState(() => _isAvailable = me.first.status == 'available');
    } catch (_) {
      // Leave _isAvailable null (toggle just won't show) rather than
      // blocking the offers list over a status-fetch failure.
    }
  }

  Future<void> _toggleAvailability(bool value) async {
    setState(() {
      _isUpdatingAvailability = true;
      _isAvailable = value;
    });

    final result = await DriverService.updateMyStatus(
      value ? 'available' : 'unavailable',
    );

    if (!mounted) return;
    setState(() => _isUpdatingAvailability = false);

    if (result['success'] != true) {
      // Revert on failure and let the driver know.
      setState(() => _isAvailable = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Could not update status'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _acceptOffer(ShipmentOffer offer) async {
    final trucks = await _truckService.fetchMyTrucks();

    if (!mounted) return;

    if (trucks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a truck in your profile before accepting a job'),
        ),
      );
      return;
    }

    final truck = await showModalBottomSheet<Truck>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Choose the truck for this job',
                style: TextStyle(
                  color: AppColors.cream,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...trucks.map((t) => ListTile(
                  leading: Icon(
                    t.hasRefrigeration
                        ? Icons.ac_unit
                        : Icons.local_shipping_outlined,
                    color: AppColors.gold,
                  ),
                  title: Text(t.truckNumber,
                      style: const TextStyle(color: AppColors.cream)),
                  subtitle: Text(t.truckType,
                      style: const TextStyle(color: AppColors.muted)),
                  onTap: () => Navigator.pop(context, t),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (truck == null) return;

    setState(() => _isAccepting = true);

    final result = await ShipmentOfferService.acceptOffer(
      offerId: offer.id,
      truckId: int.parse(truck.id),
    );

    if (!mounted) return;
    setState(() => _isAccepting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ??
            (result['success'] == true ? 'Job accepted' : 'Failed')),
        backgroundColor:
            result['success'] == true ? AppColors.success : AppColors.error,
      ),
    );

    if (result['success'] == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text('Available Offers', style: TextStyle(color: AppColors.cream)),
        iconTheme: const IconThemeData(color: AppColors.cream),
        actions: [
          if (_isAvailable != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Text(
                    _isAvailable! ? 'Available' : 'Unavailable',
                    style: TextStyle(
                      color: _isAvailable! ? AppColors.success : AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Switch(
                    value: _isAvailable!,
                    activeColor: AppColors.gold,
                    onChanged: _isUpdatingAvailability ? null : _toggleAvailability,
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
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
                            'No matching offers right now.',
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
                          Text(
                            '${offer.origin} → ${offer.destination}',
                            style: const TextStyle(
                              color: AppColors.cream,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${offer.requiredTruckType} · ${offer.orderType}'
                            '${offer.needsPermit ? " · permit" : ""}'
                            '${offer.isHazardous ? " · hazardous" : ""}'
                            '${offer.isFragile ? " · fragile" : ""}',
                            style: const TextStyle(color: AppColors.muted, fontSize: 12),
                          ),
                          if (offer.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              offer.description,
                              style: const TextStyle(color: AppColors.muted, fontSize: 12),
                            ),
                          ],
                          if (offer.priceToDriver.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Price: ${offer.priceToDriver}',
                              style: const TextStyle(
                                  color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: ElevatedButton(
                              onPressed: _isAccepting ? null : () => _acceptOffer(offer),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Accept',
                                style: TextStyle(
                                    color: AppColors.bg, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_isAccepting)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
            ),
        ],
      ),
    );
  }
}
