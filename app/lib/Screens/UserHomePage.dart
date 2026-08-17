import 'package:flutter/material.dart';

import '../API/ShipmentServices.dart';
import '../API/config.dart';
import '../models/Appuser.dart';
import '../models/Shipment.dart';
import 'ShipmentTrackingPage.dart';

/// Driver "My Shipments" — driver redesign Phase 3 (2026-08-17 mockup):
/// same screen as before (a plain shipment list), now with the mockup's
/// All/Active/Completed/Cancelled tabs. Class name/constructor kept
/// unchanged since DriverDashboardScreen's "View All" already pushes this
/// screen directly.
class UserHomePage extends StatefulWidget {
  final AppUser user;
  const UserHomePage({super.key, required this.user});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

enum _ShipmentTab { all, active, completed, cancelled }

class _UserHomePageState extends State<UserHomePage> {
  final _service = ShipmentService();

  late Future<List<Shipment>> _shipmentsFuture;
  _ShipmentTab _tab = _ShipmentTab.all;

  @override
  void initState() {
    super.initState();
    _shipmentsFuture = _service.fetchShipments();
  }

  void _refresh() => setState(() {
        _shipmentsFuture = _service.fetchShipments();
      });

  List<Shipment> _filter(List<Shipment> all, _ShipmentTab tab) {
    switch (tab) {
      case _ShipmentTab.all:
        return all;
      case _ShipmentTab.active:
        return all.where((s) => s.status == 0 || s.status == 1 || s.status == 2 || s.status == 5).toList();
      case _ShipmentTab.completed:
        return all.where((s) => s.status == 3).toList();
      case _ShipmentTab.cancelled:
        return all.where((s) => s.status == 4).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: LightColors.cream),
        title: const Text('My Shipments', style: TextStyle(color: LightColors.cream)),
      ),
      body: RefreshIndicator(
        color: LightColors.gold,
        onRefresh: () async => _refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: FutureBuilder<List<Shipment>>(
                future: _shipmentsFuture,
                builder: (context, snapshot) {
                  final all = snapshot.data ?? [];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _TabChip(
                            label: 'All (${all.length})',
                            active: _tab == _ShipmentTab.all,
                            onTap: () => setState(() => _tab = _ShipmentTab.all),
                          ),
                          const SizedBox(width: 8),
                          _TabChip(
                            label: 'Active (${_filter(all, _ShipmentTab.active).length})',
                            active: _tab == _ShipmentTab.active,
                            onTap: () => setState(() => _tab = _ShipmentTab.active),
                          ),
                          const SizedBox(width: 8),
                          _TabChip(
                            label: 'Completed (${_filter(all, _ShipmentTab.completed).length})',
                            active: _tab == _ShipmentTab.completed,
                            onTap: () => setState(() => _tab = _ShipmentTab.completed),
                          ),
                          const SizedBox(width: 8),
                          _TabChip(
                            label: 'Cancelled (${_filter(all, _ShipmentTab.cancelled).length})',
                            active: _tab == _ShipmentTab.cancelled,
                            onTap: () => setState(() => _tab = _ShipmentTab.cancelled),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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

                  final shipments = _filter(snapshot.data ?? [], _tab);

                  if (shipments.isEmpty) {
                    return const _EmptyState();
                  }

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      children: [
                        for (int i = 0; i < shipments.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          ShipmentItem(shipment: shipments[i]),
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
    );
  }
}

// ── Tabs ─────────────────────────────────────────────────────────────────────

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: LightColors.error,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Failed to load shipments',
            style: TextStyle(
              color: LightColors.cream,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: LightColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, color: LightColors.gold),
            label: const Text(
              'Retry',
              style: TextStyle(color: LightColors.gold),
            ),
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
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            color: LightColors.muted,
            size: 48,
          ),
          SizedBox(height: 16),
          Text(
            'No shipments here',
            style: TextStyle(
              color: LightColors.cream,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Shipments matching this filter will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: LightColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── ShipmentItem ─────────────────────────────────────────────────────────────

class ShipmentItem extends StatelessWidget {
  final Shipment shipment;

  const ShipmentItem({super.key, required this.shipment});

  Color get _color => switch (shipment.status) {
        0 => LightColors.gold,
        1 => LightColors.info,
        2 => LightColors.success,
        3 => LightColors.success,
        4 => LightColors.error,
        5 => LightColors.error,
        _ => LightColors.muted,
      };

  @override
  Widget build(BuildContext context) {
    final color = _color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: LightColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LightColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(shipment.icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),

          // ID + route
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SH-${shipment.id}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: LightColors.cream,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${shipment.origin} · ${shipment.destination}',
                  style:
                  const TextStyle(fontSize: 11, color: LightColors.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Status badge + time
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel(shipment.status),
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                shipment.weight,
                style:
                const TextStyle(fontSize: 10, color: LightColors.muted),
              ),
              IconButton(
                icon: const Icon(Icons.visibility_outlined),
                color: LightColors.gold,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShipmentTrackingPage(
                        shipment: shipment,
                      ),
                    ),
                  );
                },
              )
            ],
          ),
        ],
      ),
    );
  }
}
