import 'package:flutter/material.dart';

import '../API/config.dart';
import 'register_shared.dart';

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
      backgroundColor: LightColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(color: LightColors.successBg, shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle_rounded, color: LightColors.success, size: 46),
                  ),
                  const Positioned(top: 0, right: 6, child: Text('🎉', style: TextStyle(fontSize: 16))),
                  const Positioned(bottom: 4, left: 4, child: Text('✨', style: TextStyle(fontSize: 14))),
                ],
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'Welcome Back!',
                  style: TextStyle(color: LightColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Login successful',
                  style: TextStyle(color: LightColors.textSecondary, fontSize: 14),
                ),
              ),
              const SizedBox(height: 36),
              const Text(
                'Select your role to continue',
                style: TextStyle(color: LightColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3),
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
              LightPrimaryButton(label: 'Continue', color: LightColors.navy, onPressed: _continue),
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
            color: LightColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: active ? LightColors.gold : LightColors.border, width: active ? 1.4 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: active ? LightColors.gold.withOpacity(0.15) : LightColors.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: active ? LightColors.goldMuted : const Color(0xFFA0A4AC), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: active ? LightColors.textPrimary : const Color(0xFFA0A4AC),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: LightColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (active) const Icon(Icons.chevron_right_rounded, color: LightColors.gold),
            ],
          ),
        ),
      ),
    );
  }
}
