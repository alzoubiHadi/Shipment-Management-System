import 'package:flutter/material.dart';

import '../API/config.dart';




class PlaceholderPage extends StatelessWidget {
  final String label;
  final IconData icon;

  const PlaceholderPage({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.muted),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w300, color: AppColors.cream),
            ),
            const SizedBox(height: 8),
            const Text('Coming soon', style: TextStyle(fontSize: 13, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}