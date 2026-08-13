import 'package:flutter/material.dart';
import '../API/DriverService.dart';
import '../API/config.dart'; // Ensure AppColors is imported from here
import '../models/Driver.dart';

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

  Color get _approvalColor => switch (driver.approvalStatus) {
        'approved' => AppColors.success,
        'rejected' => AppColors.error,
        _ => AppColors.info,
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
        backgroundColor: AppColors.surface,
        title: const Text('Reject Driver', style: TextStyle(color: AppColors.cream)),
        content: TextField(
          controller: reasonCtrl,
          style: const TextStyle(color: AppColors.cream),
          decoration: const InputDecoration(
            hintText: 'Reason (optional)',
            hintStyle: TextStyle(color: AppColors.muted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject', style: TextStyle(color: AppColors.error)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.cream),
        title: const Text(
          'Driver Details',
          style: TextStyle(
            color: AppColors.cream,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              // Stylish Avatar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold, width: 2),
                ),
                child: const Icon(
                  Icons.person,
                  size: 48,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(height: 20),

              // Name & Email Header
              Text(
                driver.name ?? 'Unknown',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cream,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                driver.email ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.muted,
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
                  style: const TextStyle(fontSize: 12, color: AppColors.error),
                ),
              ],

              if (driver.documentIssues.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: driver.documentIssues
                        .map((i) => Text('• $i',
                            style: const TextStyle(fontSize: 12, color: AppColors.error)))
                        .toList(),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              const Divider(color: AppColors.border, thickness: 1),
              const SizedBox(height: 16),

              // Details List
              _buildItem("ID", driver.id?.toString()),
              _buildItem("Phone", driver.phone),
              _buildItem("Truck Number", driver.truck_number),
              _buildItem("Truck Type", driver.truck_type),
              _buildItem("Nationality", driver.nationality),
              _buildItem("Age", driver.age),
              _buildItem("Driver License", driver.driver_license),
              _buildItem("License Expiry", driver.license_expiry),
              _buildItem("Employment Type", driver.employmentType),
              _buildItem("Work Status", driver.status),
              _buildItem("Residency Expiry", driver.residencyExpiry),
              _buildItem("Passport Expiry", driver.passportExpiry),
              _buildItem("Blood Type", driver.bloodType),
              _buildItem("User ID", driver.user_id),

              // Hide password if empty or null
              if (driver.password != null && driver.password!.isNotEmpty)
                _buildItem("Password", "********"),

              if (driver.approvalStatus == 'pending') ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : _approve,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
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
                          side: const BorderSide(color: AppColors.error),
                        ),
                        icon: const Icon(Icons.cancel_outlined, size: 18, color: AppColors.error),
                        label: const Text('Reject', style: TextStyle(color: AppColors.error)),
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
                color: AppColors.muted,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              (value == null || value.isEmpty) ? "-" : value,
              style: const TextStyle(
                color: AppColors.cream,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}