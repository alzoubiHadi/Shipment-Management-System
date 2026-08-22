import 'dart:async';

import 'package:flutter/material.dart';
import '../API/ShipmentServices.dart';
import '../API/config.dart';
import '../l10n/app_localizations.dart';
import '../models/Appuser.dart';
import '../models/Shipment.dart';
import 'AdminShipmentStatusStyle.dart';
import 'ShipmentDetailsPageCompany.dart';
import 'ShipmentTrackingPage.dart';

// ── Page ─────────────────────────────────────────────────────────────────────
// Company redesign Phase 3 (2026-08-17 mockup): "My Shipments" list,
// light-themed with search + status filters. The Tracking screen itself
// (ShipmentTrackingPage) is also on LightColors already — this note used to
// say it stayed on the old dark theme, but that's out of date (verified
// 2026-08-27): it uses LightColors.bg/surface/gold/border throughout, same
// as this screen.
//
// 2026-08-28: restyled to match the admin Shipments redesign
// (AdminShipmentsScreen, 2026-08-24) — same header-with-refresh layout,
// same scrollable status-chip row (reusing the exact chip labels/order:
// All/Active/Pending/Delivered/Cancelled), and the same card design
// (AdminStatusPill, route line, progress dots for an active shipment),
// adapted for a company's own list: cards keep the driver's name (instead
// of admin's company name) and the tap target still opens
// ShipmentDetailsPageCompany rather than admin's per-status-group detail
// screens, since that single detail page already covers this role. The
// quick "open live map" shortcut on active shipments — not present on the
// admin cards, which route the whole card to Live Tracking directly — is
// kept as a small trailing button so a company can still jump straight to
// the map without leaving the list.

class Compnayshipments extends StatefulWidget {
  final AppUser user;
  const Compnayshipments({super.key, required this.user});

  @override
  State<Compnayshipments> createState() => _CompnayshipmentsState();
}

class _CompnayshipmentsState extends State<Compnayshipments> {
  final _service = ShipmentService();

  List<(String, String)> _chips(AppLocalizations t) => [
        ('all', t.filterAll),
        ('active', t.adminShipmentsChipActive),
        ('pending', t.tabPendingLabel),
        ('delivered', t.adminShipmentsChipDelivered),
        ('cancelled', t.adminShipmentsChipCancelled),
      ];

  late Future<List<Shipment>> _shipmentsFuture;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedGroup = 'all';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _shipmentsFuture = _service.fetchShipmentscompany();

    _searchController.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        setState(() {
          _searchQuery = _searchController.text.trim().toLowerCase();
        });
      });
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _shipmentsFuture = _service.fetchShipmentscompany();
    });
  }

  // Same coarse grouping the old "All/Pending/Live/Delivered" tabs used,
  // renamed to match AdminShipmentsScreen's group vocabulary
  // (pending/active/delivered/cancelled) so AdminStatusPill's color coding
  // lines up correctly. status meanings: see statusLabel() in config.dart —
  // 0 pending, 1 in transit, 2 out for delivery, 3 delivered, 4 cancelled,
  // 5 delayed (delayed still counts as "active": there's a live shipment
  // to track, it's just running behind).
  String _groupFor(int status) => switch (status) {
        0 => 'pending',
        3 => 'delivered',
        4 => 'cancelled',
        _ => 'active',
      };

  List<Shipment> _filterShipments(List<Shipment> list) {
    var result = list;

    if (_selectedGroup != 'all') {
      result = result.where((s) => _groupFor(s.status) == _selectedGroup).toList();
    }

    if (_searchQuery.isNotEmpty) {
      result = result.where((s) {
        final tracking = (s.trackingNumber ?? '').toLowerCase();
        final id = s.id.toString();
        final route = '${s.origin} ${s.destination}'.toLowerCase();
        return tracking.contains(_searchQuery) || id.contains(_searchQuery) || route.contains(_searchQuery);
      }).toList();
    }

    return result;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final chips = _chips(t);
    return Container(
      color: LightColors.bg,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  Text(t.myShipmentsTitle,
                      style: const TextStyle(color: LightColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded, color: LightColors.textSecondary),
                  ),
                ],
              ),
            ),

            // SEARCH BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: LightColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: t.companyShipmentsSearchHint,
                  hintStyle: const TextStyle(color: LightColors.textSecondary, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: LightColors.textSecondary, size: 20),
                  filled: true,
                  fillColor: LightColors.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: LightColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: LightColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: LightColors.gold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // STATUS CHIPS
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: chips.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final (value, label) = chips[i];
                  final selected = _selectedGroup == value;
                  return ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedGroup = value),
                    selectedColor: LightColors.navy,
                    backgroundColor: LightColors.surface,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : LightColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: selected ? LightColors.navy : LightColors.border),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: FutureBuilder<List<Shipment>>(
                future: _shipmentsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _LoadingState();
                  }

                  if (snapshot.hasError) {
                    return _ErrorState(
                      message: snapshot.error.toString(),
                      onRetry: _refresh,
                    );
                  }

                  final shipments = _filterShipments(snapshot.data ?? []);

                  if (shipments.isEmpty) {
                    return const _EmptyState();
                  }

                  return RefreshIndicator(
                    color: LightColors.gold,
                    onRefresh: _refresh,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      itemCount: shipments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _ShipmentCard(shipment: shipments[i], group: _groupFor(shipments[i].status)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── States ───────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: LightColors.gold),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: LightColors.error, size: 48),
            const SizedBox(height: 16),
            Text(t.failedToLoadShipments,
                style: const TextStyle(color: LightColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: LightColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, color: LightColors.goldMuted),
              label: Text(t.commonRetry, style: const TextStyle(color: LightColors.goldMuted)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, color: LightColors.textSecondary, size: 48),
            const SizedBox(height: 16),
            Text(t.noShipmentsHere, style: const TextStyle(color: LightColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(t.shipmentsMatchingFilterEmpty,
                textAlign: TextAlign.center, style: const TextStyle(color: LightColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ── ShipmentCard ─────────────────────────────────────────────────────────────
// Mirrors AdminShipmentsScreen's _ShipmentCard layout (same AdminStatusPill,
// same route line, same progress-dots treatment for an active shipment) —
// see this file's top docblock for what's kept company-specific.

class _ShipmentCard extends StatelessWidget {
  final Shipment shipment;
  final String group;

  const _ShipmentCard({required this.shipment, required this.group});

  bool get _isActive => group == 'active';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ShipmentDetailsPageCompany(shipment: shipment)),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: LightColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: LightColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('SH-${shipment.id}',
                      style: const TextStyle(color: LightColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                ),
                AdminStatusPill(label: statusLabel(shipment.status), statusGroup: group),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.circle, size: 6, color: LightColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${shipment.origin} → ${shipment.destination}',
                    style: const TextStyle(color: LightColors.textSecondary, fontSize: 12.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (shipment.driverName != null) ...[
              const SizedBox(height: 8),
              Text(shipment.driverName!, style: const TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
            if (_isActive) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _ProgressDots(current: shipment.currentStage, total: shipment.totalStages)),
                  const SizedBox(width: 10),
                  Material(
                    color: LightColors.navy,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ShipmentTrackingPage(shipment: shipment, readOnly: true)),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.map_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (group == 'pending') ...[
              const SizedBox(height: 6),
              Text(t.adminShipmentsWaitingForDriver, style: const TextStyle(color: LightColors.pending, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact "● ━ ● ━ ○" horizontal progress indicator — same visual as
/// AdminShipmentsScreen's _ProgressDots, duplicated here since Dart
/// privacy is per-file.
class _ProgressDots extends StatelessWidget {
  final int current;
  final int total;

  const _ProgressDots({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final dots = <Widget>[];
    for (var i = 1; i <= total; i++) {
      final done = i <= current;
      dots.add(Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? LightColors.navy : LightColors.border,
        ),
      ));
      if (i != total) {
        dots.add(Expanded(
          child: Container(height: 2, color: i < current ? LightColors.navy : LightColors.border),
        ));
      }
    }
    return Row(children: dots);
  }
}
