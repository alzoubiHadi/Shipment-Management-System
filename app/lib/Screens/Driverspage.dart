import 'package:flutter/material.dart';
import '../API/DriverService.dart';
import '../API/config.dart';
import '../models/Appuser.dart';
import '../models/Driver.dart';
import 'AddDriverPage.dart';
import 'AppBarWidget.dart';
import 'DriverDetails.dart';

// ── Page ─────────────────────────────────────────────────────────────────────

class Driverspage extends StatefulWidget {
  final AppUser user;
  const Driverspage({super.key, required this.user});

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
  String _approvalFilter = 'all';

  @override
  void initState() {
    super.initState();
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
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async {
          _refresh();
          await _driverFuture;
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            AppBarWidget(
              user: widget.user,
              subtitle: 'Drivers',
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
                    padding: const EdgeInsets.only(left: 24, right: 24, bottom: 12),
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
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
            'Failed to load Drivers',
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
            'No drivers yet',
            style: TextStyle(color: AppColors.cream, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Your drivers will appear here once created.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
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
    final borderColor = highlight && !selected ? AppColors.gold : AppColors.border;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.bg : AppColors.cream,
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
                  driver.id.toString(),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.cream),
                ),
                const SizedBox(height: 2),
                Text(
                  driver.name ?? '',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                _ApprovalBadge(status: driver.approvalStatus),
                if (driver.documentIssues.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 12, color: AppColors.error),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          driver.documentIssues.join(', '),
                          style: const TextStyle(fontSize: 10, color: AppColors.error),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Status badge + License + Actions — width-capped so a long
          // email/license string can never squeeze the leading Expanded
          // name column down to near-zero (that squeeze is what made the
          // "Pending review" badge wrap one character per line).
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    driver.email ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.bg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  driver.driver_license ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DriverDetailsPage(driver: driver),
                        ),
                      );

                      if (result == true) {
                        onRefresh?.call();
                      }
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
                          builder: (_) => AddDriverPage(driver: driver),
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
                          title: const Text('Delete Driver', style: TextStyle(color: AppColors.cream)),
                          content: Text(
                            'Are you sure you want to delete ${driver.name}?',
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
                        await DriverService.deleteDriver(driver.id);
                        onRefresh?.call();
                      }
                    },
                  ),

                  // 4. APPROVE / REJECT — only shown for drivers still
                  // awaiting admin review (self-registered, not yet acted on)
                  if (driver.approvalStatus == 'pending') ...[
                    const SizedBox(width: 8),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.check_circle_outline, size: 20),
                      color: AppColors.success,
                      tooltip: 'Approve',
                      onPressed: () async {
                        final result = await DriverService.approveDriver(driver.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(result['message'] ?? '')),
                          );
                        }
                        if (result['success'] == true) {
                          onRefresh?.call();
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.cancel_outlined, size: 20),
                      color: AppColors.error,
                      tooltip: 'Reject',
                      onPressed: () async {
                        final reasonCtrl = TextEditingController();
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppColors.surface,
                            title: const Text('Reject Driver', style: TextStyle(color: AppColors.cream)),
                            content: TextField(
                              controller: reasonCtrl,
                              style: const TextStyle(color: AppColors.cream),
                              decoration: const InputDecoration(
                                hintText: 'Reason (optional)',
                                hintStyle: TextStyle(color: AppColors.muted),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Reject', style: TextStyle(color: AppColors.error)),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          await DriverService.rejectDriver(driver.id, reason: reasonCtrl.text.trim());
                          onRefresh?.call();
                        }
                      },
                    ),
                  ],
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

// ── Approval badge ───────────────────────────────────────────────────────────

class _ApprovalBadge extends StatelessWidget {
  final String status;
  const _ApprovalBadge({required this.status});

  Color get _color => switch (status) {
        'approved' => AppColors.success,
        'rejected' => AppColors.error,
        _ => AppColors.info,
      };

  String get _label => switch (status) {
        'approved' => 'Approved',
        'rejected' => 'Rejected',
        _ => 'Pending review',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withOpacity(0.4)),
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