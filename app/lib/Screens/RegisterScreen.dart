import 'package:flutter/material.dart';

import 'CompanyRegisterScreen.dart';
import 'DriverRegisterScreen.dart';

/// First step of sign-up: pick which kind of account to create. Each choice
/// opens its own dedicated registration form — companies and drivers now
/// collect very different data (a company just needs its basic info + trade
/// license; a driver's form covers driver info AND their truck in two
/// sections), so a single shared form no longer makes sense.
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'FMS',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'Create your\naccount.',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w300,
                  color: Color(0xFFF5F0E8),
                  height: 1.1,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose the kind of account you need',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B6660)),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: _RoleCard(
                        icon: Icons.apartment_rounded,
                        title: 'Company',
                        subtitle: 'Ship your cargo — request trucks and track deliveries',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CompanyRegisterScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: _RoleCard(
                        icon: Icons.local_shipping_rounded,
                        title: 'Individual (Driver)',
                        subtitle: 'Drive your own truck — get matched with shipments',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DriverRegisterScreen()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Already have an account? Sign in',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B6660)),
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
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF15130F), Color(0xFF0F0E0C)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2A2520)),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFFD4AF37), size: 30),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFF5F0E8),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Color(0xFF6B6660), fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF6B6660)),
          ],
        ),
      ),
    );
  }
}
