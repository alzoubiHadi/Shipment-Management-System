import 'package:flutter/material.dart';
import '../API/ComplianceReportService.dart';
import '../API/ShipmentServices.dart';
import '../API/config.dart';
import '../models/ComplianceReport.dart';
import '../models/Shipment.dart';
import 'ShipmentTrackingPage.dart';

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

  Future<void> _confirmDelivery() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Confirm receipt',
            style: TextStyle(color: AppColors.cream)),
        content: const Text(
          "Confirming pays the driver immediately for this shipment. Make sure you've reviewed the proof of delivery first.",
          style: TextStyle(color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm receipt',
                style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isBusy = true);
    final result = await _service.confirmDelivery(shipmentId: _shipment.id);
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (result['success'] == true) {
      setState(() => _shipment = Shipment.fromJson(result['shipment']));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delivery confirmed — driver has been paid'),
          backgroundColor: AppColors.success,
        ),
      );
      if (mounted) await _rateDriver();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Failed')),
      );
    }
  }

  /// UC-23: prompt the company to rate the driver right after confirming.
  /// Optional — closing the dialog without picking a star simply skips it.
  Future<void> _rateDriver() async {
    int score = 0;
    final commentController = TextEditingController();

    final picked = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Rate this driver',
              style: TextStyle(color: AppColors.cream)),
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
                      color: AppColors.gold,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: commentController,
                maxLines: 2,
                style: const TextStyle(color: AppColors.cream),
                decoration: const InputDecoration(
                  hintText: 'Comment (optional)',
                  hintStyle: TextStyle(color: AppColors.muted),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Skip', style: TextStyle(color: AppColors.muted)),
            ),
            TextButton(
              onPressed: score == 0 ? null : () => Navigator.pop(context, score),
              child: const Text('Submit', style: TextStyle(color: AppColors.gold)),
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
        backgroundColor: result['success'] == true ? AppColors.success : AppColors.error,
      ),
    );
  }

  /// UC-25: report a compliance/safety issue against the assigned driver.
  Future<void> _reportDriver() async {
    if (_shipment.driverId == null) return;

    String category = ComplianceReport.categories.first;
    final descriptionController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Report driver', style: TextStyle(color: AppColors.cream)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButton<String>(
                value: category,
                dropdownColor: AppColors.surface,
                isExpanded: true,
                style: const TextStyle(color: AppColors.cream),
                items: ComplianceReport.categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setDialogState(() => category = v ?? category),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                style: const TextStyle(color: AppColors.cream),
                decoration: const InputDecoration(
                  hintText: 'Describe what happened',
                  hintStyle: TextStyle(color: AppColors.muted),
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
              onPressed: descriptionController.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Submit', style: TextStyle(color: AppColors.error)),
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
        backgroundColor: result['success'] == true ? AppColors.info : AppColors.error,
      ),
    );
  }

  Future<void> _reportProblem() async {
    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Report a problem',
            style: TextStyle(color: AppColors.cream)),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          style: const TextStyle(color: AppColors.cream),
          decoration: const InputDecoration(
            hintText: 'What went wrong? (missing items, damage, ...)',
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
            child: const Text('Submit', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty) return;

    setState(() => _isBusy = true);
    final result = await _service.disputeDelivery(
      shipmentId: _shipment.id,
      reason: reason,
    );
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (result['success'] == true) {
      setState(() => _shipment = Shipment.fromJson(result['shipment']));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reported — an admin will review this delivery'),
          backgroundColor: AppColors.info,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _shipment.statusColor;
    final awaitingConfirmation = _shipment.isAwaitingCompanyConfirmation;

    return Scaffold(
      backgroundColor: AppColors.bg,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.bg,
        title: const Text("Shipment Details"),
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (awaitingConfirmation) ...[
              SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isBusy ? null : _confirmDelivery,
                  icon: const Icon(Icons.check_circle_outline, color: AppColors.bg),
                  label: const Text('Confirm receipt'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.bg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 44,
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isBusy ? null : _reportProblem,
                  icon: const Icon(Icons.report_gmailerrorred_outlined,
                      color: AppColors.error),
                  label: const Text('Report a problem',
                      style: TextStyle(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              height: 48,
              width: double.infinity,
              child: OutlinedButton.icon(
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
            if (_shipment.driverId != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _isBusy ? null : _reportDriver,
                  icon: const Icon(Icons.flag_outlined, color: AppColors.muted, size: 16),
                  label: const Text('Report driver',
                      style: TextStyle(color: AppColors.muted, fontSize: 12)),
                ),
              ),
            ],
          ],
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
                    _shipment.trackingNumber,
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
                      statusLabel(_shipment.status),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  if (awaitingConfirmation) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        'Awaiting your confirmation',
                        style: TextStyle(
                            color: AppColors.gold, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ] else if (_shipment.isDeliveryDisputed) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        'Under admin review',
                        style: TextStyle(
                            color: AppColors.error, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            /// ROUTE
            _section(
              child: Column(
                children: [
                  _row("Origin", _shipment.origin),
                  const Divider(),
                  _row("Destination", _shipment.destination),
                ],
              ),
            ),

            const SizedBox(height: 16),

            /// BASIC INFO
            _section(
              child: Column(
                children: [
                  _row("Shipment ID", _shipment.id.toString()),
                  _row("Weight", _shipment.weight),
                  _row("Description", _shipment.description),
                ],
              ),
            ),

            const SizedBox(height: 16),

            /// TIMELINE
            _section(
              child: Column(
                children: [
                  _row("Created", _shipment.created_at),
                  _row("Pickup Time", _shipment.pickup_time),
                  _row("Delivered At", _shipment.delivered_at),
                ],
              ),
            ),

            if (_shipment.isDeliveryDisputed &&
                _shipment.disputeReason.isNotEmpty) ...[
              const SizedBox(height: 16),
              _section(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your reported problem',
                        style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(_shipment.disputeReason,
                        style: const TextStyle(color: AppColors.cream)),
                  ],
                ),
              ),
            ],
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
