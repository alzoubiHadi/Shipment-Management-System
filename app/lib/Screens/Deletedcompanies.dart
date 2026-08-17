import 'package:flutter/material.dart';
import '../API/CompanyService.dart';
import '../API/config.dart';
import '../models/Company.dart';
import 'AddCompanyPage.dart';
import 'RequestReviewScreen.dart';

/// Admin Phase 2 (2026-08-20) redesign to LightColors — same View →
/// RequestReviewScreen.company() change as Companiespage.dart.
///
/// Also fixed two pre-existing bugs found while touching this file:
/// the "+" FAB was pushing AddDriverPage instead of AddCompanyPage (a
/// copy-paste leftover per the old inline comment), and the phone line
/// under the email badge was printing company.email a second time instead
/// of company.phone.
class Deletedcompanies extends StatefulWidget {
  const Deletedcompanies({super.key});

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
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: LightColors.textPrimary),
        title: const Text('Deleted Companies', style: TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: LightColors.gold,
        child: const Icon(Icons.add, color: LightColors.textPrimary),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddCompanyPage()),
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
              child: FutureBuilder<List<Company>>(
                future: _companyFuture,
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

                  final companies = _filterdata(snapshot.data ?? []);

                  if (companies.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Text(
                          "No deleted companies found",
                          style: TextStyle(color: LightColors.textSecondary),
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
          backgroundColor: LightColors.success,
        ),
      );
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
      // ALWAYS refresh the list after the operation completes (success or fail)
      widget.onRestore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = widget.company;

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
              color: LightColors.gold.withOpacity(0.12),
            ),
            child: const Icon(
              Icons.business,
              color: LightColors.goldMuted,
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
                    color: LightColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "ID: ${company.id}",
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
                company.email,
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
                company.phone,
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
                          builder: (_) => RequestReviewScreen.company(company),
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
