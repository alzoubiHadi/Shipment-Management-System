import 'package:app/models/Company.dart';
import 'package:flutter/material.dart';
import '../API/CompanyService.dart';
import '../API/config.dart';
import '../models/Appuser.dart';
import 'AddCompanyPage.dart';
import 'RequestReviewScreen.dart';

// ── Page ─────────────────────────────────────────────────────────────────────

/// Admin Phase 2 (2026-08-20) redesign to LightColors — same treatment as
/// Driverspage.dart: "View" now opens RequestReviewScreen.company(company)
/// instead of the old dark CompanyDetailsPage, which also means Approve/
/// Reject/Request Changes are now reachable for a pending company directly
/// from this list (previously only inside CompanyDetailsPage itself).
class Companiespage extends StatefulWidget {
  final AppUser user;
  // Lets a caller (e.g. the admin drawer's "Registration Requests"
  // shortcut) land here pre-filtered to just 'pending' companies instead
  // of the full list. No visible filter-chip UI yet (unlike Driverspage) —
  // this is a silent initial filter for that one entry point.
  final String? initialApprovalFilter;
  const Companiespage({super.key, required this.user, this.initialApprovalFilter});

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
    var result = list;
    if (widget.initialApprovalFilter != null) {
      result = result.where((c) => c.approvalStatus == widget.initialApprovalFilter).toList();
    }
    if (_searchQuery.isEmpty) return result;

    return result.where((s) {
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
        title: const Text('Companies', style: TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, color: LightColors.textSecondary),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: LightColors.gold,
        child: const Icon(Icons.add, color: LightColors.textPrimary),
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
        color: LightColors.gold,
        onRefresh: () async {
          _refresh();
          await _companyFuture;
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // SEARCH BAR
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
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
        child: CircularProgressIndicator(color: LightColors.gold),
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
          const Icon(Icons.cloud_off_rounded, color: LightColors.error, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Failed to load companies',
            style: TextStyle(color: LightColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: LightColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, color: LightColors.gold),
            label: const Text('Retry', style: TextStyle(color: LightColors.gold)),
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
          Icon(Icons.inventory_2_outlined, color: LightColors.textSecondary, size: 48),
          SizedBox(height: 16),
          Text(
            'No companies yet',
            style: TextStyle(color: LightColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Your companies will appear here once created.',
            textAlign: TextAlign.center,
            style: TextStyle(color: LightColors.textSecondary, fontSize: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: LightColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LightColors.border),
      ),
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: LightColors.gold.withOpacity(0.12),
            ),
            child: const Icon(Icons.apartment_outlined, color: LightColors.goldMuted, size: 20),
          ),
          const SizedBox(width: 12),

          // ID + Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  company.name ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: LightColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'CO-${company.id}',
                  style: const TextStyle(fontSize: 11, color: LightColors.textSecondary),
                ),
                if (company.approvalStatus == 'pending') ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: LightColors.pendingBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Pending review',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 9, color: LightColors.pending, fontWeight: FontWeight.w600),
                    ),
                  ),
                ] else if (company.approvalStatus == 'rejected') ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: LightColors.errorBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Rejected',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 9, color: LightColors.error, fontWeight: FontWeight.w600),
                    ),
                  ),
                ] else if (company.approvalStatus == 'changes_required') ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: LightColors.gold.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Changes requested',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 9, color: LightColors.goldMuted, fontWeight: FontWeight.w600),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: LightColors.successBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Approved',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 9, color: LightColors.success, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Email + phone + Actions — width-capped, same fix as
          // DriverItem, so a long email can't squeeze the leading Expanded
          // name column and wrap the status badge one character per line.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  company.email ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: LightColors.textSecondary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  company.phone ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: LightColors.textSecondary),
                ),
                const SizedBox(height: 8),

              // Action Buttons Row
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. VIEW BUTTON — opens the shared light-themed review
                  // screen (Approve/Reject/Request Changes bar only shows
                  // for pending/changes_required companies).
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.visibility_outlined, size: 20),
                    color: LightColors.navy,
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RequestReviewScreen.company(company),
                        ),
                      );
                      if (result == true) onRefresh?.call();
                    },
                  ),
                  const SizedBox(width: 8),

                  // 2. EDIT BUTTON
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    color: LightColors.goldMuted,
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddCompanyPage(company: company),
                        ),
                      );

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
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: LightColors.error,
                    onPressed: () async {
                      bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: LightColors.surface,
                          title: const Text('Delete company', style: TextStyle(color: LightColors.textPrimary)),
                          content: Text(
                            'Are you sure you want to delete ${company.name}?',
                            style: const TextStyle(color: LightColors.textSecondary),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel', style: TextStyle(color: LightColors.textSecondary)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete', style: TextStyle(color: LightColors.error)),
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
          ),
        ],
      ),
    );
  }
}
