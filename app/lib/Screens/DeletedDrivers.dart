import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../API/DriverService.dart';
import '../API/config.dart';
import '../models/Appuser.dart';
import '../models/Driver.dart';
import 'AddDriverPage.dart';
import 'AppBarWidget.dart';
import 'DriverDetails.dart';

class Deleteddrivers extends StatefulWidget {
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
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.gold,
        child: const Icon(Icons.add, color: AppColors.bg),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddDriverPage()),
          );

          if (result != null) _refresh();
        },
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: AppColors.cream),
                  decoration: InputDecoration(
                    hintText: "Search by name...",
                    hintStyle: const TextStyle(color: AppColors.muted),
                    prefixIcon:
                    const Icon(Icons.search, color: AppColors.muted),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
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
                        child:
                        CircularProgressIndicator(color: AppColors.gold),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 60),
                      child: Column(
                        children: [
                          const Icon(Icons.cloud_off,
                              color: AppColors.error, size: 40),
                          const SizedBox(height: 10),
                          Text(snapshot.error.toString(),
                              textAlign: TextAlign.center,
                              style:
                              const TextStyle(color: AppColors.muted)),
                          TextButton(
                            onPressed: _refresh,
                            child: const Text("Retry",
                                style: TextStyle(color: AppColors.gold)),
                          )
                        ],
                      ),
                    );
                  }

                  final drivers =
                  _filterdata(snapshot.data ?? []);

                  if (drivers.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Text(
                          "No deleted drivers found",
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
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
          backgroundColor: Colors.green,
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
          backgroundColor: Colors.red,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.person,
              color: AppColors.cream,
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
                    color: AppColors.cream,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "ID: ${driver.id}",
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.goldMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  driver.email ?? '',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.bg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                driver.driver_license,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.muted,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined),
                    color: AppColors.info,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DriverDetailsPage(driver: driver),
                        ),
                      );
                    },
                  ),
                  _isRestoring
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : IconButton(
                    icon: const Icon(Icons.restore),
                    color: AppColors.success,
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