import 'package:flutter/material.dart';
import '../API/ShipmentServices.dart';
import '../API/config.dart';
import '../l10n/app_localizations.dart';
import '../models/Appuser.dart';
import '../models/Shipment.dart';
import 'ShipmentDetailsPageCompany.dart';
import 'ShipmentTrackingPage.dart';

// ── Page ─────────────────────────────────────────────────────────────────────
// Company redesign Phase 3 (2026-08-17 mockup): "My Shipments" list,
// light-themed with All/Pending/Live/Delivered tabs. The Tracking screen
// itself (ShipmentTrackingPage) is also on LightColors already — this note
// used to say it stayed on the old dark theme, but that's out of date
// (verified 2026-08-27): it uses LightColors.bg/surface/gold/border
// throughout, same as this screen.

enum _ShipmentTab { all, pending, live, delivered }

class Compnayshipments extends StatefulWidget {
  final AppUser user;
  const Compnayshipments({super.key, required this.user});

  @override
  State<Compnayshipments> createState() => _CompnayshipmentsState();
}

class _CompnayshipmentsState extends State<Compnayshipments> {
  final _service = ShipmentService();

  late Future<List<Shipment>> _shipmentsFuture;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  _ShipmentTab _tab = _ShipmentTab.all;

  @override
  void initState() {
    super.initState();
    _shipmentsFuture = _service.fetchShipmentscompany();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  void _refresh() => setState(() {
        _shipmentsFuture = _service.fetchShipmentscompany();
      });

  List<Shipment> _filterShipments(List<Shipment> list) {
    var result = list;

    result = switch (_tab) {
      _ShipmentTab.all => result,
      _ShipmentTab.pending => result.where((s) => s.status == 0).toList(),
      _ShipmentTab.live => result.where((s) => s.status == 1 || s.status == 2 || s.status == 5).toList(),
      _ShipmentTab.delivered => result.where((s) => s.status == 3).toList(),
    };

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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Container(
      color: LightColors.bg,
      child: SafeArea(
        child: RefreshIndicator(
          color: LightColors.gold,
          onRefresh: () async => _refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Text(t.myShipmentsTitle,
                      style: const TextStyle(color: LightColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ),

              // SEARCH BAR
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: LightColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: t.companyShipmentsSearchHint,
                      hintStyle: const TextStyle(color: LightColors.textSecondary, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: LightColors.textSecondary, size: 20),
                      filled: true,
                      fillColor: LightColors.surface,
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
              ),

              // TABS
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _TabChip(label: t.filterAll, active: _tab == _ShipmentTab.all, onTap: () => setState(() => _tab = _ShipmentTab.all)),
                      const SizedBox(width: 8),
                      _TabChip(label: t.tabPendingLabel, active: _tab == _ShipmentTab.pending, onTap: () => setState(() => _tab = _ShipmentTab.pending)),
                      const SizedBox(width: 8),
                      _TabChip(label: t.tabLiveLabel, active: _tab == _ShipmentTab.live, onTap: () => setState(() => _tab = _ShipmentTab.live)),
                      const SizedBox(width: 8),
                      _TabChip(label: t.tabDeliveredLabel, active: _tab == _ShipmentTab.delivered, onTap: () => setState(() => _tab = _ShipmentTab.delivered)),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
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

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                      child: Column(
                        children: [
                          for (int i = 0; i < shipments.length; i++) ...[
                            if (i > 0) const SizedBox(height: 10),
                            _ShipmentTile(shipment: shipments[i]),
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
      ),
    );
  }
}

// ── States ───────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: CircularProgressIndicator(color: LightColors.gold),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
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
    );
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
          color: active ? LightColors.navy : LightColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: active ? LightColors.navy : LightColors.border),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12.5,
              color: active ? Colors.white : LightColors.textSecondary,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            )),
      ),
    );
  }
}

// ── ShipmentTile ─────────────────────────────────────────────────────────────

class _ShipmentTile extends StatelessWidget {
  final Shipment shipment;

  const _ShipmentTile({required this.shipment});

  // Live == In Transit / Out for Delivery / Delayed — the only statuses
  // where a map position actually exists to show.
  bool get _isLive => shipment.status == 1 || shipment.status == 2 || shipment.status == 5;

  Color get _color => switch (shipment.status) {
        0 => LightColors.pending,
        1 => LightColors.navy,
        2 => LightColors.goldMuted,
        3 => LightColors.success,
        4 => LightColors.error,
        5 => LightColors.error,
        _ => LightColors.textSecondary,
      };

  Color get _bg => switch (shipment.status) {
        0 => LightColors.pendingBg,
        3 => LightColors.successBg,
        4 => LightColors.errorBg,
        5 => LightColors.errorBg,
        _ => LightColors.gold.withOpacity(0.12),
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LightColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ShipmentDetailsPageCompany(shipment: shipment)),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: LightColors.border)),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10)),
                child: Icon(shipment.icon, color: _color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SH-${shipment.id}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: LightColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text('${shipment.origin} · ${shipment.destination}',
                        style: const TextStyle(fontSize: 11.5, color: LightColors.textSecondary),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(8)),
                    child: Text(statusLabel(shipment.status),
                        style: TextStyle(fontSize: 10, color: _color, fontWeight: FontWeight.w700)),
                  ),
                  if (shipment.weight.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(shipment.weight, style: const TextStyle(fontSize: 10, color: LightColors.textSecondary)),
                  ],
                ],
              ),
              if (_isLive) ...[
                const SizedBox(width: 4),
                Material(
                  color: LightColors.navy,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ShipmentTrackingPage(shipment: shipment, readOnly: true)),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.map_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
              const Icon(Icons.chevron_right_rounded, color: LightColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
