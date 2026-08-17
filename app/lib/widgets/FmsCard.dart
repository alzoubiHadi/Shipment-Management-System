import 'package:flutter/material.dart';

import '../API/config.dart';

/// FMS design system shared card (2026-08-24). `Radius: 16px, Border: 1px
/// LightColors.border, no/very light shadow, Padding: 16px` — per the
/// unified design spec, replacing each screen's own hand-rolled
/// `Container(decoration: BoxDecoration(...))` card wrapper.
class FmsCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  const FmsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? LightColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LightColors.border),
      ),
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

/// A card with a solid Navy background — the deliberate "hero" treatment
/// for a handful of specific elements (Wallet balance card, Current Trip
/// card, financial highlight cards) called out in the FMS design spec as
/// staying dark/Navy against an otherwise light screen, not a parallel dark
/// theme.
class FmsHeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const FmsHeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: LightColors.navy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: card,
      ),
    );
  }
}
