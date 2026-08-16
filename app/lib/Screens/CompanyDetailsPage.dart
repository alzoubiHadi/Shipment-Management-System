import 'package:flutter/material.dart';
import '../API/CompanyService.dart';
import '../API/config.dart';
import '../models/Company.dart';

class CompanyDetailsPage extends StatefulWidget {
  final Company company;

  const CompanyDetailsPage({
    super.key,
    required this.company,
  });

  @override
  State<CompanyDetailsPage> createState() => _CompanyDetailsPageState();
}

class _CompanyDetailsPageState extends State<CompanyDetailsPage> {
  late Company company = widget.company;
  bool _busy = false;

  Color get _statusColor =>
      company.accountStatus == 'suspended' ? AppColors.error : AppColors.success;

  /// UC-27: Super Admin temporarily suspends a company account.
  Future<void> _suspend() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Suspend Company', style: TextStyle(color: AppColors.cream)),
        content: TextField(
          controller: reasonCtrl,
          style: const TextStyle(color: AppColors.cream),
          decoration: const InputDecoration(
            hintText: 'Reason (required)',
            hintStyle: TextStyle(color: AppColors.muted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: reasonCtrl.text.trim().isEmpty
                ? null
                : () => Navigator.pop(ctx, true),
            child: const Text('Suspend', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true || reasonCtrl.text.trim().isEmpty) return;

    setState(() => _busy = true);
    final result = await CompanyService.suspendCompany(
      companyId: company.id,
      reason: reasonCtrl.text.trim(),
    );
    setState(() => _busy = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']?.toString() ?? '')),
    );
    if (result['success'] == true) {
      setState(() {
        company = Company(
          id: company.id,
          name: company.name,
          email: company.email,
          phone: company.phone,
          user_id: company.user_id,
          password: company.password,
          balance: company.balance,
          creditLimit: company.creditLimit,
          accountStatus: 'suspended',
          suspensionReason: reasonCtrl.text.trim(),
        );
      });
    }
  }

  Future<void> _activate() async {
    setState(() => _busy = true);
    final result = await CompanyService.activateCompany(company.id);
    setState(() => _busy = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']?.toString() ?? '')),
    );
    if (result['success'] == true) {
      setState(() {
        company = Company(
          id: company.id,
          name: company.name,
          email: company.email,
          phone: company.phone,
          user_id: company.user_id,
          password: company.password,
          balance: company.balance,
          creditLimit: company.creditLimit,
          accountStatus: 'active',
          suspensionReason: null,
        );
      });
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
          'Company Details',
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
            border: Border.all(
              color: AppColors.border,
            ),
          ),
          child: Column(
            children: [
              // Company Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.gold,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.business,
                  size: 48,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(height: 20),

              // Company Name
              Text(
                company.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cream,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                company.email,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.muted,
                ),
              ),

              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  company.accountStatus == 'suspended' ? 'Suspended' : 'Active',
                  style: TextStyle(color: _statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),

              const SizedBox(height: 24),
              const Divider(
                color: AppColors.border,
                thickness: 1,
              ),
              const SizedBox(height: 16),

              _buildItem("ID", company.id),
              _buildItem("Phone", company.phone),
              _buildItem("User ID", company.user_id),

              if (company.password.isNotEmpty)
                _buildItem("Password", "********"),

              if (company.accountStatus == 'suspended' &&
                  (company.suspensionReason ?? '').isNotEmpty)
                _buildItem("Suspension Reason", company.suspensionReason),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: company.accountStatus == 'suspended'
                    ? OutlinedButton.icon(
                        onPressed: _busy ? null : _activate,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.success),
                        ),
                        icon: const Icon(Icons.refresh, size: 18, color: AppColors.success),
                        label: const Text('Activate', style: TextStyle(color: AppColors.success)),
                      )
                    : OutlinedButton.icon(
                        onPressed: _busy ? null : _suspend,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error),
                        ),
                        icon: const Icon(Icons.block, size: 18, color: AppColors.error),
                        label: const Text('Suspend', style: TextStyle(color: AppColors.error)),
                      ),
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
