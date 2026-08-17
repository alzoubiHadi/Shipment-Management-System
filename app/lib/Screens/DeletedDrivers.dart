import 'package:flutter/material.dart';
import '../API/DriverService.dart';
import '../API/config.dart';
import '../models/Driver.dart';
import 'AddDriverPage.dart';
import 'RequestReviewScreen.dart';

/// Admin Phase 1 (2026-08-20) redesign to LightColors — see Driverspage.dart
/// for the same View → RequestReviewScreen.driver() change.
class Deleteddrivers extends StatefulWidget {
  const Deleteddrivers({super.key});

  @override
  State<Deleteddrivers> createState() => _DriverspageState();
}

class _DriverspageState extends State<Deleteddrivers> {
  final _service = DriverService();

  late Future<List<Driver>> _driverFuture;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _driverFuture = _service.fetchDeletedDriver();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  void _refresh() => setState(() {
    _driverFuture = _service.fetchDeletedDriver();
  });

  List<Driver> _filterdata(List<Driver> list) {
    if (_searchQuery.isEmpty) return list;

    return list.where((s) {
      final name = (s.name ?? '').toLowerCase();
      return name.contains(_searchQuery);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: LightColors.textPrimary),
        title: const Text('Deleted Drivers', style: TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: LightColors.gold,
        child: const Icon(Icons.add, color: LightColors.textPrimary),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddDriverPage()),
          );

          if (result != null) _refresh();
        },
      ),
      body: RefreshIndicator(
        color: LightColors.gold,
        onRefresh: () async => _refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: LightColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Search by name...",
                    hintStyle: const TextStyle(color: LightColors.textSecondary, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: LightColors.textSecondary, size: 20),
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
            ),
            SliverToBoxAdapter(
              child: FutureBuilder<List<Driver>>(
                future: _driverFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(
                        child: CircularProgressIndicator(color: LightColors.gold),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
                      child: Column(
                        children: [
                          const Icon(Icons.cloud_off, color: LightColors.error, size: 40),
                          const SizedBox(height: 10),
                          Text(snapshot.error.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: LightColors.textSecondary)),
                          TextButton(
                            onPressed: _refresh,
                            child: const Text("Retry", style: TextStyle(color: LightColors.gold)),
                          )
                        ],
                      ),
                    );
                  }

                  final drivers = _filterdata(snapshot.data ?? []);

                  if (drivers.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Text(
                          "No deleted drivers found",
                          style: TextStyle(color: LightColors.textSecondary),
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Column(
                      children: [
                        for (final driver in drivers) ...[
                          DriverItem(
                            driver: driver,
                            onRestore: _refresh,
                          ),
                          const SizedBox(height: 10),
                        ]
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

class DriverItem extends StatefulWidget {
  final Driver driver;
  final VoidCallback onRestore;

  const DriverItem({
    super.key,
    required this.driver,
    required this.onRestore,
  });

  @override
  State<DriverItem> createState() => _DriverItemState();
}

class _DriverItemState extends State<DriverItem> {
  bool _isRestoring = false;

  Future<void> _restoreDriver() async {
    setState(() => _isRestoring = true);

    try {
      await DriverService.restoreDrivers(widget.driver.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Driver restored successfully"),
          backgroundColor: LightColors.success,
        ),
      );

      // Tell the parent (Deleteddrivers) to refresh its list now that
      // this driver has been restored and should disappear from it.
      widget.onRestore();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: LightColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRestoring = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final driver = widget.driver;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: LightColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LightColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: LightColors.navy.withOpacity(0.08),
            ),
            child: const Icon(
              Icons.person_outline,
              color: LightColors.navy,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver.name ?? '',
                  style: const TextStyle(
                    color: LightColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "ID: ${driver.id}",
                  style: const TextStyle(
                    color: LightColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                driver.email ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: LightColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                driver.driver_license,
                style: const TextStyle(
                  fontSize: 10,
                  color: LightColors.textSecondary,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined),
                    color: LightColors.navy,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RequestReviewScreen.driver(driver),
                        ),
                      );
                    },
                  ),
                  _isRestoring
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: LightColors.gold),
                  )
                      : IconButton(
                    icon: const Icon(Icons.restore),
                    color: LightColors.success,
                    onPressed: _restoreDriver,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
