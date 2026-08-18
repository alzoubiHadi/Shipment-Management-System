import 'dart:async';

import 'package:flutter/material.dart';

import '../API/PriceListService.dart';
import '../API/config.dart';

/// Zones / Smart Pricing Engine (2026-08-27) — Admin "Market Adjustment"
/// screen (design doc points 12/32-33): Finance Admin reviews the ~700
/// historical zone-based lanes and may adjust each one's
/// market_adjustment_percent — the current operational opinion layered on
/// top of the historical reference price, which itself is never editable
/// here (only re-derived by re-running the underlying data import). Server
/// enforces the same rule (PriceListController::updateMarketAdjustment()
/// only ever accepts that one field).
class AdminZonePricingPage extends StatefulWidget {
  const AdminZonePricingPage({super.key});

  @override
  State<AdminZonePricingPage> createState() => _AdminZonePricingPageState();
}

class _AdminZonePricingPageState extends State<AdminZonePricingPage> {
  final _service = PriceListService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<ZoneLaneEntry> _entries = [];
  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.fetchZoneLanes(search: _searchController.text.trim(), page: page);
      if (!mounted) return;
      setState(() {
        _entries = result['entries'] as List<ZoneLaneEntry>;
        _page = result['currentPage'] as int;
        _lastPage = result['lastPage'] as int;
        _total = result['total'] as int;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load lanes: $e';
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load(page: 1));
  }

  Future<void> _editAdjustment(ZoneLaneEntry entry) async {
    final controller = TextEditingController(text: entry.marketAdjustmentPercent.toStringAsFixed(2));

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LightColors.surface,
        title: const Text('Market Adjustment', style: TextStyle(color: LightColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${entry.originLabel} → ${entry.destinationLabel}',
                style: const TextStyle(color: LightColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 2),
            Text(entry.truckType, style: const TextStyle(color: LightColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 14),
            Text(
              'Historical reference: ${entry.referencePrice != null ? 'AED ${entry.referencePrice!.toStringAsFixed(0)}' : '—'} (not editable)',
              style: const TextStyle(color: LightColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
              decoration: const InputDecoration(
                labelText: 'Adjustment (%)',
                hintText: 'e.g. 5 for +5%, -10 for -10%',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value == null || value < -100 || value > 100) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Enter a number between -100 and 100'), backgroundColor: LightColors.error),
                );
                return;
              }
              Navigator.pop(ctx, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) return;

    final response = await _service.updateMarketAdjustment(entryId: entry.id, marketAdjustmentPercent: result);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response['message']?.toString() ?? ''),
        backgroundColor: response['success'] == true ? LightColors.success : LightColors.error,
      ),
    );

    if (response['success'] == true) {
      final updated = response['entry'] as ZoneLaneEntry?;
      if (updated != null) {
        setState(() {
          final idx = _entries.indexWhere((e) => e.id == updated.id);
          if (idx != -1) _entries[idx] = updated;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: LightColors.textPrimary),
        title: const Text('Zone Pricing', style: TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: LightColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by zone, city, country, or truck type…',
                hintStyle: const TextStyle(color: LightColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: LightColors.textMuted, size: 20),
                filled: true,
                fillColor: LightColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LightColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LightColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LightColors.gold)),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('$_total lane${_total == 1 ? '' : 's'} · page $_page of $_lastPage',
                    style: const TextStyle(color: LightColors.textSecondary, fontSize: 12)),
              ),
            ),
          Expanded(child: _body()),
          if (!_loading && _lastPage > 1) _pager(),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: LightColors.gold));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: const TextStyle(color: LightColors.error), textAlign: TextAlign.center),
        ),
      );
    }
    if (_entries.isEmpty) {
      return const Center(child: Text('No lanes found', style: TextStyle(color: LightColors.textSecondary)));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _laneCard(_entries[i]),
    );
  }

  Widget _laneCard(ZoneLaneEntry entry) {
    final adjusted = entry.adjustedSuggestedPrice;
    final adjustmentPositive = entry.marketAdjustmentPercent > 0;
    final adjustmentZero = entry.marketAdjustmentPercent == 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: LightColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: LightColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text('${entry.originLabel} → ${entry.destinationLabel}',
                    style: const TextStyle(color: LightColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13.5)),
              ),
              if (entry.confidence != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: LightColors.gold.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text(entry.confidence!, style: const TextStyle(color: LightColors.goldMuted, fontSize: 10.5, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${entry.truckType}${entry.historicalTripCount != null ? ' · ${entry.historicalTripCount} past trips' : ''}',
            style: const TextStyle(color: LightColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _statColumn('Reference', entry.referencePrice != null ? 'AED ${entry.referencePrice!.toStringAsFixed(0)}' : '—'),
              ),
              Expanded(
                child: _statColumn(
                  'Adjustment',
                  '${adjustmentPositive ? '+' : ''}${entry.marketAdjustmentPercent.toStringAsFixed(1)}%',
                  color: adjustmentZero ? LightColors.textSecondary : (adjustmentPositive ? LightColors.success : LightColors.error),
                ),
              ),
              Expanded(
                child: _statColumn('Suggested Price', adjusted != null ? 'AED ${adjusted.toStringAsFixed(0)}' : '—', color: LightColors.gold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _editAdjustment(entry),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                side: const BorderSide(color: LightColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.tune, size: 15, color: LightColors.textPrimary),
              label: const Text('Adjust', style: TextStyle(color: LightColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statColumn(String label, String value, {Color color = LightColors.textPrimary}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: LightColors.textSecondary, fontSize: 10.5)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _pager() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _page > 1 ? () => _load(page: _page - 1) : null,
            icon: const Icon(Icons.chevron_left, color: LightColors.textPrimary),
          ),
          Text('$_page / $_lastPage', style: const TextStyle(color: LightColors.textSecondary, fontSize: 13)),
          IconButton(
            onPressed: _page < _lastPage ? () => _load(page: _page + 1) : null,
            icon: const Icon(Icons.chevron_right, color: LightColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
