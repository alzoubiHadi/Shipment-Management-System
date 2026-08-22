import 'package:flutter/material.dart';

import '../API/ShipmentOfferService.dart';
import '../API/config.dart';
import '../l10n/app_localizations.dart';
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
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: LightColors.textPrimary),
        title: Text(t.myShipmentOffersTitle,
            style: const TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateForm,
        backgroundColor: LightColors.gold,
        icon: const Icon(Icons.add, color: LightColors.textPrimary),
        label: Text(
          t.newOfferButton,
          style: const TextStyle(color: LightColors.textPrimary, fontWeight: FontWeight.w700),
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
                          Text(
                            t.failedToLoadOffers,
                            style: const TextStyle(color: LightColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
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
                            label: Text(t.commonRetry, style: const TextStyle(color: LightColors.goldMuted)),
                          ),
                        ],
                      ),
                    );
                  }

                  final offers = snapshot.data ?? [];

                  if (offers.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_shipping_outlined, color: LightColors.textSecondary, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            t.noOffersYet,
                            style: const TextStyle(color: LightColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            t.tapNewOfferHint,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: LightColors.textSecondary, fontSize: 12),
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

  String _statusLabel(AppLocalizations t) {
    switch (offer.status) {
      case 'pending':
        return t.offerStatusMatchingDrivers;
      case 'awaiting_manual_price':
        return t.offerStatusAwaitingPrice;
      case 'escalated':
        return t.offerStatusEscalated;
      case 'accepted':
        return t.offerStatusAccepted;
      case 'cancelled':
        return t.offerStatusCancelled;
      case 'expired':
        return t.offerStatusExpired;
      default:
        return offer.status;
    }
  }

  Future<void> _raisePrice(BuildContext context) async {
    final t = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: offer.priceToClient);
    final newPrice = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LightColors.surface,
        title: Text(t.raisePriceDialogTitle,
            style: const TextStyle(color: LightColors.textPrimary, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: LightColors.textPrimary),
          decoration: InputDecoration(
            labelText: t.newPriceAedLabel,
            labelStyle: const TextStyle(color: LightColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.commonCancel, style: const TextStyle(color: LightColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim());
              Navigator.pop(ctx, v);
            },
            child: Text(t.commonSave, style: const TextStyle(color: LightColors.goldMuted, fontWeight: FontWeight.w700)),
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
    final t = AppLocalizations.of(context)!;
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LightColors.surface,
        title: Text(t.cancelOfferDialogTitle, style: const TextStyle(color: LightColors.textPrimary, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: reasonController,
          style: const TextStyle(color: LightColors.textPrimary),
          decoration: InputDecoration(
            labelText: t.reasonLabel,
            labelStyle: const TextStyle(color: LightColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.commonBack, style: const TextStyle(color: LightColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, reasonController.text.trim()),
            child: Text(t.cancelOfferButton, style: const TextStyle(color: LightColors.error, fontWeight: FontWeight.w700)),
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
        content: Text(ok ? t.offerCancelledMsg : t.failedToCancelOffer),
        backgroundColor: ok ? LightColors.success : LightColors.error,
      ),
    );
    if (ok) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
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
                  _statusLabel(t),
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
            '${offer.requiredTruckType} · '
            '${offer.orderType == 'internal' ? t.addShipmentDomesticShort : (offer.orderType == 'external' ? t.addShipmentCrossBorderShort : offer.orderType)} · '
            '${t.eligibleDriversCount(offer.eligibleDriversCount)}',
            style: const TextStyle(color: LightColors.textSecondary, fontSize: 11),
          ),
          if (offer.priceToClient.isNotEmpty && offer.priceToClient != '0') ...[
            const SizedBox(height: 4),
            Text(
              t.priceToClientLabel(offer.priceToClient) +
                  (offer.pricingMode == 'manual' ? t.manualSuffix : ''),
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
                  label: Text(t.raisePriceButton, style: const TextStyle(color: LightColors.goldMuted, fontSize: 12)),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _cancel(context),
                  icon: const Icon(Icons.close, color: LightColors.error, size: 16),
                  label: Text(t.commonCancel, style: const TextStyle(color: LightColors.error, fontSize: 12)),
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
                  label: Text(t.commonCancel, style: const TextStyle(color: LightColors.error, fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
