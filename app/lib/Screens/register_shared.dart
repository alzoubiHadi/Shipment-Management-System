import 'package:flutter/material.dart';

import '../API/config.dart';

// ─── Password Strength (shared by CompanyRegisterScreen & DriverRegisterScreen) ──

enum PasswordStrength { none, weak, fair, strong }

PasswordStrength evaluatePasswordStrength(String p) {
  if (p.isEmpty) return PasswordStrength.none;
  int score = 0;
  if (p.length >= 8) score++;
  if (p.length >= 12) score++;
  if (RegExp(r'[A-Z]').hasMatch(p)) score++;
  if (RegExp(r'[0-9]').hasMatch(p)) score++;
  if (RegExp(r'[!@#\$&*~%^]').hasMatch(p)) score++;
  if (score <= 1) return PasswordStrength.weak;
  if (score <= 3) return PasswordStrength.fair;
  return PasswordStrength.strong;
}

class PasswordStrengthBar extends StatelessWidget {
  final PasswordStrength strength;
  const PasswordStrengthBar({super.key, required this.strength});

  Color get _color => switch (strength) {
        PasswordStrength.weak => const Color(0xFFE57373),
        PasswordStrength.fair => const Color(0xFFFFB74D),
        PasswordStrength.strong => const Color(0xFF81C784),
        _ => Colors.transparent,
      };

  String get _label => switch (strength) {
        PasswordStrength.weak => 'Weak',
        PasswordStrength.fair => 'Fair',
        PasswordStrength.strong => 'Strong',
        _ => '',
      };

  int get _filled => switch (strength) {
        PasswordStrength.weak => 1,
        PasswordStrength.fair => 2,
        PasswordStrength.strong => 3,
        _ => 0,
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...List.generate(
          3,
          (i) => Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 3,
              margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: i < _filled ? _color : LightColors.border,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(_label, style: TextStyle(fontSize: 11, color: _color)),
      ],
    );
  }
}

// ─── Shared text field style ──────────────────────────────────────────────────
// DEAD CODE (as of Admin Phase 6 audit, 2026-08-20): unused now that
// CompanyRegisterScreen/DriverRegisterScreen use buildLightTextField below.
// Left in place — file deletion isn't available in this environment.

Widget buildAuthTextField({
  required TextEditingController controller,
  required String label,
  bool obscure = false,
  bool hasError = false,
  bool enabled = true,
  TextInputType? keyboardType,
  Widget? suffix,
  int maxLines = 1,
}) {
  return TextField(
    controller: controller,
    obscureText: obscure,
    enabled: enabled,
    keyboardType: keyboardType,
    maxLines: maxLines,
    style: const TextStyle(color: Color(0xFFF5F0E8), fontSize: 15),
    cursorColor: const Color(0xFFD4AF37),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: hasError ? const Color(0xFFE57373) : const Color(0xFF4A4540),
        fontSize: 13,
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF111113),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2A2520)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: hasError ? const Color(0xFFE57373) : const Color(0xFF2A2520),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: hasError ? const Color(0xFFE57373) : const Color(0xFFD4AF37),
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    ),
  );
}

// ─── Light theme building blocks (2026-08-21 design pass) ─────────────────
// Label-above-field style matching the Login/Registration mockups, as
// opposed to the floating-label dark-theme fields above. Used by
// LoginScreen, RoleConfirmScreen, DriverRegisterScreen, and
// CompanyRegisterScreen.

Widget buildLightTextField({
  required TextEditingController controller,
  required String label,
  String? hint,
  bool obscure = false,
  bool hasError = false,
  bool enabled = true,
  TextInputType? keyboardType,
  Widget? prefixIcon,
  Widget? suffix,
  int maxLines = 1,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: const TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        obscureText: obscure,
        enabled: enabled,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: LightColors.textPrimary, fontSize: 14),
        cursorColor: LightColors.gold,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFA0A4AC), fontSize: 14),
          prefixIcon: prefixIcon,
          suffixIcon: suffix,
          filled: true,
          fillColor: enabled ? LightColors.surface : LightColors.bg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: hasError ? LightColors.error : LightColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: hasError ? LightColors.error : LightColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: hasError ? LightColors.error : LightColors.gold, width: 1.4),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    ],
  );
}

/// Same tap-to-open-a-picker concept as [PickerField] but styled for the
/// light theme (label above, white card, grey border).
class LightPickerField extends StatelessWidget {
  final String label;
  final String? value;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;
  final bool hasError;

  const LightPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.onTap,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: LightColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: hasError ? LightColors.error : LightColors.border),
            ),
            child: Row(
              children: [
                Icon(icon, color: value == null ? const Color(0xFFA0A4AC) : LightColors.gold, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value ?? hint,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: value == null ? const Color(0xFFA0A4AC) : LightColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFFA0A4AC), size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Thin gold progress line + "Step X of N" label, matching the top of every
/// screen in the registration wizards.
class LightStepProgress extends StatelessWidget {
  final int current; // 0-based
  final int total;
  const LightStepProgress({super.key, required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('Step ${current + 1} of $total', style: const TextStyle(color: LightColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: (current + 1) / total,
            minHeight: 3,
            backgroundColor: LightColors.border,
            valueColor: const AlwaysStoppedAnimation(LightColors.gold),
          ),
        ),
      ],
    );
  }
}

/// Solid rounded button — navy for in-wizard "Next"/"Verify"/"Submit"
/// actions, gold where the mockups use gold (Log In, Update Application).
class LightPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color color;
  final Color textColor;
  final IconData? icon;

  const LightPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.color = LightColors.navy,
    this.textColor = Colors.white,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: loading
            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: textColor))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, size: 18, color: textColor), const SizedBox(width: 8)],
                  Text(label, style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }
}

/// White outlined button (Log Out, Contact Support, Change Email...).
class LightOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  const LightOutlineButton({super.key, required this.label, required this.onPressed, this.color = LightColors.textPrimary});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: LightColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class LightErrorBanner extends StatelessWidget {
  final String message;
  const LightErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: LightColors.errorBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LightColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: LightColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13, color: LightColors.error))),
        ],
      ),
    );
  }
}

/// DEAD CODE (as of Admin Phase 6 audit, 2026-08-20): superseded by
/// [LightPickerField] above, which is what DriverRegisterScreen and
/// CompanyRegisterScreen actually use now. Left in place — file deletion
/// isn't available in this environment.
class PickerField extends StatelessWidget {
  final String label;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;
  final bool hasError;

  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF111113),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasError
                ? const Color(0xFFE57373)
                : (value == null ? const Color(0xFF2A2520) : const Color(0xFFD4AF37)),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: value == null ? const Color(0xFF6B6660) : const Color(0xFFD4AF37), size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value ?? label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: value == null ? const Color(0xFF6B6660) : const Color(0xFFF5F0E8),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
