import 'package:flutter/material.dart';

import '../API/ShipmentOfferService.dart';
import '../API/config.dart';
import '../models/Appuser.dart';
import '../models/ShipmentOffer.dart';
import 'AddShipmentOfferPage.dart';

/// Company self-service offers tab (UC-11): shows this company's own
/// shipment offers (pending / awaiting manual price / escalated / accepted
/// / cancelled) and lets the company create a new one directly.
///
/// Light-themed (2026-08-17 audit) — this screen is company-only (unlike
/// ShipmentTrackingPage/StatementPage/NotificationsPage, which stay dark
/// because they're shared with other roles), so unlike those it had simply
/// been missed during the 5-phase company redesign rather than deliberately
/// deferred.
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
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: LightColors.textPrimary),
        title: const Text('My Shipment Offers',
            style: TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateForm,
        backgroundColor: LightColors.gold,
        icon: const Icon(Icons.add, color: LightColors.textPrimary),
        label: const Text(
          'New Offer',
          style: TextStyle(color: LightColors.textPrimary, fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        color: LightColors.gold,
        onRefresh: () async => _refresh(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: FutureBuilder<List<ShipmentOffer>>(
                future: _offersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(
                        child: CircularProgressIndicator(color: LightColors.gold),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_rounded, color: LightColors.error, size: 48),
                          const SizedBox(height: 16),
                          const Text(
                            'Failed to load offers',
                            style: TextStyle(color: LightColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: LightColors.textSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 20),
                          TextButton.icon(
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh_rounded, color: LightColors.goldMuted),
                            label: const Text('Retry', style: TextStyle(color: LightColors.goldMuted)),
                          ),
                        ],
                      ),
                    );
                  }

                  final offers = snapshot.data ?? [];

                  if (offers.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 60),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_shipping_outlined, color: LightColors.textSecondary, size: 48),
                          SizedBox(height: 16),
                          Text(
                            'No offers yet',
                            style: TextStyle(color: LightColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Tap "New Offer" to request a shipment.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: LightColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
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
        return LightColors.navy;
      case 'awaiting_manual_price':
        return LightColors.pending;
      case 'escalated':
        return LightColors.error;
      case 'accepted':
        return LightColors.success;
      case 'cancelled':
      case 'expired':
        return LightColors.textSecondary;
      default:
        return LightColors.textSecondary;
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
    final controller = TextEditingController(text: offer.priceToClient);
    final newPrice = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LightColors.surface,
        title: const Text('Raise price to client',
            style: TextStyle(color: LightColors.textPrimary, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: LightColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'New price (AED)',
            labelStyle: TextStyle(color: LightColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: LightColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim());
              Navigator.pop(ctx, v);
            },
            child: const Text('Save', style: TextStyle(color: LightColors.goldMuted, fontWeight: FontWeight.w700)),
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
        backgroundColor: result['success'] == true ? LightColors.success : LightColors.error,
      ),
    );
    if (result['success'] == true) onChanged();
  }

  Future<void> _cancel(BuildContext context) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LightColors.surface,
        title: const Text('Cancel offer', style: TextStyle(color: LightColors.textPrimary, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: reasonController,
          style: const TextStyle(color: LightColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Reason',
            labelStyle: TextStyle(color: LightColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back', style: TextStyle(color: LightColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, reasonController.text.trim()),
            child: const Text('Cancel Offer', style: TextStyle(color: LightColors.error, fontWeight: FontWeight.w700)),
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
        backgroundColor: ok ? LightColors.success : LightColors.error,
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
        color: LightColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LightColors.border),
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
                    color: LightColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: _statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${offer.requiredTruckType} · ${offer.orderType} · ${offer.eligibleDriversCount} eligible driver(s)',
            style: const TextStyle(color: LightColors.textSecondary, fontSize: 11),
          ),
          if (offer.priceToClient.isNotEmpty && offer.priceToClient != '0') ...[
            const SizedBox(height: 4),
            Text(
              'Price to client: ${offer.priceToClient} AED'
              '${offer.pricingMode == 'manual' ? ' (manual)' : ''}',
              style: const TextStyle(color: LightColors.goldMuted, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
          if (canModify) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _raisePrice(context),
                  icon: const Icon(Icons.trending_up, color: LightColors.goldMuted, size: 16),
                  label: const Text('Raise price', style: TextStyle(color: LightColors.goldMuted, fontSize: 12)),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _cancel(context),
                  icon: const Icon(Icons.close, color: LightColors.error, size: 16),
                  label: const Text('Cancel', style: TextStyle(color: LightColors.error, fontSize: 12)),
                ),
              ],
            ),
          ] else if (offer.status == 'awaiting_manual_price' || offer.status == 'escalated') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _cancel(context),
                  icon: const Icon(Icons.close, color: LightColors.error, size: 16),
                  label: const Text('Cancel', style: TextStyle(color: LightColors.error, fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
