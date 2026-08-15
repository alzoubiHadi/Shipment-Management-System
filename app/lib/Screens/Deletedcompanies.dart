import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../API/CompanyService.dart';
import '../API/config.dart';
import '../models/Company.dart';
import 'AddDriverPage.dart'; // Kept as AddDriverPage to match your original imports
import 'AppBarWidget.dart';
import 'CompanyDetailsPage.dart';

class Deletedcompanies extends StatefulWidget {
  @override
  State<Deletedcompanies> createState() => _CompaniespageState();
}

class _CompaniespageState extends State<Deletedcompanies> {
  final _service = CompanyService();
  late Future<List<Company>> _companyFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _companyFuture = _service.fetchCompainesdeleted();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  void _refresh() => setState(() {
    _companyFuture = _service.fetchCompainesdeleted();
  });

  List<Company> _filterdata(List<Company> list) {
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: AppColors.cream),
                  decoration: InputDecoration(
                    hintText: "Search by name...",
                    hintStyle: const TextStyle(color: AppColors.muted),
                    prefixIcon: const Icon(Icons.search, color: AppColors.muted),
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
              child: FutureBuilder<List<Company>>(
                future: _companyFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.gold),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
                      child: Column(
                        children: [
                          const Icon(Icons.cloud_off, color: AppColors.error, size: 40),
                          const SizedBox(height: 10),
                          Text(snapshot.error.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.muted)),
                          TextButton(
                            onPressed: _refresh,
                            child: const Text("Retry", style: TextStyle(color: AppColors.gold)),
                          )
                        ],
                      ),
                    );
                  }

                  final companies = _filterdata(snapshot.data ?? []);

                  if (companies.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Text(
                          "No deleted companies found",
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      children: [
                        for (final company in companies) ...[
                          CompanyItem(
                            company: company,
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

class CompanyItem extends StatefulWidget {
  final Company company;
  final VoidCallback onRestore;

  const CompanyItem({
    super.key,
    required this.company,
    required this.onRestore,
  });

  @override
  State<CompanyItem> createState() => _CompanyItemState();
}

class _CompanyItemState extends State<CompanyItem> {
  bool _isRestoring = false;

  Future<void> _restoreCompany() async {
    setState(() => _isRestoring = true);

    try {
      await CompanyService.restoreCompany(widget.company.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Company restored successfully"),
          backgroundColor: Colors.green,
        ),
      );
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
      // ALWAYS refresh the list after the operation completes (success or fail)
      widget.onRestore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = widget.company;

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
              Icons.business,
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
                  company.name ?? '',
                  style: const TextStyle(
                    color: AppColors.cream,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "ID: ${company.id}",
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
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  company.email, // Removed ?? '' to prevent compile error
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.bg, // Fixed invisible text (was gold on gold)
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                company.email,
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
                    color: AppColors.gold, // Used existing color to avoid errors
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CompanyDetailsPage(company: company),
                        ),
                      );
                    },
                  ),
                  _isRestoring
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                  )
                      : IconButton(
                    icon: const Icon(Icons.restore),
                    color: AppColors.gold, // Used existing color to avoid errors
                    onPressed: _restoreCompany,
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