import 'package:flutter/material.dart';

import '../API/CompanyService.dart';
import '../API/DriverService.dart';
import '../API/config.dart';
import '../models/Appuser.dart';
import '../models/Company.dart';
import '../models/Driver.dart';
import 'CompanyDetailsPage.dart';
import 'DriverDetails.dart';

/// Unified driver+company registration review queue (2026-08-21 mockup,
/// Phase 2 of the admin dashboard redesign). Lives as a bottom-nav tab
/// (see AdminBottomNav) rather than behind the drawer, since it's the
/// admin's primary daily workflow.
///
/// Merges DriverService.fetchDriver() + CompanyService.fetchCompaines()
/// client-side rather than adding a new backend endpoint — same pattern
/// Driverspage/Companiespage already use for their own lists.
///
/// Tapping a row currently opens the existing DriverDetailsPage/
/// CompanyDetailsPage (dark-themed, already supports approve/reject) as an
/// interim link. Phase 3 replaces this with the new light-themed tabbed
/// review + decision screens from the mockup.
enum _TypeTab { all, drivers, companies }

enum _StatusFilter { all, pending, changesRequired, rejected }

class RegistrationRequestsScreen extends StatefulWidget {
  final AppUser user;
  final VoidCallback onOpenDrawer;
  final String initialStatusFilter; // 'all' | 'pending' | 'changes_required' | 'rejected'
  final String initialTypeTab; // 'all' | 'drivers' | 'companies'

  const RegistrationRequestsScreen({
    super.key,
    required this.user,
    required this.onOpenDrawer,
    this.initialStatusFilter = 'all',
    this.initialTypeTab = 'all',
  });

  @override
  State<RegistrationRequestsScreen> createState() => _RegistrationRequestsScreenState();
}

class _RegistrationRequestsScreenState extends State<RegistrationRequestsScreen> {
  late Future<List<_UnifiedRequest>> _future;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _TypeTab _typeTab = _TypeTab.all;
  late _StatusFilter _statusFilter;

  @override
  void initState() {
    super.initState();
    _statusFilter = _statusFromString(widget.initialStatusFilter);
    _typeTab = switch (widget.initialTypeTab) {
      'drivers' => _TypeTab.drivers,
      'companies' => _TypeTab.companies,
      _ => _TypeTab.all,
    };
    _future = _load();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  static _StatusFilter _statusFromString(String s) {
    switch (s) {
      case 'pending':
        return _StatusFilter.pending;
      case 'changes_required':
        return _StatusFilter.changesRequired;
      case 'rejected':
        return _StatusFilter.rejected;
      default:
        return _StatusFilter.all;
    }
  }

  Future<List<_UnifiedRequest>> _load() async {
    final results = await Future.wait([
      DriverService().fetchDriver(),
      CompanyService().fetchCompaines(),
    ]);
    final drivers = results[0] as List<Driver>;
    final companies = results[1] as List<Company>;
    return [
      ...drivers.map((d) => _UnifiedRequest.driver(d)),
      ...companies.map((c) => _UnifiedRequest.company(c)),
    ];
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_UnifiedRequest> _applyFilters(List<_UnifiedRequest> all) {
    var result = all;
    if (_typeTab == _TypeTab.drivers) {
      result = result.where((r) => r.kind == RequestKind.driver).toList();
    } else if (_typeTab == _TypeTab.companies) {
      result = result.where((r) => r.kind == RequestKind.company).toList();
    }
    if (_statusFilter != _StatusFilter.all) {
      final wanted = switch (_statusFilter) {
        _StatusFilter.pending => 'pending',
        _StatusFilter.changesRequired => 'changes_required',
        _StatusFilter.rejected => 'rejected',
        _StatusFilter.all => '',
      };
      result = result.where((r) => r.status == wanted).toList();
    }
    if (_searchQuery.isNotEmpty) {
      result = result.where((r) {
        return r.name.toLowerCase().contains(_searchQuery) ||
            r.email.toLowerCase().contains(_searchQuery) ||
            r.phone.toLowerCase().contains(_searchQuery) ||
            r.code.toLowerCase().contains(_searchQuery);
      }).toList();
    }
    return result;
  }

  void _openDetails(_UnifiedRequest r) {
    if (r.kind == RequestKind.driver) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => DriverDetailsPage(driver: r.driver!)));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => CompanyDetailsPage(company: r.company!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LightColors.bg,
      child: SafeArea(
        child: FutureBuilder<List<_UnifiedRequest>>(
          future: _future,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState == ConnectionState.waiting;
            final all = snapshot.data ?? const [];
            final filtered = _applyFilters(all);

            final counts = {
              _StatusFilter.all: all.length,
              _StatusFilter.pending: all.where((r) => r.status == 'pending').length,
              _StatusFilter.changesRequired: all.where((r) => r.status == 'changes_required').length,
              _StatusFilter.rejected: all.where((r) => r.status == 'rejected').length,
            };

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: widget.onOpenDrawer,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.menu_rounded, color: LightColors.textPrimary, size: 26),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Registration Requests',
                          style: TextStyle(color: LightColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      IconButton(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded, color: LightColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: LightColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search by name, email, phone, ID...',
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _TypeTabButton(
                        label: 'All Requests',
                        active: _typeTab == _TypeTab.all,
                        onTap: () => setState(() => _typeTab = _TypeTab.all),
                      ),
                      const SizedBox(width: 20),
                      _TypeTabButton(
                        label: 'Drivers',
                        active: _typeTab == _TypeTab.drivers,
                        onTap: () => setState(() => _typeTab = _TypeTab.drivers),
                      ),
                      const SizedBox(width: 20),
                      _TypeTabButton(
                        label: 'Companies',
                        active: _typeTab == _TypeTab.companies,
                        onTap: () => setState(() => _typeTab = _TypeTab.companies),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _StatusChip(
                        label: 'All',
                        count: counts[_StatusFilter.all]!,
                        active: _statusFilter == _StatusFilter.all,
                        color: LightColors.navy,
                        onTap: () => setState(() => _statusFilter = _StatusFilter.all),
                      ),
                      const SizedBox(width: 8),
                      _StatusChip(
                        label: 'Pending',
                        count: counts[_StatusFilter.pending]!,
                        active: _statusFilter == _StatusFilter.pending,
                        color: LightColors.pending,
                        onTap: () => setState(() => _statusFilter = _StatusFilter.pending),
                      ),
                      const SizedBox(width: 8),
                      _StatusChip(
                        label: 'Changes Required',
                        count: counts[_StatusFilter.changesRequired]!,
                        active: _statusFilter == _StatusFilter.changesRequired,
                        color: LightColors.gold,
                        onTap: () => setState(() => _statusFilter = _StatusFilter.changesRequired),
                      ),
                      const SizedBox(width: 8),
                      _StatusChip(
                        label: 'Rejected',
                        count: counts[_StatusFilter.rejected]!,
                        active: _statusFilter == _StatusFilter.rejected,
                        color: LightColors.error,
                        onTap: () => setState(() => _statusFilter = _StatusFilter.rejected),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator(color: LightColors.gold))
                      : snapshot.hasError
                          ? Center(
                              child: Text('Could not load requests.\n${snapshot.error}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: LightColors.textSecondary)),
                            )
                          : RefreshIndicator(
                              color: LightColors.gold,
                              onRefresh: _refresh,
                              child: _buildList(filtered),
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(List<_UnifiedRequest> filtered) {
    if (filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(
              child: Text('No requests match this filter.', style: TextStyle(color: LightColors.textSecondary)),
            ),
          ),
        ],
      );
    }

    // Grouped by status, in review-priority order.
    const order = ['pending', 'changes_required', 'rejected', 'approved'];
    const labels = {
      'pending': 'Pending',
      'changes_required': 'Changes Required',
      'rejected': 'Rejected',
      'approved': 'Approved',
    };

    final groups = <String, List<_UnifiedRequest>>{};
    for (final status in order) {
      final items = filtered.where((r) => r.status == status).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
      if (items.isNotEmpty) groups[status] = items;
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      children: [
        for (final status in groups.keys) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text('${labels[status]} (${groups[status]!.length})',
                style: const TextStyle(color: LightColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          ...groups[status]!.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RequestTile(request: r, onTap: () => _openDetails(r)),
              )),
        ],
      ],
    );
  }
}

enum RequestKind { driver, company }

class _UnifiedRequest {
  final RequestKind kind;
  final Driver? driver;
  final Company? company;

  const _UnifiedRequest.driver(Driver d)
      : kind = RequestKind.driver,
        driver = d,
        company = null;

  const _UnifiedRequest.company(Company c)
      : kind = RequestKind.company,
        driver = null,
        company = c;

  String get id => kind == RequestKind.driver ? driver!.id : company!.id;
  String get name => kind == RequestKind.driver ? driver!.name : company!.name;
  String get email => kind == RequestKind.driver ? driver!.email : company!.email;
  String get phone => kind == RequestKind.driver ? driver!.phone : company!.phone;
  String get status => kind == RequestKind.driver ? driver!.approvalStatus : company!.approvalStatus;
  DateTime? get createdAt => kind == RequestKind.driver ? driver!.createdAt : company!.createdAt;
  String get typeLabel => kind == RequestKind.driver ? 'Driver Registration' : 'Company Registration';

  String get code {
    final prefix = kind == RequestKind.driver ? 'DR' : 'CO';
    final dt = createdAt ?? DateTime.now();
    final yy = (dt.year % 100).toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final idNum = int.tryParse(id) ?? 0;
    return '$prefix-$yy$mm-${idNum.toString().padLeft(4, '0')}';
  }

  String get appliedLabel {
    final dt = createdAt;
    if (dt == null) return '—';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

class _TypeTabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TypeTabButton({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                  fontSize: 14,
                  color: active ? LightColors.textPrimary : LightColors.textSecondary,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                )),
            const SizedBox(height: 4),
            Container(
              height: 2,
              width: 28,
              color: active ? LightColors.gold : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.count,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.12) : LightColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: active ? color : LightColors.border),
        ),
        child: Text('$label $count',
            style: TextStyle(
              fontSize: 12.5,
              color: active ? color : LightColors.textSecondary,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            )),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final _UnifiedRequest request;
  final VoidCallback onTap;

  const _RequestTile({required this.request, required this.onTap});

  Color get _statusColor => switch (request.status) {
        'pending' => LightColors.pending,
        'changes_required' => LightColors.gold,
        'rejected' => LightColors.error,
        'approved' => LightColors.success,
        _ => LightColors.textSecondary,
      };

  Color get _statusBg => switch (request.status) {
        'pending' => LightColors.pendingBg,
        'changes_required' => LightColors.gold.withOpacity(0.12),
        'rejected' => LightColors.errorBg,
        'approved' => LightColors.successBg,
        _ => LightColors.border,
      };

  String get _statusLabel => switch (request.status) {
        'pending' => 'PENDING',
        'changes_required' => 'CHANGES',
        'rejected' => 'REJECTED',
        'approved' => 'APPROVED',
        _ => request.status.toUpperCase(),
      };

  @override
  Widget build(BuildContext context) {
    final isDriver = request.kind == RequestKind.driver;
    return Material(
      color: LightColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: LightColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDriver ? LightColors.navy.withOpacity(0.08) : LightColors.gold.withOpacity(0.12),
                ),
                child: Icon(
                  isDriver ? Icons.person_outline : Icons.apartment_outlined,
                  color: isDriver ? LightColors.navy : LightColors.goldMuted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: LightColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('${request.typeLabel} · ${request.code}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: LightColors.textSecondary, fontSize: 11.5)),
                    Text(request.appliedLabel, style: const TextStyle(color: LightColors.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _statusBg, borderRadius: BorderRadius.circular(8)),
                child: Text(_statusLabel,
                    style: TextStyle(color: _statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
