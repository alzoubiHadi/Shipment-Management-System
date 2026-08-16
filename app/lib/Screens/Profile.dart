import 'package:flutter/material.dart';
import '../API/ReportService.dart';
import '../API/TruckService.dart';
import '../API/config.dart';
import '../models/Appuser.dart';
import '../models/Truck.dart';
import '../utils/logout_helper.dart';
import 'AddTruckPage.dart';
import 'CompanyBalancePage.dart';
import 'DriverBalancePage.dart';
import 'DriverComplianceReportsPage.dart';

class Profile extends StatefulWidget {
  final AppUser user;

  const Profile({required this.user, super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final _truckService = TruckService();
  final _reportService = ReportService();
  Future<List<Truck>>? _trucksFuture;
  Future<Map<String, dynamic>>? _reportFuture;

  bool get _isDriver => (widget.user.role ?? '').toLowerCase() == 'driver';

  @override
  void initState() {
    super.initState();
    if (_isDriver) {
      _trucksFuture = _truckService.fetchMyTrucks();
      _reportFuture = _reportService.fetchMyDriverReport();
    }
  }

  void _refreshTrucks() {
    setState(() {
      _trucksFuture = _truckService.fetchMyTrucks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final role = (widget.user.role ?? '').toLowerCase();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(color: AppColors.cream),
        ),
        iconTheme: const IconThemeData(color: AppColors.cream),
        actions: [logoutAction(context)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfileHeader(user: widget.user, role: role),
            const SizedBox(height: 24),

            _SectionTitle('Contact Information'),
            const SizedBox(height: 12),
            _InfoTile(
              icon: Icons.email_outlined,
              label: 'Email',
              value: widget.user.email ?? '—',
            ),

            if (role == 'driver' || role == 'company') ...[
              const SizedBox(height: 24),
              _SectionTitle('Finance'),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => role == 'driver'
                        ? const DriverBalancePage()
                        : const CompanyBalancePage(),
                  ),
                ),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.account_balance_wallet_outlined,
                            color: AppColors.gold, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'My Balance',
                          style: TextStyle(
                              color: AppColors.cream,
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.muted),
                    ],
                  ),
                ),
              ),
            ],

            if (_isDriver) ...[
              const SizedBox(height: 24),
              _SectionTitle('My Performance'),
              const SizedBox(height: 12),
              FutureBuilder<Map<String, dynamic>>(
                future: _reportFuture,
                builder: (context, snapshot) {
                  final completed = snapshot.data?['completed_count'] ?? 0;
                  final cancelled = snapshot.data?['cancelled_count'] ?? 0;

                  return Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Completed',
                          value: completed.toString(),
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Cancelled',
                          value: cancelled.toString(),
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              _SectionTitle('Rating & Compliance'),
              const SizedBox(height: 12),
              FutureBuilder<Map<String, dynamic>>(
                future: _reportFuture,
                builder: (context, snapshot) {
                  final rating =
                      double.tryParse(snapshot.data?['rating']?.toString() ?? '') ?? 4.5;
                  final compliance =
                      snapshot.data?['compliance_status']?.toString() ?? 'active';
                  final complianceColor = compliance == 'active'
                      ? AppColors.success
                      : compliance == 'warning'
                          ? AppColors.gold
                          : AppColors.error;

                  return InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DriverComplianceReportsPage(),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: AppColors.gold, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            rating.toStringAsFixed(2),
                            style: const TextStyle(
                                color: AppColors.cream,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: complianceColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              compliance,
                              style: TextStyle(
                                  color: complianceColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right, color: AppColors.muted),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],

            if (_isDriver) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SectionTitle('My Trucks'),
                  TextButton.icon(
                    onPressed: () async {
                      final added = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AddTruckPage()),
                      );
                      if (added == true) _refreshTrucks();
                    },
                    icon: const Icon(Icons.add, size: 16, color: AppColors.gold),
                    label: const Text(
                      'Add Truck',
                      style: TextStyle(color: AppColors.gold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              FutureBuilder<List<Truck>>(
                future: _trucksFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.gold,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Text(
                      'Could not load trucks',
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 13),
                    );
                  }

                  final trucks = snapshot.data ?? [];

                  if (trucks.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 18, horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 0.5),
                      ),
                      child: const Text(
                        'No trucks added yet. Add your truck so you can be matched with shipments.',
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    );
                  }

                  return Column(
                    children: trucks
                        .map((t) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _InfoTile(
                                icon: t.hasRefrigeration
                                    ? Icons.ac_unit
                                    : Icons.local_shipping_outlined,
                                label: t.truckType,
                                value: t.truckNumber,
                              ),
                            ))
                        .toList(),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final AppUser user;
  final String role;

  const _ProfileHeader({required this.user, required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.bg,
            child: Icon(
              role == 'driver'
                  ? Icons.local_shipping_outlined
                  : role == 'company'
                  ? Icons.apartment_outlined
                  : Icons.person_outline,
              color: AppColors.gold,
              size: 36,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            user.name ?? '—',
            style: const TextStyle(
              color: AppColors.cream,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              role.isEmpty
                  ? 'User'
                  : role[0].toUpperCase() + role.substring(1),
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section title ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

// ── Stat card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Info tile ─────────────────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.gold, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.cream,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
