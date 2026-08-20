import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../API/DriverService.dart';
import '../API/ShipmentOfferService.dart';
import '../API/config.dart';
import '../models/ShipmentOffer.dart';
import '../utils/offer_accept_flow.dart';
import '../utils/saved_offers.dart';
import 'DriverOfferDetailsPage.dart';

/// Driver redesign Phase 2 (2026-08-17 mockup): "Available Shipments" —
/// search and All/Nearby/Saved tabs, on top of the existing
/// accept-with-a-truck flow (now shared with DriverOfferDetailsPage via
/// utils/offer_accept_flow.dart).
///
/// 2026-08-27: dropped the truck-type filter chip — this list is already
/// the driver's own eligible offers (the backend's hard-eligibility filter
/// in MatchingService only ever surfaces offers the driver's own truck
/// qualifies for), so a driver filtering "by truck type" had nothing
/// meaningful to narrow: every offer here already matches their truck.
///
/// "Nearby" uses ShipmentOffer.originLat/originLng (real DB columns, see
/// the 2026-08-16 geo-matching migration) compared against the driver's own
/// current GPS fix — honest about it: most offers don't have pickup
/// coordinates yet since the company-side Create Shipment form doesn't
/// collect them, so this tab may legitimately be sparse today rather than
/// faking a distance for offers that don't have one.
///
/// "Saved" is an on-device bookmark list (SharedPreferences via
/// utils/saved_offers.dart) — no backend support for this exists, and
/// doesn't need to.
enum _OfferTab { all, nearby, saved }

class DriverOffersPage extends StatefulWidget {
  const DriverOffersPage({super.key});

  @override
  State<DriverOffersPage> createState() => _DriverOffersPageState();
}

class _DriverOffersPageState extends State<DriverOffersPage> {
  final _offerService = ShipmentOfferService();
  final _driverService = DriverService();
  late Future<List<ShipmentOffer>> _offersFuture;
  bool _isAccepting = false;

  bool? _isAvailable;
  bool _isUpdatingAvailability = false;

  final _searchController = TextEditingController();
  String _searchQuery = '';
  _OfferTab _tab = _OfferTab.all;

  Set<int> _savedIds = {};
  Position? _myPosition;

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadMyStatus();
    _loadSaved();
    _loadMyPosition();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _offersFuture = _offerService.fetchAvailableOffers();
    });
  }

  Future<void> _loadSaved() async {
    final ids = await SavedOffers.getAll();
    if (mounted) setState(() => _savedIds = ids);
  }

  Future<void> _loadMyPosition() async {
    try {
      // Location permission is already requested app-wide by
      // DriverLocationReporter (HomeScreen.initState for drivers) — this
      // just reads whatever fix is already available, doesn't prompt again.
      final last = await Geolocator.getLastKnownPosition();
      if (mounted) setState(() => _myPosition = last);
    } catch (_) {
      // Nearby tab just won't be able to sort/show distance — not fatal.
    }
  }

  Future<void> _loadMyStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('id');
      final drivers = await _driverService.fetchDriver();
      final me = drivers.where((d) => d.user_id == userId).toList();
      if (!mounted || me.isEmpty) return;
      setState(() => _isAvailable = me.first.status == 'available');
    } catch (_) {}
  }

  Future<void> _toggleAvailability(bool value) async {
    setState(() {
      _isUpdatingAvailability = true;
      _isAvailable = value;
    });

    final result = await DriverService.updateMyStatus(value ? 'available' : 'unavailable');

    if (!mounted) return;
    setState(() => _isUpdatingAvailability = false);

    if (result['success'] != true) {
      setState(() => _isAvailable = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Could not update status'), backgroundColor: LightColors.error),
      );
    }
  }

  Future<void> _acceptOffer(ShipmentOffer offer) async {
    setState(() => _isAccepting = true);
    final ok = await acceptOfferFlow(context, offer);
    if (!mounted) return;
    setState(() => _isAccepting = false);
    if (ok) _refresh();
  }

  Future<void> _openDetails(ShipmentOffer offer) async {
    final accepted = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => DriverOfferDetailsPage(offer: offer)));
    _loadSaved();
    if (accepted == true) _refresh();
  }

  double? _distanceKm(ShipmentOffer o) {
    if (_myPosition == null || o.originLat == null || o.originLng == null) return null;
    return Geolocator.distanceBetween(_myPosition!.latitude, _myPosition!.longitude, o.originLat!, o.originLng!) / 1000;
  }

  List<ShipmentOffer> _visible(List<ShipmentOffer> all) {
    var result = all;

    if (_searchQuery.isNotEmpty) {
      result = result.where((o) {
        final haystack = '${o.origin} ${o.destination} ${o.requiredTruckType} ${o.description}'.toLowerCase();
        return haystack.contains(_searchQuery);
      }).toList();
    }

    switch (_tab) {
      case _OfferTab.all:
        break;
      case _OfferTab.saved:
        result = result.where((o) => _savedIds.contains(o.id)).toList();
        break;
      case _OfferTab.nearby:
        result = result.where((o) => o.originLat != null && o.originLng != null).toList();
        result.sort((a, b) => (_distanceKm(a) ?? double.infinity).compareTo(_distanceKm(b) ?? double.infinity));
        break;
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        title: const Text('Available Shipments', style: TextStyle(color: LightColors.cream)),
        iconTheme: const IconThemeData(color: LightColors.cream),
        actions: [
          if (_isAvailable != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Row(
                children: [
                  Text(_isAvailable! ? 'Available' : 'Unavailable',
                      style: TextStyle(color: _isAvailable! ? LightColors.success : LightColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                  Switch(value: _isAvailable!, activeColor: LightColors.gold, onChanged: _isUpdatingAvailability ? null : _toggleAvailability),
                ],
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            color: LightColors.gold,
            onRefresh: () async => _refresh(),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: LightColors.cream, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search by location, load type...',
                        hintStyle: const TextStyle(color: LightColors.muted, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: LightColors.muted, size: 20),
                        filled: true,
                        fillColor: LightColors.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LightColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LightColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LightColors.gold)),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: FutureBuilder<List<ShipmentOffer>>(
                    future: _offersFuture,
                    builder: (context, snapshot) {
                      final all = snapshot.data ?? [];
                      final allCount = _tabCount(all, _OfferTab.all);
                      final nearbyCount = _tabCount(all, _OfferTab.nearby);
                      final savedCount = _tabCount(all, _OfferTab.saved);
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(
                          children: [
                            _TabChip(label: 'All ($allCount)', active: _tab == _OfferTab.all, onTap: () => setState(() => _tab = _OfferTab.all)),
                            const SizedBox(width: 8),
                            _TabChip(label: 'Nearby ($nearbyCount)', active: _tab == _OfferTab.nearby, onTap: () => setState(() => _tab = _OfferTab.nearby)),
                            const SizedBox(width: 8),
                            _TabChip(label: 'Saved ($savedCount)', active: _tab == _OfferTab.saved, onTap: () => setState(() => _tab = _OfferTab.saved)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: FutureBuilder<List<ShipmentOffer>>(
                    future: _offersFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 80),
                          child: Center(child: CircularProgressIndicator(color: LightColors.gold)),
                        );
                      }
                      if (snapshot.hasError) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 80),
                          child: Center(child: Text('Could not load offers', style: TextStyle(color: LightColors.error))),
                        );
                      }

                      final offers = _visible(snapshot.data ?? []);
                      if (offers.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
                          child: Center(
                            child: Text(
                              switch (_tab) {
                                _OfferTab.saved => 'No saved offers yet.',
                                _OfferTab.nearby => 'No nearby offers with pickup coordinates right now.',
                                _OfferTab.all => 'No matching offers right now.',
                              },
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: LightColors.muted),
                            ),
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        child: Column(
                          children: [
                            for (int i = 0; i < offers.length; i++) ...[
                              if (i > 0) const SizedBox(height: 12),
                              _OfferCard(
                                offer: offers[i],
                                distanceKm: _distanceKm(offers[i]),
                                saved: _savedIds.contains(offers[i].id),
                                onDetails: () => _openDetails(offers[i]),
                                onAccept: () => _acceptOffer(offers[i]),
                                onToggleSave: () async {
                                  await SavedOffers.toggle(offers[i].id);
                                  _loadSaved();
                                },
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_isAccepting)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator(color: LightColors.gold)),
            ),
        ],
      ),
    );
  }

  int _tabCount(List<ShipmentOffer> all, _OfferTab tab) {
    var result = all;
    if (_searchQuery.isNotEmpty) {
      result = result.where((o) => '${o.origin} ${o.destination} ${o.requiredTruckType} ${o.description}'.toLowerCase().contains(_searchQuery)).toList();
    }
    switch (tab) {
      case _OfferTab.all:
        return result.length;
      case _OfferTab.nearby:
        return result.where((o) => o.originLat != null && o.originLng != null).length;
      case _OfferTab.saved:
        return result.where((o) => _savedIds.contains(o.id)).length;
    }
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? LightColors.gold : LightColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: active ? LightColors.gold : LightColors.border),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12.5, color: active ? LightColors.deepNavy : LightColors.muted, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  final ShipmentOffer offer;
  final double? distanceKm;
  final bool saved;
  final VoidCallback onDetails;
  final VoidCallback onAccept;
  final VoidCallback onToggleSave;

  const _OfferCard({
    required this.offer,
    required this.distanceKm,
    required this.saved,
    required this.onDetails,
    required this.onAccept,
    required this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: LightColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: LightColors.border, width: 0.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text('${offer.origin} → ${offer.destination}',
                    style: const TextStyle(color: LightColors.cream, fontWeight: FontWeight.w600, fontSize: 15)),
              ),
              InkWell(
                onTap: onToggleSave,
                child: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: LightColors.gold, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${offer.requiredTruckType} · ${offer.orderType == 'internal' ? 'Domestic' : 'Cross-border'}'
            '${offer.needsPermit ? " · permit" : ""}'
            '${offer.isHazardous ? " · hazardous" : ""}'
            '${offer.isFragile ? " · fragile" : ""}'
            '${distanceKm != null ? " · ${distanceKm!.toStringAsFixed(0)} km away" : ""}',
            style: const TextStyle(color: LightColors.muted, fontSize: 12),
          ),
          if (offer.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(offer.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: LightColors.muted, fontSize: 12)),
          ],
          if (offer.priceToDriver.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Price: ${offer.priceToDriver} AED', style: const TextStyle(color: LightColors.gold, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDetails,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: const BorderSide(color: LightColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Details', style: TextStyle(color: LightColors.cream, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    backgroundColor: LightColors.gold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Accept', style: TextStyle(color: LightColors.deepNavy, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
