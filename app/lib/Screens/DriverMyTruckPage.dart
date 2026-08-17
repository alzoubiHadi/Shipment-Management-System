import 'package:flutter/material.dart';

import '../API/TruckService.dart';
import '../API/config.dart';
import '../models/Truck.dart';
import 'AddTruckPage.dart';
import 'DriverDocumentsPage.dart';

/// Driver redesign Phase 4 (2026-08-17 mockup): "My Truck" — a driver
/// registers with exactly one truck (server-enforced), so this is really a
/// single-truck detail view, kept as a list for robustness rather than
/// assuming that invariant never changes.
///
/// Scope note: the mockup shows "Model Year" — Truck has no such column on
/// either side of this app (only truck_type, not make/model/year), so it's
/// left out rather than faked. "Capacity" uses the real max_load column.
class DriverMyTruckPage extends StatefulWidget {
  const DriverMyTruckPage({super.key});

  @override
  State<DriverMyTruckPage> createState() => _DriverMyTruckPageState();
}

class _DriverMyTruckPageState extends State<DriverMyTruckPage> {
  late Future<List<Truck>> _trucksFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() => _trucksFuture = TruckService().fetchMyTrucks());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: LightColors.cream),
        title: const Text('My Truck', style: TextStyle(color: LightColors.cream)),
      ),
      body: RefreshIndicator(
        color: LightColors.gold,
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<Truck>>(
          future: _trucksFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: LightColors.gold));
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Could not load your truck', style: TextStyle(color: LightColors.error)));
            }

            final trucks = snapshot.data ?? [];

            if (trucks.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const SizedBox(height: 60),
                  const Icon(Icons.local_shipping_outlined, color: LightColors.muted, size: 48),
                  const SizedBox(height: 16),
                  const Text('No truck registered yet', textAlign: TextAlign.center, style: TextStyle(color: LightColors.cream, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text('Add your truck so you can be matched with shipments.',
                      textAlign: TextAlign.center, style: TextStyle(color: LightColors.muted, fontSize: 12.5)),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        final added = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AddTruckPage()));
                        if (added == true) _refresh();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: LightColors.gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Add Truck', style: TextStyle(color: LightColors.deepNavy, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: trucks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, i) => _TruckCard(truck: trucks[i]),
            );
          },
        ),
      ),
    );
  }
}

class _TruckCard extends StatelessWidget {
  final Truck truck;
  const _TruckCard({required this.truck});

  _ExpiryState _expiryState(DateTime? date) {
    if (date == null) return _ExpiryState('—', LightColors.muted);
    final daysLeft = date.difference(DateTime.now()).inDays;
    if (daysLeft < 0) return _ExpiryState('Expired', LightColors.error);
    if (daysLeft <= 30) return _ExpiryState('Expires Soon', LightColors.gold);
    return _ExpiryState('Valid', LightColors.success);
  }

  String _fmt(DateTime? d) => d == null ? '—' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: LightColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LightColors.border, width: 0.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: LightColors.gold.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.local_shipping_rounded, color: LightColors.gold, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(truck.truckNumber, style: const TextStyle(color: LightColors.cream, fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(truck.truckType, style: const TextStyle(color: LightColors.muted, fontSize: 12.5)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: (truck.isActive ? LightColors.success : LightColors.muted).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(truck.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(color: truck.isActive ? LightColors.success : LightColors.muted, fontSize: 10.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const Divider(height: 28, color: LightColors.border),
          _InfoRow('Capacity', truck.maxLoad != null ? '${truck.maxLoad!.toStringAsFixed(0)} kg' : '—'),
          _InfoRow('Refrigeration', truck.hasRefrigeration ? 'Yes' : 'No'),
          const SizedBox(height: 12),
          _ExpiryRow('Insurance', _fmt(truck.insuranceExpiry), _expiryState(truck.insuranceExpiry)),
          const SizedBox(height: 8),
          _ExpiryRow('Vehicle License', _fmt(truck.licenseExpiry), _expiryState(truck.licenseExpiry)),
          const SizedBox(height: 8),
          _ExpiryRow('Technical Inspection', _fmt(truck.technicalInspectionExpiry), _expiryState(truck.technicalInspectionExpiry)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverDocumentsPage(initialTab: DriverDocTab.truck))),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: LightColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('View Documents', style: TextStyle(color: LightColors.cream, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: LightColors.muted, fontSize: 12.5))),
          Text(value, style: const TextStyle(color: LightColors.cream, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ExpiryState {
  final String label;
  final Color color;
  _ExpiryState(this.label, this.color);
}

class _ExpiryRow extends StatelessWidget {
  final String label;
  final String date;
  final _ExpiryState state;
  const _ExpiryRow(this.label, this.date, this.state);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: LightColors.cream, fontSize: 13, fontWeight: FontWeight.w600)),
              Text(date, style: const TextStyle(color: LightColors.muted, fontSize: 11)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(color: state.color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Text(state.label, style: TextStyle(color: state.color, fontSize: 10.5, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
