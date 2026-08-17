import 'package:shared_preferences/shared_preferences.dart';

/// Locally-persisted "saved for later" shipment offers (driver Available
/// Shipments screen, 2026-08-17 mockup's "Saved" tab). No backend support
/// exists for this — it's essentially a personal shortlist, so an
/// on-device bookmark list (SharedPreferences) is enough rather than
/// adding a new table/endpoint. Not synced across devices/reinstalls,
/// which is an acceptable tradeoff for this use case.
class SavedOffers {
  static const _key = 'saved_offer_ids';

  static Future<Set<int>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list.map((e) => int.tryParse(e) ?? -1).where((e) => e != -1).toSet();
  }

  static Future<bool> isSaved(int offerId) async {
    final all = await getAll();
    return all.contains(offerId);
  }

  static Future<Set<int>> toggle(int offerId) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await getAll();
    if (all.contains(offerId)) {
      all.remove(offerId);
    } else {
      all.add(offerId);
    }
    await prefs.setStringList(_key, all.map((e) => e.toString()).toList());
    return all;
  }
}
