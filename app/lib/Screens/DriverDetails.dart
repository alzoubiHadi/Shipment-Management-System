import 'package:flutter/material.dart';
import '../API/DriverService.dart';
import '../API/config.dart'; // Ensure AppColors is imported from here
import '../models/Driver.dart';
import '../models/DriverDocument.dart';

class DriverDetailsPage extends StatefulWidget {
  final Driver driver;

  const DriverDetailsPage({
    super.key,
    required this.driver,
  });

  @override
  State<DriverDetailsPage> createState() => _DriverDetailsPageState();
}

class _DriverDetailsPageState extends State<DriverDetailsPage> {
  late Driver driver = widget.driver;
  bool _busy = false;
  late Future<List<DriverDocument>> _documentsFuture;

  @override
  void initState() {
    super.initState();
    _documentsFuture = DriverService.fetchDocumentsFor(driver.user_id);
  }

  /// 2026-08-27 (security review, item 7): documents moved to the private
  /// disk — fetched through the authenticated /driver-documents/{id}/file
  /// endpoint instead of a plain storage URL.
  Future<void> _openFile(String documentId) async {
    await viewSecureFile(context, '$baseUrl/driver-documents/$documentId/file');
  }

  Color get _approvalColor => switch (driver.approvalStatus) {
        'approved' => LightColors.success,
        'rejected' => LightColors.error,
        _ => LightColors.info,
      };

  String get _approvalLabel => switch (driver.approvalStatus) {
        'approved' => 'Approved',
        'rejected' => 'Rejected',
        _ => 'Pending review',
      };

  Future<void> _approve() async {
    setState(() => _busy = true);
    final result = await DriverService.approveDriver(driver.id);
    setState(() => _busy = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? '')),
      );
      if (result['success'] == true) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _reject() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LightColors.surface,
        title: const Text('Reject Driver', style: TextStyle(color: LightColors.cream)),
        content: TextField(
          controller: reasonCtrl,
          style: const TextStyle(color: LightColors.cream),
          decoration: const InputDecoration(
            hintText: 'Reason (optional)',
            hintStyle: TextStyle(color: LightColors.muted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: LightColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject', style: TextStyle(color: LightColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _busy = true);
      await DriverService.rejectDriver(driver.id, reason: reasonCtrl.text.trim());
      setState(() => _busy = false);
      if (mounted) Navigator.pop(context, true);
    }
  }

  Color get _complianceColor => switch (driver.complianceStatus) {
        'active' => LightColors.success,
        'warning' => LightColors.gold,
        _ => LightColors.error,
      };

  /// Super Admin (UC-25 special requirement): freeze a driver directly,
  /// skipping the report/escalation workflow.
  Future<void> _suspend() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LightColors.surface,
        title: const Text('Suspend Driver', style: TextStyle(color: LightColors.cream)),
        content: TextField(
          controller: reasonCtrl,
          style: const TextStyle(color: LightColors.cream),
          decoration: const InputDecoration(
            hintText: 'Reason (required)',
            hintStyle: TextStyle(color: LightColors.muted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: LightColors.muted)),
          ),
          TextButton(
            onPressed: reasonCtrl.text.trim().isEmpty
                ? null
                : () => Navigator.pop(ctx, true),
            child: const Text('Suspend', style: TextStyle(color: LightColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true || reasonCtrl.text.trim().isEmpty) return;

    setState(() => _busy = true);
    final result = await DriverService.suspendDriver(driver.id, reasonCtrl.text.trim());
    setState(() => _busy = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? '')),
      );
      if (result['success'] == true) Navigator.pop(context, true);
    }
  }

  Future<void> _reactivate() async {
    setState(() => _busy = true);
    final result = await DriverService.reactivateDriver(driver.id);
    setState(() => _busy = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? '')),
      );
      if (result['success'] == true) Navigator.pop(context, true);
    }
  }

  /// UC-24: Super Admin rates a driver directly, independent of any
  /// shipment.
  Future<void> _rate() async {
    int score = 0;
    final commentCtrl = TextEditingController();

    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: LightColors.surface,
          title: const Text('Rate driver', style: TextStyle(color: LightColors.cream)),
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
              TextField(
                controller: commentCtrl,
                maxLines: 2,
                style: const TextStyle(color: LightColors.cream),
                decoration: const InputDecoration(
                  hintText: 'Comment (optional)',
                  hintStyle: TextStyle(color: LightColors.muted),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: LightColors.muted)),
            ),
            TextButton(
              onPressed: score == 0 ? null : () => Navigator.pop(ctx, score),
              child: const Text('Submit', style: TextStyle(color: LightColors.gold)),
            ),
          ],
        ),
      ),
    );

    if (picked == null || picked == 0) return;

    setState(() => _busy = true);
    final result = await DriverService.rateDriver(
      driverId: driver.id,
      score: picked,
      comment: commentCtrl.text.trim(),
    );
    setState(() => _busy = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? ''),
          backgroundColor: result['success'] == true ? LightColors.success : LightColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: LightColors.cream),
        title: const Text(
          'Driver Details',
          style: TextStyle(
            color: LightColors.cream,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: LightColors.surfaceHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: LightColors.border),
          ),
          child: Column(
            children: [
              // Stylish Avatar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: LightColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: LightColors.gold, width: 2),
                ),
                child: const Icon(
                  Icons.person,
                  size: 48,
                  color: LightColors.gold,
                ),
              ),
              const SizedBox(height: 20),

              // Name & Email Header
              Text(
                driver.name ?? 'Unknown',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: LightColors.cream,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                driver.email ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  color: LightColors.muted,
                ),
              ),

              const SizedBox(height: 16),

              // Approval status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _approvalColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _approvalColor.withOpacity(0.4)),
                ),
                child: Text(
                  _approvalLabel,
                  style: TextStyle(fontSize: 12, color: _approvalColor, fontWeight: FontWeight.w600),
                ),
              ),

              if (driver.approvalStatus == 'rejected' &&
                  (driver.rejectionReason ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Reason: ${driver.rejectionReason}',
                  style: const TextStyle(fontSize: 12, color: LightColors.error),
                ),
              ],

              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star, color: LightColors.gold, size: 16),
                  const SizedBox(width: 4),
                  Text(driver.rating.toStringAsFixed(2),
                      style: const TextStyle(color: LightColors.cream, fontSize: 13)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _complianceColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      driver.complianceStatus,
                      style: TextStyle(color: _complianceColor, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),

              if (driver.documentIssues.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: LightColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: driver.documentIssues
                        .map((i) => Text('• $i',
                            style: const TextStyle(fontSize: 12, color: LightColors.error)))
                        .toList(),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              const Divider(color: LightColors.border, thickness: 1),
              const SizedBox(height: 16),

              // Uploaded documents — the admin needs to actually open and
              // look at these to approve a join request responsibly, not
              // just see an expiry-date text field.
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Documents',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: LightColors.cream,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FutureBuilder<List<DriverDocument>>(
                future: _documentsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: CircularProgressIndicator(color: LightColors.gold),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Could not load documents', style: TextStyle(color: LightColors.error, fontSize: 12)),
                    );
                  }

                  final all = snapshot.data ?? [];
                  final current = <String, DriverDocument>{};
                  for (final d in all) {
                    if (d.isCurrent) current[d.type] = d;
                  }

                  if (current.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No documents uploaded yet', style: TextStyle(color: LightColors.muted, fontSize: 12)),
                    );
                  }

                  return Column(
                    children: current.values.map((doc) {
                      final expired = doc.isExpired;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: LightColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: LightColors.border, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.description_outlined,
                                color: expired ? LightColors.error : LightColors.gold, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(driverDocumentTypeLabel(doc.type),
                                      style: const TextStyle(color: LightColors.cream, fontSize: 13, fontWeight: FontWeight.w600)),
                                  if (doc.expiryDate != null)
                                    Text(
                                      'exp. ${doc.expiryDate!.year}-${doc.expiryDate!.month.toString().padLeft(2, '0')}-${doc.expiryDate!.day.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        color: expired ? LightColors.error : LightColors.muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => _openFile(doc.id),
                              child: const Text('View', style: TextStyle(color: LightColors.gold, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 12),
              const Divider(color: LightColors.border, thickness: 1),
              const SizedBox(height: 16),

              // Driver Information — same order and fields as the
              // registration form's Section 1 (DriverRegisterScreen), so
              // what the admin reviews here always matches what the driver
              // actually submitted. "Employment Type" used to show here
              // too, but registration hasn't collected that field since
              // the two-section rebuild — removed rather than showing a
              // value the driver never actually provided.
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Driver Information',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: LightColors.cream, fontSize: 15)),
              ),
              const SizedBox(height: 8),
              _buildItem("ID", driver.id?.toString()),
              _buildItem("Phone", driver.phone),
              _buildItem("Nationality", driver.nationality),
              _buildItem("Age", driver.age),
              _buildItem("Driver License", driver.driver_license),
              _buildItem("License Expiry", driver.license_expiry),
              _buildItem("Passport Expiry", driver.passportExpiry),
              _buildItem("Residency Expiry", driver.residencyExpiry),
              _buildItem("Blood Type", driver.bloodType),
              _buildItem("Health Conditions", driver.healthConditions),
              FutureBuilder<List<String>>(
                future: DriverService.fetchDestinationsFor(driver.user_id),
                builder: (context, snapshot) {
                  final list = snapshot.data;
                  return _buildItem(
                    "Work Destinations",
                    list == null ? null : (list.isEmpty ? null : list.join(', ')),
                  );
                },
              ),
              _buildItem("Work Status", driver.status),
              _buildItem("User ID", driver.user_id),

              // Hide password if empty or null
              if (driver.password != null && driver.password!.isNotEmpty)
                _buildItem("Password", "********"),

              const SizedBox(height: 12),
              const Divider(color: LightColors.border, thickness: 1),
              const SizedBox(height: 16),

              // Truck Information — Section 2 of registration.
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Truck Information',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: LightColors.cream, fontSize: 15)),
              ),
              const SizedBox(height: 8),
              _buildItem("Truck Number", driver.truck_number),
              _buildItem("Truck Type", driver.truck_type),

              if (driver.approvalStatus == 'pending') ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : _approve,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LightColors.success,
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Approve'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _reject,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: LightColors.error),
                        ),
                        icon: const Icon(Icons.cancel_outlined, size: 18, color: LightColors.error),
                        label: const Text('Reject', style: TextStyle(color: LightColors.error)),
                      ),
                    ),
                  ],
                ),
              ],

              if (driver.approvalStatus == 'approved') ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _rate,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: LightColors.gold),
                        ),
                        icon: const Icon(Icons.star_outline, size: 18, color: LightColors.gold),
                        label: const Text('Rate', style: TextStyle(color: LightColors.gold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: driver.complianceStatus == 'active' || driver.complianceStatus == 'warning'
                          ? OutlinedButton.icon(
                              onPressed: _busy ? null : _suspend,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: LightColors.error),
                              ),
                              icon: const Icon(Icons.block, size: 18, color: LightColors.error),
                              label: const Text('Suspend', style: TextStyle(color: LightColors.error)),
                            )
                          : OutlinedButton.icon(
                              onPressed: _busy ? null : _reactivate,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: LightColors.success),
                              ),
                              icon: const Icon(Icons.refresh, size: 18, color: LightColors.success),
                              label: const Text('Reactivate', style: TextStyle(color: LightColors.success)),
                            ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: LightColors.muted,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              (value == null || value.isEmpty) ? "-" : value,
              style: const TextStyle(
                color: LightColors.cream,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}