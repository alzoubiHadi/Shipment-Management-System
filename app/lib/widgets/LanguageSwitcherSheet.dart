import 'package:flutter/material.dart';

import '../API/config.dart';
import '../l10n/app_localizations.dart';
import '../l10n/locale_controller.dart';

/// Shared language-picker bottom sheet (2026-08-22 Arabic localization
/// pass) — one implementation reused from AdminSettingsPage, Profile.dart,
/// and CompanyProfileScreen.dart's own tile widgets, each of which just
/// calls [showLanguagePicker] from their existing tap handler rather than
/// duplicating a picker UI three times. Selecting a language calls
/// [LocaleController.setLocale], which persists the choice and rebuilds
/// the whole app (via main.dart's ValueListenableBuilder) immediately —
/// no restart, no navigation needed after picking.
Future<void> showLanguagePicker(BuildContext context) async {
  final t = AppLocalizations.of(context)!;
  await showModalBottomSheet(
    context: context,
    backgroundColor: LightColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                t.languagePickerTitle,
                style: const TextStyle(color: LightColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          _LanguageOption(code: 'en', label: t.languageEnglish, selected: !LocaleController.isArabic),
          _LanguageOption(code: 'ar', label: t.languageArabic, selected: LocaleController.isArabic),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _LanguageOption extends StatelessWidget {
  final String code;
  final String label;
  final bool selected;

  const _LanguageOption({required this.code, required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: const TextStyle(color: LightColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: selected ? const Icon(Icons.check_circle_rounded, color: LightColors.gold) : null,
      onTap: () {
        LocaleController.setLocale(code);
        Navigator.pop(context);
      },
    );
  }
}
