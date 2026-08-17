import 'package:flutter/material.dart';

import '../API/AdminDashboardService.dart';
import '../API/config.dart';
import '../models/Appuser.dart';

/// The "+" quick action on the admin bottom nav (2026-08-21 mockup) — lets
/// the admin jump straight into reviewing one category of pending
/// registration instead of scrolling the unified list.
///
/// Doesn't navigate anywhere itself — [onSelect] tells the owning
/// HomeScreen to switch to the Registration Requests tab pre-filtered to
/// this type, then this screen pops itself to reveal it (HomeScreen stays
/// the single source of truth for which tab/filter is active, since
/// RegistrationRequestsScreen lives inside its IndexedStack).
class SelectRequestTypeScreen extends StatefulWidget {
  final AppUser user;
  final void Function(String type) onSelect; // 'drivers' | 'companies'

  const SelectRequestTypeScreen({super.key, required this.user, required this.onSelect});

  @override
  State<SelectRequestTypeScreen> createState() => _SelectRequestTypeScreenState();
}

class _SelectRequestTypeScreenState extends State<SelectRequestTypeScreen> {
  late Future<AdminDashboardStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = AdminDashboardService().fetchStats();
  }

  void _open(BuildContext context, String type) {
    widget.onSelect(type);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: LightColors.textPrimary),
        title: const Text('Select Request Type',
            style: TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choose the type of registration request to review',
                  style: TextStyle(color: LightColors.textSecondary, fontSize: 13.5)),
              const SizedBox(height: 20),
              FutureBuilder<AdminDashboardStats>(
                future: _statsFuture,
                builder: (context, snapshot) {
                  final stats = snapshot.data;
                  return Column(
                    children: [
                      _RequestTypeCard(
                        icon: Icons.person_outline,
                        title: 'Driver Registrations',
                        subtitle: 'Review and manage driver registration requests',
                        pending: stats?.registrationPendingDrivers,
                        color: LightColors.success,
                        bg: LightColors.successBg,
                        onTap: () => _open(context, 'drivers'),
                      ),
                      const SizedBox(height: 14),
                      _RequestTypeCard(
                        icon: Icons.apartment_outlined,
                        title: 'Company Registrations',
                        subtitle: 'Review and manage company registration requests',
                        pending: stats?.registrationPendingCompanies,
                        color: LightColors.pending,
                        bg: LightColors.pendingBg,
                        onTap: () => _open(context, 'companies'),
                      ),
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
}

class _RequestTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int? pending;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _RequestTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.pending,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LightColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: LightColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(color: LightColors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(color: LightColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        pending == null ? '… Pending' : '$pending Pending',
                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: LightColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
