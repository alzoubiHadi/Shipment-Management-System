import 'package:flutter/material.dart';

import '../API/ShipmentOfferService.dart';
import '../API/config.dart';
import '../models/ShipmentOffer.dart';
import 'AddShipmentOfferPage.dart';

/// Admin screen: shows every shipment offer that has been logged, with its
/// current status and how many drivers are eligible for it right now.
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

  Future<void> _openAddOffer() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddShipmentOfferPage()),
    );
    if (created == true) _refresh();
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

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return AppColors.success;
      case 'cancelled':
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
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.gold,
        onPressed: _openAddOffer,
        child: const Icon(Icons.add, color: AppColors.bg),
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
              return Center(
                child: Text(
                  'Could not load offers',
                  style: const TextStyle(color: AppColors.error),
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
                        'No offers yet. Tap + to log one.',
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
                        'Cargo: ${offer.cargoType}'
                        '${offer.requiresCrossBorder ? " · cross-border" : ""}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                      if (offer.status == 'pending') ...[
                        const SizedBox(height: 6),
                        Text(
                          '${offer.eligibleDriversCount} eligible driver(s) right now',
                          style: const TextStyle(
                              color: AppColors.gold, fontSize: 12),
                        ),
                      ],
                      if (offer.status == 'pending') ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _cancelOffer(offer),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: AppColors.error, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
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
