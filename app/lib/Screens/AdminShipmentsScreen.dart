import 'dart:async';

import 'package:flutter/material.dart';

import '../API/AdminShipmentService.dart';
import '../API/config.dart';
import '../l10n/app_localizations.dart';
import '../models/AdminShipmentSummary.dart';
import '../models/Appuser.dart';
import 'AdminShipmentStatusStyle.dart';
import 'CancellationReportScreen.dart';
import 'LiveShipmentTrackingScreen.dart';
import 'MatchingStatusScreen.dart';
import 'TripReportScreen.dart';

/// Admin Shipments redesign (2026-08-24) — replaces Shipmentpageadmin as the
/// admin's main Shipments tab. Card-based list, filter chips, search — the
/// whole card is the tap target (no separate View/Manage icon buttons like
/// the old screen), and tapping routes by status: Pending -> Matching
/// Status, Active -> Live Tracking, Delivered -> Trip Report, Cancelled ->
/// Cancellation Report. See AdminShipmentController for the unified
/// offers+shipments feed backing this.
class AdminShipmentsScreen extends StatefulWidget {
  final AppUser user;
  const AdminShipmentsScreen({super.key, required this.user});

  @override
  State<AdminShipmentsScreen> createState() => _AdminShipmentsScreenState();
}

class _AdminShipmentsScreenState extends State<AdminShipmentsScreen> {
  List<(String, String)> _chips(AppLocalizations t) => [
        ('all', t.filterAll),
        ('active', t.adminShipmentsChipActive),
        ('pending', t.tabPendingLabel),
        ('delivered', t.adminShipmentsChipDelivered),
        ('cancelled', t.adminShipmentsChipCancelled),
      ];

  String _selectedGroup = 'all';
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  String? _error;
  List<AdminShipmentSummary> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AdminShipmentService.fetchShipments(
        group: _selectedGroup,
        search: _searchCtrl.text.trim(),
      );
      final list = (data['shipments'] as List? ?? [])
          .map((e) => AdminShipmentSummary.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  void _openDetail(AdminShipmentSummary item) {
    Widget screen;
    if (item.kind == 'offer' || item.statusGroup == 'pending') {
      screen = MatchingStatusScreen(trackingNumber: item.trackingNumber);
    } else {
      switch (item.statusGroup) {
        case 'delivered':
          screen = TripReportScreen(trackingNumber: item.trackingNumber);
          break;
        case 'cancelled':
          screen = CancellationReportScreen(trackingNumber: item.trackingNumber);
          break;
        case 'active':
        default:
          screen = LiveShipmentTrackingScreen(trackingNumber: item.trackingNumber);
      }
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final chips = _chips(t);
    return Scaffold(
      backgroundColor: LightColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(t.adminShipmentsTitle,
                      style: const TextStyle(color: LightColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded, color: LightColors.textSecondary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: LightColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: t.adminShipmentsSearchHint,
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
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: chips.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final (value, label) = chips[i];
                  final selected = _selectedGroup == value;
                  return ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _selectedGroup = value);
                      _load();
                    },
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
            Expanded(child: _buildBody(t)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations t) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: LightColors.navy));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: LightColors.error, size: 40),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: LightColors.textSecondary)),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: Text(t.commonRetry)),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(t.adminShipmentsNoneFound, style: const TextStyle(color: LightColors.textSecondary)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _ShipmentCard(item: _items[i], onTap: () => _openDetail(_items[i])),
      ),
    );
  }
}

class _ShipmentCard extends StatelessWidget {
  final AdminShipmentSummary item;
  final VoidCallback onTap;

  const _ShipmentCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return InkWell(
      onTap: onTap,
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
                  child: Text('#${item.trackingNumber}',
                      style: const TextStyle(color: LightColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                ),
                AdminStatusPill(label: item.statusLabel, statusGroup: item.statusGroup),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.circle, size: 6, color: LightColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${item.origin} → ${item.destination}',
                    style: const TextStyle(color: LightColors.textSecondary, fontSize: 12.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (item.companyName != null) ...[
              const SizedBox(height: 8),
              Text(item.companyName!, style: const TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
            if (item.driverName != null || item.truckLabel != null) ...[
              const SizedBox(height: 2),
              Text(
                [item.driverName, item.truckLabel].where((e) => e != null).join(' • '),
                style: const TextStyle(color: LightColors.textSecondary, fontSize: 12),
              ),
            ],
            if (item.statusGroup == 'active' && item.currentStage != null && item.totalStages != null) ...[
              const SizedBox(height: 10),
              _ProgressDots(current: item.currentStage!, total: item.totalStages!),
            ],
            if (item.statusGroup == 'pending') ...[
              const SizedBox(height: 6),
              Text(t.adminShipmentsWaitingForDriver, style: const TextStyle(color: LightColors.pending, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact "● ━ ● ━ ○" horizontal progress indicator for an active
/// shipment's card — full stage labels only appear on the detail screen's
/// vertical timeline, per the mockup's "cards show only decision-relevant
/// info" principle.
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
