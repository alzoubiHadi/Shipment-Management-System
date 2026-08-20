import 'package:flutter/material.dart';

import '../API/PlatformSettingService.dart';
import '../API/config.dart';

/// Super Admin only: platform-wide configuration screen (2026-08-27) —
/// profit margin, matching weights/timeout/batch size, and driver-ops
/// defaults. The backend (PlatformSettingController) has always supported
/// this via GET/PUT /platform-settings, but no Flutter screen ever called
/// it until now.
///
/// 2026-08-27 (security review): this was mislabeled as a Finance Admin
/// screen and reachable via 'permission:finance' — the backend now
/// restricts both endpoints to Super Admin only (see
/// PlatformSettingController::requireSuperAdmin()); this screen must only
/// ever be shown to a Super Admin (see AdminDrawer's routing).
class AdminPlatformSettingsPage extends StatefulWidget {
  const AdminPlatformSettingsPage({super.key});

  @override
  State<AdminPlatformSettingsPage> createState() => _AdminPlatformSettingsPageState();
}

class _SettingMeta {
  final String key;
  final String label;
  final String description;
  final String? suffix;
  const _SettingMeta(this.key, this.label, this.description, {this.suffix});
}

class _AdminPlatformSettingsPageState extends State<AdminPlatformSettingsPage> {
  final _service = PlatformSettingService();
  Map<String, String> _values = {};
  bool _loading = true;
  String? _error;

  static const _pricing = [
    _SettingMeta('profit_margin_percent', 'Profit Margin', 'Platform\'s cut of every priced offer (price to client minus price to driver).', suffix: '%'),
  ];

  static const _matching = [
    _SettingMeta('matching_response_timeout_minutes', 'Response Timeout', 'How long a batch of matched drivers has to respond before the next round.', suffix: 'min'),
    _SettingMeta('matching_batch_size', 'Batch Size', 'How many drivers are matched per round.'),
  ];

  static const _matchingWeights = [
    _SettingMeta('matching_weight_proximity', 'Proximity', 'How close the driver is to pickup.'),
    _SettingMeta('matching_weight_rating', 'Rating', 'Driver\'s historical rating.'),
    _SettingMeta('matching_weight_acceptance', 'Acceptance', 'Driver\'s historical acceptance rate.'),
    _SettingMeta('matching_weight_fairness', 'Fairness', 'Time since the driver\'s last job.'),
    _SettingMeta('matching_weight_route_experience', 'Route Experience', 'Driver\'s history on this exact zone lane (Smart Pricing Engine).'),
  ];

  static const _operations = [
    _SettingMeta('working_hours_alert_threshold_minutes', 'Working Hours Alert Threshold', 'Alerts admins when a driver approaches this many minutes on duty.', suffix: 'min'),
    _SettingMeta('rest_reset_minutes', 'Rest Reset Duration', 'Minutes of rest required before a driver\'s working-hours clock resets.', suffix: 'min'),
    _SettingMeta('default_driver_rating', 'Default Driver Rating', 'Starting rating assigned to a newly approved driver.'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await _service.fetchSettings();
      if (!mounted) return;
      setState(() {
        _values = {for (final s in settings) s.key: s.value};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load settings: $e';
        _loading = false;
      });
    }
  }

  Future<void> _edit(_SettingMeta meta) async {
    final controller = TextEditingController(text: _values[meta.key] ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LightColors.surface,
        title: Text(meta.label, style: const TextStyle(color: LightColors.textPrimary, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(meta.description, style: const TextStyle(color: LightColors.textSecondary, fontSize: 12.5)),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
              decoration: InputDecoration(labelText: 'Value', suffixText: meta.suffix),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty || double.tryParse(text) == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Enter a valid number'), backgroundColor: LightColors.error),
                );
                return;
              }
              Navigator.pop(ctx, text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) return;

    final response = await _service.updateSetting(key: meta.key, value: result);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response['message']?.toString() ?? ''),
        backgroundColor: response['success'] == true ? LightColors.success : LightColors.error,
      ),
    );

    if (response['success'] == true) {
      setState(() => _values[meta.key] = result);
    }
  }

  double get _weightSum {
    double sum = 0;
    for (final m in _matchingWeights) {
      sum += double.tryParse(_values[m.key] ?? '') ?? 0;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: LightColors.textPrimary),
        title: const Text('Platform Settings', style: TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(child: _body()),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: const TextStyle(color: LightColors.error), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final weightSum = _weightSum;
    final weightSumOk = (weightSum - 1.0).abs() < 0.01;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader('Pricing'),
          ..._pricing.map((m) => _settingTile(m)),
          const SizedBox(height: 20),
          _SectionHeader('Matching'),
          ..._matching.map((m) => _settingTile(m)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text('Matching Weights', style: TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (weightSumOk ? LightColors.success : LightColors.error).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Sum: ${(weightSum * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: weightSumOk ? LightColors.success : LightColors.error, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (!weightSumOk) ...[
            const SizedBox(height: 6),
            const Text('Weights should sum to 100% (1.0) — matching scores may not behave as expected otherwise.',
                style: TextStyle(color: LightColors.error, fontSize: 11.5)),
          ],
          const SizedBox(height: 8),
          ..._matchingWeights.map((m) => _settingTile(m)),
          const SizedBox(height: 20),
          _SectionHeader('Driver Operations'),
          ..._operations.map((m) => _settingTile(m)),
        ],
      ),
    );
  }

  Widget _settingTile(_SettingMeta meta) {
    final value = _values[meta.key];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: LightColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: LightColors.border)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meta.label, style: const TextStyle(color: LightColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(meta.description, style: const TextStyle(color: LightColors.textSecondary, fontSize: 11.5)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value != null ? '$value${meta.suffix ?? ''}' : '—',
            style: const TextStyle(color: LightColors.gold, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () => _edit(meta),
            icon: const Icon(Icons.edit_outlined, size: 18, color: LightColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: const TextStyle(color: LightColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
    );
  }
}
