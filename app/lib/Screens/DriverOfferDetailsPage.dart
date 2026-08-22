import 'package:flutter/material.dart';

import '../API/ShipmentOfferService.dart';
import '../API/config.dart';
import '../l10n/app_localizations.dart';
import '../models/ShipmentOffer.dart';
import '../utils/offer_accept_flow.dart';
import '../utils/saved_offers.dart';

/// Driver redesign Phase 2 (2026-08-17 mockup): "Shipment Details" for a
/// single available offer, reached via the "Details" button on Available
/// Shipments. Built from ShipmentOffer's real fields only — the mockup
/// shows a Schedule section (Loading/Delivery Date) and a "No. of Pallets"
/// field that don't exist anywhere in this data model (not even on the
/// Shipment it becomes once accepted), so they're left out rather than
/// faked, same call made for the company-side Create Shipment wizard.
class DriverOfferDetailsPage extends StatefulWidget {
  final ShipmentOffer offer;
  const DriverOfferDetailsPage({super.key, required this.offer});

  @override
  State<DriverOfferDetailsPage> createState() => _DriverOfferDetailsPageState();
}

class _DriverOfferDetailsPageState extends State<DriverOfferDetailsPage> {
  bool _saved = false;
  bool _accepting = false;
  bool _declining = false;

  @override
  void initState() {
    super.initState();
    SavedOffers.isSaved(widget.offer.id).then((v) {
      if (mounted) setState(() => _saved = v);
    });
  }

  Future<void> _toggleSave() async {
    final all = await SavedOffers.toggle(widget.offer.id);
    if (mounted) setState(() => _saved = all.contains(widget.offer.id));
  }

  Future<void> _accept() async {
    setState(() => _accepting = true);
    final ok = await acceptOfferFlow(context, widget.offer);
    if (!mounted) return;
    setState(() => _accepting = false);
    if (ok) Navigator.pop(context, true);
  }

  Future<void> _decline() async {
    final t = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LightColors.surface,
        title: Text(t.declineOfferTitle, style: const TextStyle(color: LightColors.cream)),
        content: Text(t.declineOfferBody, style: const TextStyle(color: LightColors.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.commonCancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.commonDecline, style: const TextStyle(color: LightColors.error))),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _declining = true);
    final result = await ShipmentOfferService.declineOffer(widget.offer.id);
    if (!mounted) return;
    setState(() => _declining = false);

    if (result['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? t.failedToDeclineOffer), backgroundColor: LightColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final offer = widget.offer;
    final requirements = [
      if (offer.needsPermit) t.requirementSpecialPermit,
      if (offer.isHazardous) t.requirementHazardousCargo,
      if (offer.isFragile) t.requirementFragileCargo,
    ];

    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: LightColors.cream),
        title: Text(t.shipmentDetailsTitle, style: const TextStyle(color: LightColors.cream)),
        actions: [
          IconButton(
            icon: Icon(_saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: LightColors.gold),
            onPressed: _toggleSave,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: LightColors.success.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Text(t.statusOffered, style: const TextStyle(color: LightColors.success, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 10),
          Text('${offer.origin}  →  ${offer.destination}',
              style: const TextStyle(color: LightColors.cream, fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(offer.companyName.isEmpty ? '' : t.postedByCompany(offer.companyName),
              style: const TextStyle(color: LightColors.muted, fontSize: 12.5)),
          const SizedBox(height: 20),

          _SectionCard(
            title: t.sectionLoadInformation,
            rows: [
              (t.fieldOrderType, offer.orderType == 'internal' ? t.addShipmentDomesticShort : t.addShipmentCrossBorderShort),
              if (offer.hasZoneRoute) (t.fieldPickupZone, [offer.originCity, offer.originCountry].where((s) => s != null && s.isNotEmpty).join(', ')),
              if (offer.hasZoneRoute) (t.fieldDropoffZone, [offer.destinationCity, offer.destinationCountry].where((s) => s != null && s.isNotEmpty).join(', ')),
              (t.addShipmentReviewTruckType, offer.requiredTruckType.isEmpty ? '—' : offer.requiredTruckType),
              (t.addShipmentReviewWeight, offer.weight.isEmpty ? '—' : '${offer.weight} kg'),
              if (requirements.isNotEmpty) (t.fieldRequirements, requirements.join(', ')),
            ],
          ),

          if (offer.description.isNotEmpty) ...[
            const SizedBox(height: 14),
            _SectionCard(title: t.sectionCargoDescription, rows: [('', offer.description)], plainText: true),
          ],

          const SizedBox(height: 14),
          _SectionCard(
            title: t.sectionPayment,
            rows: [
              (t.fieldPriceToYou, offer.priceToDriver.isEmpty || offer.priceToDriver == '0' ? t.toBeConfirmed : '${offer.priceToDriver} AED'),
            ],
            highlightValue: true,
          ),

          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _toggleSave,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: LightColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(_saved ? t.commonSaved : t.commonSave, style: const TextStyle(color: LightColors.cream, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _declining ? null : _decline,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: LightColors.error),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _declining
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: LightColors.error))
                      : Text(t.commonDecline, style: const TextStyle(color: LightColors.error, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _accepting ? null : _accept,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: LightColors.gold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _accepting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: LightColors.deepNavy))
                  : Text(t.acceptShipmentButton, style: const TextStyle(color: LightColors.deepNavy, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;
  final bool plainText;
  final bool highlightValue;

  const _SectionCard({required this.title, required this.rows, this.plainText = false, this.highlightValue = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: LightColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: LightColors.border, width: 0.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: LightColors.cream, fontSize: 13.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (plainText)
            Text(rows.first.$2, style: const TextStyle(color: LightColors.muted, fontSize: 13))
          else
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 110, child: Text(row.$1, style: const TextStyle(color: LightColors.muted, fontSize: 12.5))),
                    Expanded(
                      child: Text(row.$2,
                          style: TextStyle(
                            color: highlightValue ? LightColors.gold : LightColors.cream,
                            fontSize: highlightValue ? 16 : 12.5,
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
