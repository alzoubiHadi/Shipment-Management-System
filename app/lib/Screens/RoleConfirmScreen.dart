import 'package:flutter/material.dart';

import '../API/config.dart';

/// Login-design screen 4 ("Login Successful — Select your role to
/// continue"). Per the 2026-08-19 design review: this account model has
/// exactly ONE fixed role per account (set at registration, never chosen
/// at login) — so this screen is a confirmation display, not a real
/// picker. Only the card matching [role] is enabled/highlighted; the
/// other two are shown greyed out so the layout still matches the design,
/// but tapping them does nothing. Tapping the active card (or waiting
/// briefly) continues to [next].
class RoleConfirmScreen extends StatefulWidget {
  final String role; // 'driver' | 'company' | 'admin' | 'super_admin' | 'sub_admin'
  final Widget next;

  const RoleConfirmScreen({super.key, required this.role, required this.next});

  @override
  State<RoleConfirmScreen> createState() => _RoleConfirmScreenState();
}

class _RoleConfirmScreenState extends State<RoleConfirmScreen> {
  bool get _isAdmin => ['admin', 'super_admin', 'sub_admin'].contains(widget.role);

  void _continue() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => widget.next),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 44),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'Welcome Back!',
                  style: TextStyle(color: AppColors.cream, fontSize: 24, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Login successful',
                  style: TextStyle(color: AppColors.muted, fontSize: 14),
                ),
              ),
              const SizedBox(height: 36),
              const Text(
                'Continue as',
                style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5),
              ),
              const SizedBox(height: 12),
              _RoleCard(
                icon: Icons.local_shipping_outlined,
                title: 'Driver',
                subtitle: 'View trips and manage deliveries',
                active: widget.role == 'driver',
                onTap: widget.role == 'driver' ? _continue : null,
              ),
              const SizedBox(height: 12),
              _RoleCard(
                icon: Icons.apartment_outlined,
                title: 'Company',
                subtitle: 'Manage your shipments',
                active: widget.role == 'company',
                onTap: widget.role == 'company' ? _continue : null,
              ),
              const SizedBox(height: 12),
              _RoleCard(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Admin',
                subtitle: 'System administration',
                active: _isAdmin,
                onTap: _isAdmin ? _continue : null,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(color: AppColors.bg, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback? onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: active ? AppColors.gold.withOpacity(0.08) : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: active ? AppColors.gold : AppColors.border, width: active ? 1.2 : 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: active ? AppColors.gold.withOpacity(0.15) : AppColors.border.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: active ? AppColors.gold : AppColors.muted, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: active ? AppColors.cream : AppColors.muted,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (active) const Icon(Icons.chevron_right_rounded, color: AppColors.gold),
            ],
          ),
        ),
      ),
    );
  }
}
