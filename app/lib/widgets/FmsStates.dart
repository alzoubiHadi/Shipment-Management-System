import 'package:flutter/material.dart';

import '../API/config.dart';
import 'FmsButtons.dart';

/// FMS design system shared loading/error/empty states (2026-08-24) — every
/// screen in this app was independently hand-rolling its own
/// `CircularProgressIndicator`/error `Column`/"No X found" text with
/// slightly different padding, icon, and copy each time. These three cover
/// the vast majority of cases; screens with a genuinely custom empty state
/// (illustrations, etc.) can still build their own.
class FmsLoadingState extends StatelessWidget {
  final String? message;
  const FmsLoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: LightColors.navy),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!, style: const TextStyle(color: LightColors.textSecondary, fontSize: 12.5)),
          ],
        ],
      ),
    );
  }
}

class FmsErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const FmsErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: LightColors.error, size: 40),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: LightColors.textSecondary, fontSize: 13)),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              SizedBox(width: 140, child: FmsSecondaryButton(label: 'Retry', onPressed: onRetry, icon: Icons.refresh_rounded)),
            ],
          ],
        ),
      ),
    );
  }
}

class FmsEmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const FmsEmptyState({super.key, required this.message, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: LightColors.textMuted, size: 40),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: LightColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
