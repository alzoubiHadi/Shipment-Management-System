import 'package:app/models/Company.dart';
import 'package:flutter/material.dart';
import '../API/CompanyService.dart';
import '../API/config.dart';
import '../models/Appuser.dart';
import 'AddCompanyPage.dart';
import 'CompanyDetailsPage.dart';
import 'RequestReviewScreen.dart';

// ── Page ─────────────────────────────────────────────────────────────────────

/// Admin Phase 2 (2026-08-20) redesign to LightColors — same treatment as
/// Driverspage.dart.
///
/// Phase 3 (2026-08-22) nav rework, mirroring the Drivers list: tapping
/// anywhere on a company card opens RequestReviewScreen.company(company) —
/// the original registration/request review screen, including the
/// Approve/Reject/Request Changes bar when the workflow allows it. Each
/// card keeps exactly three explicit actions: View Information (opens the
/// read-only CompanyDetailsPage — all currently available company data, no
/// editing controls), Suspend/Reactivate (toggles account_status via the
/// existing backend endpoints, confirmed via dialog), and Delete. The old
/// per-card Edit icon button was removed — there is no dedicated edit flow
/// from this list anymore.
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

  bool get _isSuspended => company.accountStatus == 'suspended';

  // Whole-card tap: opens the original registration/review request in its
  // final form. Approve/Reject/Request Changes live inside that screen and
  // only show themselves while the workflow allows it.
  Future<void> _openReview(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RequestReviewScreen.company(company)),
    );
    if (result == true) onRefresh?.call();
  }

  // "View Information": a plain read-only page, all currently available
  // company data on one screen. No approve/reject/suspend actions there —
  // those are reached via _openReview or the buttons below.
  void _openInfo(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CompanyDetailsPage(company: company)),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LightColors.surface,
        title: const Text('Delete Company', style: TextStyle(color: LightColors.textPrimary)),
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
  }

  // UC-27: Super Admin temporarily suspends a company account — same
  // CompanyService.suspendCompany(companyId, reason) endpoint the old
  // CompanyDetailsPage action bar used; a reason is required server-side.
  Future<void> _suspend(BuildContext context) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: LightColors.surface,
          title: const Text('Suspend Company', style: TextStyle(color: LightColors.textPrimary)),
          content: TextField(
            controller: reasonCtrl,
            onChanged: (_) => setDialogState(() {}),
            style: const TextStyle(color: LightColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Reason (required)',
              hintStyle: TextStyle(color: LightColors.textSecondary),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: LightColors.textSecondary)),
            ),
            TextButton(
              onPressed: reasonCtrl.text.trim().isEmpty ? null : () => Navigator.pop(ctx, true),
              child: const Text('Suspend', style: TextStyle(color: LightColors.error)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || reasonCtrl.text.trim().isEmpty) return;

    final result = await CompanyService.suspendCompany(
      companyId: company.id,
      reason: reasonCtrl.text.trim(),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? '')),
      );
    }
    if (result['success'] == true) onRefresh?.call();
  }

  Future<void> _reactivate(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LightColors.surface,
        title: const Text('Reactivate Company', style: TextStyle(color: LightColors.textPrimary)),
        content: Text(
          'Reactivate ${company.name}? Their account will become active again.',
          style: const TextStyle(color: LightColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: LightColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reactivate', style: TextStyle(color: LightColors.success)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await CompanyService.activateCompany(company.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? '')),
      );
    }
    if (result['success'] == true) onRefresh?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LightColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openReview(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: LightColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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

                  // Name + code + status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                company.name ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: LightColors.textPrimary),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _CompanyStatusBadge(company: company),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'CO-${company.id}',
                          style: const TextStyle(fontSize: 11, color: LightColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: LightColors.textSecondary, size: 20),
                ],
              ),
              const SizedBox(height: 12),

              // Exactly three actions: View Information, Suspend/Reactivate, Delete.
              Row(
                children: [
                  Expanded(
                    child: _CardAction(
                      icon: Icons.visibility_outlined,
                      label: 'Information',
                      color: LightColors.navy,
                      onTap: () => _openInfo(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _isSuspended
                        ? _CardAction(
                            icon: Icons.play_circle_outline,
                            label: 'Reactivate',
                            color: LightColors.success,
                            onTap: () => _reactivate(context),
                          )
                        : _CardAction(
                            icon: Icons.pause_circle_outline,
                            label: 'Suspend',
                            color: LightColors.goldMuted,
                            onTap: () => _suspend(context),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CardAction(
                      icon: Icons.delete_outline,
                      label: 'Delete',
                      color: LightColors.error,
                      onTap: () => _delete(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Card action chip ─────────────────────────────────────────────────────────

class _CardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CardAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Status badge ─────────────────────────────────────────────────────────────

/// Mirrors the approval-status states already shown here, plus the
/// account_status='suspended' case (which approval_status alone doesn't
/// capture) — same states CompanyDetailsPage's badges already cover.
class _CompanyStatusBadge extends StatelessWidget {
  final Company company;
  const _CompanyStatusBadge({required this.company});

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final Color bg;
    late final String label;

    if (company.accountStatus == 'suspended') {
      color = LightColors.error;
      bg = LightColors.errorBg;
      label = 'Suspended';
    } else {
      switch (company.approvalStatus) {
        case 'pending':
          color = LightColors.pending;
          bg = LightColors.pendingBg;
          label = 'Pending review';
          break;
        case 'rejected':
          color = LightColors.error;
          bg = LightColors.errorBg;
          label = 'Rejected';
          break;
        case 'changes_required':
          color = LightColors.goldMuted;
          bg = LightColors.gold.withOpacity(0.14);
          label = 'Changes requested';
          break;
        default:
          color = LightColors.success;
          bg = LightColors.successBg;
          label = 'Approved';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
