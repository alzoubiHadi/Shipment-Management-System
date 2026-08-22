import 'package:flutter/material.dart';
import '../API/DriverService.dart';
import '../API/config.dart'; // Ensure AppColors is imported from here
import '../models/Driver.dart';
import '../models/DriverDocument.dart';
import '../models/Truck.dart';

/// Read-only "View Information" screen (Drivers list Phase 2, 2026-08-22).
/// Shows every currently available piece of driver + truck data on one
/// page — no approve/reject/rate/suspend/reactivate actions here. Those
/// decisions live in RequestReviewScreen (approve/reject/request changes)
/// and directly on the Drivers list cards (suspend/reactivate/delete).
/// Reuses the existing Driver/Truck models and DriverService calls only;
/// no new fields or fabricated stats are introduced.
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
  late Future<List<DriverDocument>> _documentsFuture;
  late Future<Truck?> _truckFuture;
  late Future<List<String>> _destinationsFuture;

  @override
  void initState() {
    super.initState();
    _documentsFuture = DriverService.fetchDocumentsFor(driver.user_id);
    _truckFuture = DriverService.fetchTruckForDriver(driver.id);
    _destinationsFuture = DriverService.fetchDestinationsFor(driver.user_id);
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
        'changes_required' => LightColors.goldMuted,
        _ => LightColors.info,
      };

  String get _approvalLabel => switch (driver.approvalStatus) {
        'approved' => 'Approved',
        'rejected' => 'Rejected',
        'changes_required' => 'Changes requested',
        _ => 'Pending review',
      };

  Color get _complianceColor => switch (driver.complianceStatus) {
        'active' => LightColors.success,
        'warning' => LightColors.gold,
        _ => LightColors.error,
      };

  String _fmtDate(DateTime? d) =>
      d == null ? '' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: LightColors.textPrimary),
        title: const Text(
          'Driver Information',
          style: TextStyle(
            color: LightColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: LightColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: LightColors.border),
          ),
          child: Column(
            children: [
              // Avatar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: LightColors.surfaceHigh,
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
                  color: LightColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                driver.email ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  color: LightColors.textSecondary,
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
                      style: const TextStyle(color: LightColors.textPrimary, fontSize: 13)),
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
                    color: LightColors.errorBg,
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

              // Uploaded driver documents.
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: const Text(
                  'Documents',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: LightColors.textPrimary,
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
                      child: Text('No documents uploaded yet', style: TextStyle(color: LightColors.textSecondary, fontSize: 12)),
                    );
                  }

                  return Column(
                    children: current.values.map((doc) {
                      final expired = doc.isExpired;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: LightColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: LightColors.border, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.description_outlined,
                                color: expired ? LightColors.error : LightColors.goldMuted, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(driverDocumentTypeLabel(doc.type),
                                      style: const TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                                  if (doc.expiryDate != null)
                                    Text(
                                      'exp. ${_fmtDate(doc.expiryDate)}',
                                      style: TextStyle(
                                        color: expired ? LightColors.error : LightColors.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => _openFile(doc.id),
                              child: const Text('View', style: TextStyle(color: LightColors.goldMuted, fontSize: 12, fontWeight: FontWeight.w600)),
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
              // what's shown here always matches what the driver actually
              // submitted.
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: const Text('Driver Information',
                    style: TextStyle(fontWeight: FontWeight.w600, color: LightColors.textPrimary, fontSize: 15)),
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
                future: _destinationsFuture,
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

              const SizedBox(height: 12),
              const Divider(color: LightColors.border, thickness: 1),
              const SizedBox(height: 16),

              // Truck Information + Truck Documents — same data the admin
              // review screen's Truck Info tab already fetches.
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: const Text('Truck Information',
                    style: TextStyle(fontWeight: FontWeight.w600, color: LightColors.textPrimary, fontSize: 15)),
              ),
              const SizedBox(height: 8),
              FutureBuilder<Truck?>(
                future: _truckFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: CircularProgressIndicator(color: LightColors.gold),
                    );
                  }

                  final truck = snapshot.data;
                  if (truck == null) {
                    return Column(
                      children: [
                        _buildItem("Truck Number", driver.truck_number),
                        _buildItem("Truck Type", driver.truck_type),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      _buildItem("Plate Number", truck.truckNumber),
                      _buildItem("Truck Type", truck.truckType),
                      _buildItem("Refrigerated", truck.hasRefrigeration ? 'Yes' : 'No'),
                      _buildItem("Max Load", truck.maxLoad?.toString()),
                      _buildItem("Permit Type", truck.permitType),
                      _buildItem("Permit Expiry", _fmtDate(truck.permitExpiry)),
                      const SizedBox(height: 8),
                      _buildItem("Vehicle License Expiry", _fmtDate(truck.licenseExpiry)),
                      _buildItem("Insurance Expiry", _fmtDate(truck.insuranceExpiry)),
                      _buildItem("Technical Inspection Expiry", _fmtDate(truck.technicalInspectionExpiry)),
                    ],
                  );
                },
              ),
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
                color: LightColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              (value == null || value.isEmpty) ? "-" : value,
              style: const TextStyle(
                color: LightColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
