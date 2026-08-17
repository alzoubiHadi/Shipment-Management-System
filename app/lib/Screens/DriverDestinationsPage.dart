import 'package:flutter/material.dart';

import '../API/DriverService.dart';
import '../API/config.dart';

/// UC-3/3.3: the country-level list of destinations a driver covers — feeds
/// the matching algorithm (UC-14). At least one is required.
class DriverDestinationsPage extends StatefulWidget {
  const DriverDestinationsPage({super.key});

  @override
  State<DriverDestinationsPage> createState() => _DriverDestinationsPageState();
}

class _DriverDestinationsPageState extends State<DriverDestinationsPage> {
  Map<String, String> _options = {};
  final Set<String> _selected = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

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
      final options = await DriverService.fetchDestinationOptions();
      final mine = await DriverService.fetchMyDestinations();
      if (!mounted) return;
      setState(() {
        _options = options;
        _selected
          ..clear()
          ..addAll(mine);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load destinations';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one destination')),
      );
      return;
    }

    setState(() => _saving = true);
    final result = await DriverService.syncMyDestinations(_selected.toList());
    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']?.toString() ?? '')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        title: const Text('My Destinations', style: TextStyle(color: LightColors.cream)),
        iconTheme: const IconThemeData(color: LightColors.cream),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: LightColors.gold))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: LightColors.error)))
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Pick every destination you can work on — this decides which shipment offers get matched to you.',
                              style: TextStyle(color: LightColors.muted, fontSize: 12),
                            ),
                          ),
                          ..._options.entries.map((entry) {
                            final selected = _selected.contains(entry.key);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: LightColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected ? LightColors.gold : LightColors.border,
                                  width: selected ? 1 : 0.5,
                                ),
                              ),
                              child: CheckboxListTile(
                                value: selected,
                                onChanged: (v) => setState(() {
                                  if (v == true) {
                                    _selected.add(entry.key);
                                  } else {
                                    _selected.remove(entry.key);
                                  }
                                }),
                                title: Text(entry.value, style: const TextStyle(color: LightColors.cream, fontSize: 14)),
                                activeColor: LightColors.gold,
                                controlAffinity: ListTileControlAffinity.leading,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(backgroundColor: LightColors.gold),
                          child: _saving
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: LightColors.deepNavy),
                                )
                              : const Text('Save', style: TextStyle(color: LightColors.deepNavy, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
