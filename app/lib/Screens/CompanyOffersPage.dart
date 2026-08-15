import 'package:flutter/material.dart';

import '../API/ShipmentOfferService.dart';
import '../API/config.dart';
import '../models/Appuser.dart';
import '../models/ShipmentOffer.dart';
import 'AddShipmentOfferPage.dart';
import 'AppBarWidget.dart';

/// Company self-service offers tab (UC-11): shows this company's own
/// shipment offers (pending / awaiting manual price / escalated / accepted
/// / cancelled) and lets the company create a new one directly.
class CompanyOffersPage extends StatefulWidget {
  final AppUser user;
  const CompanyOffersPage({super.key, required this.user});

  @override
  State<CompanyOffersPage> createState() => _CompanyOffersPageState();
}

class _CompanyOffersPageState extends State<CompanyOffersPage> {
  final _service = ShipmentOfferService();
  late Future<List<ShipmentOffer>> _offersFuture;

  @override
  void initState() {
    super.initState();
    _offersFuture = _service.fetchMyOffers();
  }

  void _refresh() => setState(() {
        _offersFuture = _service.fetchMyOffers();
      });

  Future<void> _openCreateForm() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddShipmentOfferPage()),
    );
    if (created == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateForm,
        backgroundColor: AppColors.gold,
        icon: const Icon(Icons.add, color: AppColors.bg),
        label: const Text(
          'New Offer',
          style: TextStyle(color: AppColors.bg, fontWeight: FontWeight.w600),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: CustomScrollView(
          slivers: [
            AppBarWidget(user: widget.user, subtitle: 'My Shipment Offers'),
            SliverToBoxAdapter(
              child: FutureBuilder<List<ShipmentOffer>>(
                future: _offersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(
                        child:
                            CircularProgressIndicator(color: AppColors.gold),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 60),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_rounded,
                              color: AppColors.error, size: 48),
                          const SizedBox(height: 16),
                          const Text(
                            'Failed to load offers',
                            style: TextStyle(
                                color: AppColors.cream,
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12),
                          ),
                          const SizedBox(height: 20),
                          TextButton.icon(
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh_rounded,
                                color: AppColors.gold),
                            label: const Text('Retry',
                                style: TextStyle(color: AppColors.gold)),
                          ),
                        ],
                      ),
                    );
                  }

                  final offers = snapshot.data ?? [];

                  if (offers.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 24, vertical: 60),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_shipping_outlined,
                              color: AppColors.muted, size: 48),
                          SizedBox(height: 16),
                          Text(
                            'No offers yet',
                            style: TextStyle(
                                color: AppColors.cream,
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Tap "New Offer" to request a shipment.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                    child: Column(
                      children: [
                        for (int i = 0; i < offers.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          _OfferCard(offer: offers[i], onChanged: _refresh),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  final ShipmentOffer offer;
  final VoidCallback onChanged;

  const _OfferCard({required this.offer, required this.onChanged});

  Color get _statusColor {
    switch (offer.status) {
      case 'pending':
        return AppColors.info;
      case 'awaiting_manual_price':
        return AppColors.gold;
      case 'escalated':
        return AppColors.error;
      case 'accepted':
        return AppColors.success;
      case 'cancelled':
      case 'expired':
        return AppColors.muted;
      default:
        return AppColors.muted;
    }
  }

  String get _statusLabel {
    switch (offer.status) {
      case 'pending':
        return 'Matching drivers';
      case 'awaiting_manual_price':
        return 'Awaiting price';
      case 'escalated':
        return 'Escalated';
      case 'accepted':
        return 'Accepted';
      case 'cancelled':
        return 'Cancelled';
      case 'expired':
        return 'Expired';
      default:
        return offer.status;
    }
  }

  Future<void> _raisePrice(BuildContext context) async {
    final controller =
        TextEditingController(text: offer.priceToClient);
    final newPrice = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Raise price to client',
            style: TextStyle(color: AppColors.cream)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.cream),
          decoration: const InputDecoration(
            labelText: 'New price (AED)',
            labelStyle: TextStyle(color: AppColors.muted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim());
              Navigator.pop(ctx, v);
            },
            child: const Text('Save',
                style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );

    if (newPrice == null) return;

    final result = await ShipmentOfferService.raisePrice(
      offerId: offer.id,
      priceToClient: newPrice,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? ''),
        backgroundColor:
            result['success'] == true ? AppColors.success : AppColors.error,
      ),
    );
    if (result['success'] == true) onChanged();
  }

  Future<void> _cancel(BuildContext context) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cancel offer',
            style: TextStyle(color: AppColors.cream)),
        content: TextField(
          controller: reasonController,
          style: const TextStyle(color: AppColors.cream),
          decoration: const InputDecoration(
            labelText: 'Reason',
            labelStyle: TextStyle(color: AppColors.muted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back',
                style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, reasonController.text.trim()),
            child: const Text('Cancel Offer',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty) return;

    final ok = await ShipmentOfferService.cancelOffer(
      offerId: offer.id,
      reason: reason,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Offer cancelled' : 'Failed to cancel offer'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
    if (ok) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final canModify = offer.isPending;

    return Container(
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
            children: [
              Expanded(
                child: Text(
                  '${offer.origin} → ${offer.destination}',
                  style: const TextStyle(
                    color: AppColors.cream,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: _statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${offer.requiredTruckType} · ${offer.orderType} · ${offer.eligibleDriversCount} eligible driver(s)',
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          if (offer.priceToClient.isNotEmpty && offer.priceToClient != '0') ...[
            const SizedBox(height: 4),
            Text(
              'Price to client: ${offer.priceToClient} AED'
              '${offer.pricingMode == 'manual' ? ' (manual)' : ''}',
              style: const TextStyle(color: AppColors.gold, fontSize: 12),
            ),
          ],
          if (canModify) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _raisePrice(context),
                  icon: const Icon(Icons.trending_up,
                      color: AppColors.gold, size: 16),
                  label: const Text('Raise price',
                      style: TextStyle(color: AppColors.gold, fontSize: 12)),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _cancel(context),
                  icon: const Icon(Icons.close, color: AppColors.error, size: 16),
                  label: const Text('Cancel',
                      style: TextStyle(color: AppColors.error, fontSize: 12)),
                ),
              ],
            ),
          ] else if (offer.status == 'awaiting_manual_price' ||
              offer.status == 'escalated') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _cancel(context),
                  icon: const Icon(Icons.close, color: AppColors.error, size: 16),
                  label: const Text('Cancel',
                      style: TextStyle(color: AppColors.error, fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
