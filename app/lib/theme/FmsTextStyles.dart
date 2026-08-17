import 'package:flutter/material.dart';

import '../API/config.dart';

/// FMS design system typography scale (2026-08-24). One consistent set of
/// sizes/weights used across Admin, Company, and Driver — replaces each
/// screen hand-rolling its own `TextStyle(fontSize: ..., fontWeight: ...)`
/// literals. Screens are free to keep using raw `TextStyle` for one-off
/// tweaks (color overrides, letter-spacing, etc.) — this class exists so
/// the COMMON sizes agree app-wide, not to force every text widget through
/// it.
class FmsTextStyles {
  static const pageTitle = TextStyle(
    color: LightColors.textPrimary,
    fontSize: 26,
    fontWeight: FontWeight.w800,
  );

  static const sectionTitle = TextStyle(
    color: LightColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );

  static const cardTitle = TextStyle(
    color: LightColors.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w700,
  );

  static const body = TextStyle(
    color: LightColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static const secondary = TextStyle(
    color: LightColors.textSecondary,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
  );

  static const caption = TextStyle(
    color: LightColors.textSecondary,
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
  );

  static const buttonLabel = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w700,
  );
}
