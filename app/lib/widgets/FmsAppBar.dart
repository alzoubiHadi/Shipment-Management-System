import 'package:flutter/material.dart';

import '../API/config.dart';

/// FMS design system app bar (2026-08-24) — flat, light, navy title text.
/// Most already-migrated screens hand-roll an `AppBar` with these exact
/// property values already; this centralizes it (and now also matches
/// `FmsTheme.lightTheme`'s `AppBarTheme`, so using a bare `AppBar()` with
/// no overrides gets the same look automatically).
class FmsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;

  const FmsAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: LightColors.bg,
      elevation: 0,
      centerTitle: centerTitle,
      leading: leading,
      iconTheme: const IconThemeData(color: LightColors.textPrimary),
      title: Text(title, style: const TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
      actions: actions,
    );
  }
}
