import 'package:flutter/material.dart';
import '../API/DriverService.dart';
import '../API/config.dart';
import '../models/Appuser.dart';
import '../models/Driver.dart';
import 'DriverDetails.dart';
import 'RequestReviewScreen.dart';

/// Admin Phase 1 (2026-08-20) redesign to LightColors, matching the
/// Registration Requests / Request Review screens already redesigned in an
/// earlier phase.
///
/// Phase 2 (2026-08-22) nav rework: tapping anywhere on a driver card now
/// opens RequestReviewScreen.driver(driver) — the original registration/
/// review request in its final form, including the Approve/Reject/Request
/// Changes bar for drivers still pending/changes_required. Each card keeps
/// exactly three explicit actions: View Information (opens the read-only
/// DriverDetailsPage — all currently available driver/truck data, no
/// actions), Suspend/Reactivate (toggles compliance_status via the existing
/// backend endpoints, confirmed via dialog), and Delete. The old per-card
/// Edit/Approve/Reject icon buttons were removed — approval decisions now
/// live only inside RequestReviewScreen, and there is no dedicated edit
/// flow from this list anymore.
class Driverspage extends StatefulWidget {
  final AppUser user;
  // Lets a caller (e.g. the admin drawer's "Registration Requests" shortcut)
  // land here with a filter chip already selected instead of always
  // starting on 'all'.
  final String initialFilter;
  const Driverspage({super.key, required this.user, this.initialFilter = 'all'});

  @override
  State<Driverspage> createState() => _DriverspageState();
}

class _DriverspageState extends State<Driverspage> {
  final _service = DriverService();

  late Future<List<Driver>> _driverFuture;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // 'all' | 'pending' | 'approved' | 'rejected' — lets the admin quickly
  // isolate self-registered drivers awaiting review from everyone else.
  late String _approvalFilter;

  @override
  void initState() {
    super.initState();
    _approvalFilter = widget.initialFilter;
    _driverFuture = _service.fetchDriver();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  void _refresh() => setState(() {
    _driverFuture = _service.fetchDriver();
  });

  List<Driver> _filterdata(List<Driver> list) {
    var result = list;

    if (_approvalFilter != 'all') {
      result = result.where((d) => d.approvalStatus == _approvalFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      result = result.where((s) {
        final name = (s.name ?? '').toLowerCase();
        return name.contains(_searchQuery);
      }).toList();
    }

    return result;
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
        title: const Text('Drivers', style: TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, color: LightColors.textSecondary),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: LightColors.gold,
        onRefresh: () async {
          _refresh();
          await _driverFuture;
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

            FutureBuilder<List<Driver>>(
              future: _driverFuture,
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

                final allDrivers = snapshot.data ?? [];
                final pendingCount =
                    allDrivers.where((d) => d.approvalStatus == 'pending').length;

                final filterBar = SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          selected: _approvalFilter == 'all',
                          onTap: () => setState(() => _approvalFilter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: pendingCount > 0 ? 'Pending ($pendingCount)' : 'Pending',
                          selected: _approvalFilter == 'pending',
                          highlight: pendingCount > 0,
                          onTap: () => setState(() => _approvalFilter = 'pending'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Approved',
                          selected: _approvalFilter == 'approved',
                          onTap: () => setState(() => _approvalFilter = 'approved'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Rejected',
                          selected: _approvalFilter == 'rejected',
                          onTap: () => setState(() => _approvalFilter = 'rejected'),
                        ),
                      ],
                    ),
                  ),
                );

                final drivers = _filterdata(allDrivers);

                if (drivers.isEmpty) {
                  return SliverMainAxisGroup(
                    slivers: [
                      filterBar,
                      const SliverToBoxAdapter(child: _EmptyState()),
                    ],
                  );
                }

                return SliverMainAxisGroup(
                  slivers: [
                    filterBar,
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            return Padding(
                              padding: EdgeInsets.only(bottom: index == drivers.length - 1 ? 0 : 10),
                              child: DriverItem(
                                driver: drivers[index],
                                onRefresh: _refresh,
                              ),
                            );
                          },
                          childCount: drivers.length,
                        ),
                      ),
                    ),
                  ],
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
            'Failed to load Drivers',
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
            'No drivers yet',
            style: TextStyle(color: LightColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Your drivers will appear here once created.',
            textAlign: TextAlign.center,
            style: TextStyle(color: LightColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Filter chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool highlight;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = highlight && !selected ? LightColors.gold : LightColors.border;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? LightColors.gold : LightColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? LightColors.textPrimary : LightColors.textPrimary.withOpacity(0.85),
          ),
        ),
      ),
    );
  }
}

// ── Item ─────────────────────────────────────────────────────────────────────

class DriverItem extends StatelessWidget {
  final Driver driver;
  final VoidCallback? onRefresh;

  const DriverItem({super.key, required this.driver, this.onRefresh});

  bool get _isSuspended =>
      driver.complianceStatus == 'suspended' || driver.complianceStatus == 'banned';

  // Whole-card tap: opens the original registration/review request in its
  // final form. Approve/Reject/Request Changes live inside that screen and
  // only show themselves while status is 'pending'/'changes_required'.
  Future<void> _openReview(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RequestReviewScreen.driver(driver)),
    );
    if (result == true) onRefresh?.call();
  }

  // "View Information": a plain read-only page, all currently available
  // driver/truck data on one screen. No approve/reject/suspend actions
  // there — those are reached via _openReview or the buttons below.
  void _openInfo(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DriverDetailsPage(driver: driver)),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LightColors.surface,
        title: const Text('Delete Driver', style: TextStyle(color: LightColors.textPrimary)),
        content: Text(
          'Are you sure you want to delete ${driver.name}?',
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
      await DriverService.deleteDriver(driver.id);
      onRefresh?.call();
    }
  }

  // Super Admin freezes a driver directly (compliance_status='suspended'),
  // same DriverService.suspendDriver(id, reason) endpoint the old
  // DriverDetailsPage action bar used — a reason is required server-side.
  Future<void> _suspend(BuildContext context) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: LightColors.surface,
          title: const Text('Suspend Driver', style: TextStyle(color: LightColors.textPrimary)),
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

    final result = await DriverService.suspendDriver(driver.id, reasonCtrl.text.trim());
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
        title: const Text('Reactivate Driver', style: TextStyle(color: LightColors.textPrimary)),
        content: Text(
          'Reactivate ${driver.name}? They will become available for matching again.',
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

    final result = await DriverService.reactivateDriver(driver.id);
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
                      color: LightColors.navy.withOpacity(0.08),
                    ),
                    child: const Icon(Icons.person_outline, color: LightColors.navy, size: 20),
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
                                driver.name ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: LightColors.textPrimary),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _ApprovalBadge(status: driver.approvalStatus),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'DR-${driver.id}',
                          style: const TextStyle(fontSize: 11, color: LightColors.textSecondary),
                        ),
                        if (driver.documentIssues.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 12, color: LightColors.error),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  driver.documentIssues.join(', '),
                                  style: const TextStyle(fontSize: 10, color: LightColors.error),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
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

// ── Approval badge ───────────────────────────────────────────────────────────

class _ApprovalBadge extends StatelessWidget {
  final String status;
  const _ApprovalBadge({required this.status});

  Color get _color => switch (status) {
        'approved' => LightColors.success,
        'rejected' => LightColors.error,
        'changes_required' => LightColors.goldMuted,
        _ => LightColors.pending,
      };

  Color get _bg => switch (status) {
        'approved' => LightColors.successBg,
        'rejected' => LightColors.errorBg,
        'changes_required' => LightColors.gold.withOpacity(0.14),
        _ => LightColors.pendingBg,
      };

  String get _label => switch (status) {
        'approved' => 'Approved',
        'rejected' => 'Rejected',
        'changes_required' => 'Changes requested',
        _ => 'Pending review',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 9, color: _color, fontWeight: FontWeight.w600),
      ),
    );
  }
}