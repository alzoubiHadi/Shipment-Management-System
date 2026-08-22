import 'package:flutter/material.dart';
import '../API/ComplianceReportService.dart';
import '../API/ShipmentServices.dart';
import '../API/config.dart';
import '../l10n/app_localizations.dart';
import '../models/ComplianceReport.dart';
import '../models/Shipment.dart';
import 'ProofOfDeliveryPage.dart';
import 'ShipmentTrackingPage.dart';
import 'register_shared.dart';

/// Company redesign Phase 4 (2026-08-17 mockup): light-themed shipment
/// details. "Confirm receipt" now opens the dedicated ProofOfDeliveryPage
/// (signature + recipient + Confirm/Report actions) instead of a plain
/// AlertDialog. "View Tracking Timeline" still pushes the shared
/// ShipmentTrackingPage — that screen stays dark for now (shared with the
/// driver's in-progress UI, out of scope for this pass).
class ShipmentDetailsPageCompany extends StatefulWidget {
  final Shipment shipment;

  const ShipmentDetailsPageCompany({
    super.key,
    required this.shipment,
  });

  @override
  State<ShipmentDetailsPageCompany> createState() =>
      _ShipmentDetailsPageCompanyState();
}

class _ShipmentDetailsPageCompanyState
    extends State<ShipmentDetailsPageCompany> {
  final _service = ShipmentService();
  late Shipment _shipment;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _shipment = widget.shipment;
  }

  Future<void> _openProofOfDelivery() async {
    final updated = await Navigator.push<Shipment>(
      context,
      MaterialPageRoute(builder: (_) => ProofOfDeliveryPage(shipment: _shipment)),
    );
    if (updated == null) return;

    final justConfirmed = updated.isDeliveryConfirmed && !_shipment.isDeliveryConfirmed;
    setState(() => _shipment = updated);
    if (justConfirmed && mounted) await _rateDriver();
  }

  /// UC-23: prompt the company to rate the driver right after confirming.
  /// Optional — closing the dialog without picking a star simply skips it.
  Future<void> _rateDriver() async {
    final t = AppLocalizations.of(context)!;
    int score = 0;
    final commentController = TextEditingController();

    final picked = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: LightColors.surface,
          title: Text(t.rateDriverTitle, style: const TextStyle(color: LightColors.textPrimary, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final starIndex = i + 1;
                  return IconButton(
                    onPressed: () => setDialogState(() => score = starIndex),
                    icon: Icon(
                      starIndex <= score ? Icons.star : Icons.star_border,
                      color: LightColors.gold,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: commentController,
                maxLines: 2,
                style: const TextStyle(color: LightColors.textPrimary),
                decoration: InputDecoration(
                  hintText: t.commentOptionalHint,
                  hintStyle: const TextStyle(color: LightColors.textSecondary),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t.commonSkip, style: const TextStyle(color: LightColors.textSecondary)),
            ),
            TextButton(
              onPressed: score == 0 ? null : () => Navigator.pop(context, score),
              child: Text(t.commonSubmit, style: const TextStyle(color: LightColors.goldMuted, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (picked == null || picked == 0) return;

    final result = await _service.rateDriver(
      shipmentId: _shipment.id,
      score: picked,
      comment: commentController.text.trim(),
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? ''),
        backgroundColor: result['success'] == true ? LightColors.success : LightColors.error,
      ),
    );
  }

  /// UC-25: report a compliance/safety issue against the assigned driver.
  Future<void> _reportDriver() async {
    if (_shipment.driverId == null) return;
    final t = AppLocalizations.of(context)!;

    String category = ComplianceReport.categories.first;
    final descriptionController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: LightColors.surface,
          title: Text(t.reportDriverTitle, style: const TextStyle(color: LightColors.textPrimary, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButton<String>(
                value: category,
                dropdownColor: LightColors.surface,
                isExpanded: true,
                style: const TextStyle(color: LightColors.textPrimary),
                items: ComplianceReport.categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setDialogState(() => category = v ?? category),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                style: const TextStyle(color: LightColors.textPrimary),
                decoration: InputDecoration(
                  hintText: t.describeWhatHappenedHint,
                  hintStyle: const TextStyle(color: LightColors.textSecondary),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t.commonCancel, style: const TextStyle(color: LightColors.textSecondary)),
            ),
            TextButton(
              onPressed: descriptionController.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: Text(t.commonSubmit, style: const TextStyle(color: LightColors.error, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || descriptionController.text.trim().isEmpty) return;

    setState(() => _isBusy = true);
    final result = await ComplianceReportService().fileReport(
      driverId: _shipment.driverId.toString(),
      category: category,
      description: descriptionController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isBusy = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? ''),
        backgroundColor: result['success'] == true ? LightColors.navy : LightColors.error,
      ),
    );
  }

  Color get _statusColor => switch (_shipment.status) {
        0 => LightColors.pending,
        1 => LightColors.navy,
        2 => LightColors.goldMuted,
        3 => LightColors.success,
        4 => LightColors.error,
        5 => LightColors.error,
        _ => LightColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final awaitingConfirmation = _shipment.isAwaitingCompanyConfirmation;

    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: LightColors.bg,
        iconTheme: const IconThemeData(color: LightColors.textPrimary),
        title: Text(t.shipmentDetailsTitle,
            style: const TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(color: LightColors.surface, border: Border(top: BorderSide(color: LightColors.border))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (awaitingConfirmation) ...[
              LightPrimaryButton(
                label: t.reviewProofOfDeliveryButton,
                icon: Icons.fact_check_outlined,
                color: LightColors.gold,
                textColor: LightColors.textPrimary,
                onPressed: _openProofOfDelivery,
              ),
              const SizedBox(height: 10),
            ],
            LightOutlineButton(
              label: t.viewTrackingTimelineButton,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShipmentTrackingPage(
                      shipment: _shipment,
                      readOnly: true,
                    ),
                  ),
                );
              },
            ),
            if (_shipment.driverId != null) ...[
              const SizedBox(height: 6),
              SizedBox(
                height: 40,
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _isBusy ? null : _reportDriver,
                  icon: const Icon(Icons.flag_outlined, color: LightColors.textSecondary, size: 16),
                  label: Text(t.reportDriverButton, style: const TextStyle(color: LightColors.textSecondary, fontSize: 12)),
                ),
              ),
            ],
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: LightColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LightColors.border)),
              child: Column(
                children: [
                  Text(
                    _shipment.trackingNumber.isEmpty ? 'SH-${_shipment.id}' : _shipment.trackingNumber,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: LightColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(color: _statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(30)),
                    child: Text(statusLabel(_shipment.status), style: TextStyle(color: _statusColor, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ),
                  if (awaitingConfirmation) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(color: LightColors.gold.withOpacity(0.14), borderRadius: BorderRadius.circular(30)),
                      child: Text(t.awaitingYourConfirmation, style: const TextStyle(color: LightColors.goldMuted, fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ] else if (_shipment.isDeliveryDisputed) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(color: LightColors.errorBg, borderRadius: BorderRadius.circular(30)),
                      child: Text(t.underAdminReview, style: const TextStyle(color: LightColors.error, fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            _section(title: t.sectionRoute, rows: [
              (t.addShipmentReviewOrigin, _shipment.origin),
              (t.addShipmentReviewDestination, _shipment.destination),
            ]),
            const SizedBox(height: 14),
            _section(title: t.sectionShipmentInfo, rows: [
              (t.fieldShipmentId, _shipment.id.toString()),
              (t.addShipmentReviewWeight, _shipment.weight.isEmpty ? '—' : _shipment.weight),
              (t.addShipmentReviewDescription, _shipment.description.isEmpty ? '—' : _shipment.description),
            ]),
            const SizedBox(height: 14),
            _section(title: t.sectionTimeline, rows: [
              (t.fieldCreated, _shipment.created_at.isEmpty ? '—' : _shipment.created_at),
              (t.fieldPickupTime, _shipment.pickup_time.isEmpty ? '—' : _shipment.pickup_time),
              (t.fieldDeliveredAt, _shipment.delivered_at.isEmpty ? '—' : _shipment.delivered_at),
            ]),
            if (_shipment.isDeliveryDisputed && _shipment.disputeReason.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: LightColors.errorBg, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.yourReportedProblem, style: const TextStyle(color: LightColors.error, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(_shipment.disputeReason, style: const TextStyle(color: LightColors.textPrimary)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section({required String title, required List<(String, String)> rows}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: LightColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LightColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: LightColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text(row.$1, style: const TextStyle(color: LightColors.textSecondary, fontSize: 12.5))),
                  Expanded(
                    flex: 3,
                    child: Text(row.$2, textAlign: TextAlign.end, style: const TextStyle(color: LightColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
