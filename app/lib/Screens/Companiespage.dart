import 'package:app/models/Company.dart';
import 'package:flutter/material.dart';
import '../API/CompanyService.dart';
import '../API/DriverService.dart';
import '../API/config.dart';
import '../models/Appuser.dart';
import '../models/Driver.dart';
import 'AddCompanyPage.dart';
import 'AddDriverPage.dart';
import 'AppBarWidget.dart';
import 'CompanyDetailsPage.dart';
import 'DriverDetails.dart';

// ── Page ─────────────────────────────────────────────────────────────────────

class Companiespage extends StatefulWidget {
  final AppUser user;
  const Companiespage({super.key, required this.user});

  @override
  State<Companiespage> createState() => _CompaniespageState();
}

class _CompaniespageState extends State<Companiespage> {
  final _service = CompanyService();

  late Future<List<Company>> _companyFuture;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _companyFuture = _service.fetchCompaines();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  void _refresh() => setState(() {
    _companyFuture = _service.fetchCompaines();
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
            MaterialPageRoute(builder: (_) => const AddCompanyPage()),
          );

          if (result != null) {
            _refresh();
          }
        },
      ),
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async {
          _refresh();
          await _companyFuture;
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            AppBarWidget(
              user: widget.user,
              subtitle: 'Companies',
            ),

            // SEARCH BAR
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

            FutureBuilder<List<Company>>(
              future: _companyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const SliverToBoxAdapter(child: _LoadingState());
                }

                if (snapshot.hasError) {
                  return SliverToBoxAdapter(
                    child: _ErrorState(
                      message: snapshot.error.toString(),
                      onRetry: _refresh,
                    ),
                  );
                }

                final companies = _filterdata(snapshot.data ?? []);

                if (companies.isEmpty) {
                  return const SliverToBoxAdapter(child: _EmptyState());
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: index == companies.length - 1 ? 0 : 10),
                          child: CompanyItem(
                            company: companies[index],
                            onRefresh: _refresh,
                          ),
                        );
                      },
                      childCount: companies.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
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
        child: CircularProgressIndicator(color: AppColors.gold),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Failed to load companies',
            style: TextStyle(color: AppColors.cream, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.gold),
            label: const Text('Retry', style: TextStyle(color: AppColors.gold)),
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
          Icon(Icons.inventory_2_outlined, color: AppColors.muted, size: 48),
          SizedBox(height: 16),
          Text(
            'No companies yet',
            style: TextStyle(color: AppColors.cream, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Your companies will appear here once created.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Item ─────────────────────────────────────────────────────────────────────

class CompanyItem extends StatelessWidget {
  final Company company;
  final VoidCallback? onRefresh;

  const CompanyItem({super.key, required this.company, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.verified_user, color: AppColors.cream, size: 20),
          ),
          const SizedBox(width: 12),

          // ID + Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  company.id.toString(),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.cream),
                ),
                const SizedBox(height: 2),
                Text(
                  company.name ?? '',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  overflow: TextOverflow.ellipsis,
                ),
                if (company.approvalStatus == 'pending') ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Pending review',
                      style: TextStyle(fontSize: 9, color: AppColors.info, fontWeight: FontWeight.w600),
                    ),
                  ),
                ] else if (company.approvalStatus == 'rejected') ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Rejected',
                      style: TextStyle(fontSize: 9, color: AppColors.error, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Status badge + License + Actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  company.email ?? '',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.bg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                company.phone ?? '',
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
              const SizedBox(height: 8),

              // Action Buttons Row
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. VIEW BUTTON
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.visibility_outlined, size: 20),
                    color: AppColors.gold,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CompanyDetailsPage(company: company),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),

                  // 2. EDIT BUTTON (NEW)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    color: AppColors.info, // Blue color for edit
                    onPressed: () async {
                      // Navigate to AddDriverPage and pass the driver object for editing
                      // Note: Ensure AddDriverPage accepts an optional `Driver? driver` parameter
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddCompanyPage(company: company),
                        ),
                      );

                      // Refresh the list if we returned from the edit page
                      if (result != null) {
                        onRefresh?.call();
                      }
                    },
                  ),
                  const SizedBox(width: 8),

                  // 3. DELETE BUTTON
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.delete, size: 20),
                    color: AppColors.error,
                    onPressed: () async {
                      bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.surface,
                          title: const Text('Delete company', style: TextStyle(color: AppColors.cream)),
                          content: Text(
                            'Are you sure you want to delete ${company.name}?',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete', style: TextStyle(color: AppColors.error)),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await CompanyService.deleteCompany(company.id);
                        onRefresh?.call();
                      }
                    },
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

