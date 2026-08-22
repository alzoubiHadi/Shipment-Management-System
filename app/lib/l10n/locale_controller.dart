import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single source of truth for the app's active language (2026-08-22 Arabic
/// localization pass). A bare `ValueNotifier<Locale>` — matches the app's
/// existing lightweight state-management idiom (plain StatefulWidget +
/// setState, plus a handful of global ValueNotifiers like
/// DriverLocationReporter.hasActiveTrip / NotificationBadge.unreadCount)
/// rather than pulling in Provider/Bloc/Riverpod for a single global value.
///
/// main.dart wraps MaterialApp in a ValueListenableBuilder listening to
/// [locale], so calling [setLocale] rebuilds the whole app with the new
/// language immediately — no restart needed. Persisted to SharedPreferences
/// under the 'locale' key, alongside the other session keys every
/// `*Service` class already reads (token/role/id/name/email/loggedIn — see
/// AuthResponse.dart, ProfileService.dart, etc.).
///
/// [isArabic] is also read directly (no BuildContext needed) by
/// error_messages.dart and l10n/enum_labels.dart so the message-building
/// helpers deep in the API layer can be bilingual without threading
/// BuildContext/AppLocalizations through every service method's signature.
class LocaleController {
  LocaleController._();

  static const _prefsKey = 'locale';
  static const supportedLanguageCodes = ['en', 'ar'];

  /// Defaults to English until [load] resolves at app start. Not worth
  /// blocking the very first frame on a SharedPreferences read to avoid a
  /// brief English flash on an Arabic-preferring device — main() calls
  /// [load] before runApp() specifically to make that window as small as
  /// possible (see main.dart).
  static final ValueNotifier<Locale> locale = ValueNotifier<Locale>(const Locale('en'));

  static bool get isArabic => locale.value.languageCode == 'ar';

  /// Reads the persisted choice, if any. Call once at startup before
  /// runApp() (see main.dart) — a fresh install with no saved preference
  /// keeps the English default rather than guessing from the device locale,
  /// matching this app's existing "English unless a user opts into Arabic"
  /// behavior.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null && supportedLanguageCodes.contains(saved)) {
      locale.value = Locale(saved);
    }
  }

  static Future<void> setLocale(String languageCode) async {
    if (!supportedLanguageCodes.contains(languageCode)) return;
    locale.value = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, languageCode);
  }
}
