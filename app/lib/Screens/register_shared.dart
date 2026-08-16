import 'package:flutter/material.dart';

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
                color: i < _filled ? _color : const Color(0xFF2A2520),
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

/// A tappable field-styled container that opens a picker (file/date/dropdown
/// sheet) instead of a keyboard — used throughout the driver registration
/// form for file uploads and selection fields.
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
