import 'package:flutter/material.dart';

import '../API/CompanyService.dart';
import '../API/DriverService.dart';
import '../API/ProfileService.dart';
import '../API/config.dart';
import '../models/Appuser.dart';
import '../models/Company.dart';
import '../models/Driver.dart';
import '../models/ProfileEditRequest.dart';
import 'DocumentRenewalReviewScreen.dart';
import 'RequestReviewScreen.dart';

/// Unified Approvals screen (2026-08-22 redesign) — the admin's single home
/// for everything awaiting a decision, replacing RegistrationRequestsScreen
/// (left in place as dead code — see its docblock) as admin bottom-nav tab
/// index 1.
///
/// Three sections per spec:
///  - New Registrations: first-time driver/company sign-ups
///    (Driver/Company.approval_status == 'pending') — unchanged behavior
///    from the old Registration Requests screen.
///  - Document Renewals: a driver/truck/company document re-uploaded after
///    expiring or nearing expiry (ProfileEditRequest categories 'document',
///    'truck_document', 'company_license', status 'pending'). See
///    ProfileController::adminIndex()/approve()/reject() on the backend.
///  - Changes Required: registrations the admin previously reviewed and
///    sent back for an edit (Driver/Company.approval_status ==
///    'changes_required') — same data source as New Registrations, just a
///    different status filter.
///
/// Deliberately does NOT include "Expiring Soon" documents — per spec those
/// only produce a dashboard alert/notification (AdminDashboardController::
/// documentAlerts) until the owner actually uploads a renewal, at which
/// point they appear here under Document Renewals.
///
/// 2026-08-28: added a 4th section, Work Destinations (ProfileEditRequest
/// category 'destinations' — a driver changing which countries they cover).
/// This used to live on its own drawer page (AdminProfileEditRequestsPage,
/// now removed) separate from every other approval queue; folded in here so
/// admins have one single home for everything awaiting a decision, same
/// gating (finance permission) as before.
enum ApprovalSection { registrations, renewals, changes, destinations }

class ApprovalsPage extends StatefulWidget {
  final AppUser user;
  final VoidCallback onOpenDrawer;
  final ApprovalSection initialSection;

  const ApprovalsPage({
    super.key,
    required this.user,
    required this.onOpenDrawer,
    this.initialSection = ApprovalSection.registrations,
  });

  @override
  State<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends State<ApprovalsPage> {
  final _profileService = ProfileService();
  late ApprovalSection _section;
  late Future<List<_RegistrationItem>> _registrationsFuture;
  late Future<List<ProfileEditRequest>> _renewalsFuture;
  late Future<List<ProfileEditRequest>> _destinationsFuture;
  bool _destinationsBusy = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Document Renewals covers 3 categories, each now gated to a specific
  // permission on the backend (document->trainer, truck_document->
  // technical_check, company_license->finance — see ProfileController::
  // reviewPermissionFor()). An admin with none of those three (e.g.
  // crm-only) would just get a 403 hitting adminIndex(), so this tab is
  // hidden entirely for them instead of showing a permanent error.
  bool get _canReviewRenewals =>
      widget.user.hasPermission('finance') ||
      widget.user.hasPermission('trainer') ||
      widget.user.hasPermission('technical_check');

  // Work Destinations ('destinations' category) stayed gated to 'finance'
  // only, same as the old AdminProfileEditRequestsPage/AdminDrawer's
  // _canReviewFinanceRequests — see ProfileController::reviewPermissionFor().
  bool get _canReviewDestinations => widget.user.hasPermission('finance');

  @override
  void initState() {
    super.initState();
    _section = switch (widget.initialSection) {
      ApprovalSection.renewals when !_canReviewRenewals => ApprovalSection.registrations,
      ApprovalSection.destinations when !_canReviewDestinations => ApprovalSection.registrations,
      final s => s,
    };
    _registrationsFuture = _loadRegistrations();
    _renewalsFuture = _loadRenewals();
    _destinationsFuture = _loadDestinations();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  Future<List<_RegistrationItem>> _loadRegistrations() async {
    final results = await Future.wait([
      DriverService().fetchDriver(),
      CompanyService().fetchCompaines(),
    ]);
    final drivers = results[0] as List<Driver>;
    final companies = results[1] as List<Company>;
    return [
      ...drivers.map((d) => _RegistrationItem.driver(d)),
      ...companies.map((c) => _RegistrationItem.company(c)),
    ];
  }

  Future<List<ProfileEditRequest>> _loadRenewals() {
    if (!_canReviewRenewals) return Future.value(const <ProfileEditRequest>[]);
    return _profileService.fetchEditRequests(category: 'document,truck_document,company_license');
  }

  Future<List<ProfileEditRequest>> _loadDestinations() {
    if (!_canReviewDestinations) return Future.value(const <ProfileEditRequest>[]);
    return _profileService.fetchEditRequests(category: 'destinations');
  }

  Future<void> _refreshAll() async {
    setState(() {
      _registrationsFuture = _loadRegistrations();
      _renewalsFuture = _loadRenewals();
      _destinationsFuture = _loadDestinations();
    });
    await Future.wait([_registrationsFuture, _renewalsFuture, _destinationsFuture]);
  }

  Future<void> _approveDestination(ProfileEditRequest r) async {
    setState(() => _destinationsBusy = true);
    final result = await _profileService.approveEditRequest(r.id);
    if (!mounted) return;
    setState(() => _destinationsBusy = false);
    if (result['success'] == true) {
      setState(() => _destinationsFuture = _loadDestinations());
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']?.toString() ?? '')),
    );
  }

  Future<void> _rejectDestination(ProfileEditRequest r) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LightColors.surface,
        title: const Text('Reject request', style: TextStyle(color: LightColors.textPrimary)),
        content: TextField(
          controller: reasonCtrl,
          style: const TextStyle(color: LightColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Reason (optional)',
            hintStyle: TextStyle(color: LightColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: LightColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject', style: TextStyle(color: LightColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _destinationsBusy = true);
    final result = await _profileService.rejectEditRequest(r.id, reason: reasonCtrl.text.trim());
    if (!mounted) return;
    setState(() => _destinationsBusy = false);
    if (result['success'] == true) {
      setState(() => _destinationsFuture = _loadDestinations());
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']?.toString() ?? '')),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openRegistration(_RegistrationItem r) async {
    final screen = r.kind == _RegKind.driver
        ? RequestReviewScreen.driver(r.driver!)
        : RequestReviewScreen.company(r.company!);
    final decided = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => screen));
    if (decided == true) _refreshAll();
  }

  Future<void> _openRenewal(ProfileEditRequest r) async {
    final decided = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DocumentRenewalReviewScreen(request: r)),
    );
    if (decided == true) _refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LightColors.bg,
      child: SafeArea(
        child: Column(
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
                  const Text('Approvals',
                      style: TextStyle(color: LightColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    onPressed: _refreshAll,
                    icon: const Icon(Icons.refresh_rounded, color: LightColors.textSecondary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: FutureBuilder<List<_RegistrationItem>>(
                      future: _registrationsFuture,
                      builder: (context, snap) {
                        final count = (snap.data ?? const []).where((r) => r.status == 'pending').length;
                        return _SectionTabButton(
                          // 2026-08-28: shortened from "New\nRegistrations"
                          // per user request — kept the trailing newline
                          // (renders as a blank second line) so this chip
                          // stays the same height as its two-line neighbors
                          // ("Document\nRenewals" etc.) in the row.
                          label: 'New\n',
                          count: count,
                          active: _section == ApprovalSection.registrations,
                          onTap: () => setState(() => _section = ApprovalSection.registrations),
                        );
                      },
                    ),
                  ),
                  if (_canReviewRenewals) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: FutureBuilder<List<ProfileEditRequest>>(
                        future: _renewalsFuture,
                        builder: (context, snap) {
                          final count = (snap.data ?? const []).length;
                          return _SectionTabButton(
                            label: 'Document\nRenewals',
                            count: count,
                            active: _section == ApprovalSection.renewals,
                            onTap: () => setState(() => _section = ApprovalSection.renewals),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Expanded(
                    child: FutureBuilder<List<_RegistrationItem>>(
                      future: _registrationsFuture,
                      builder: (context, snap) {
                        final count = (snap.data ?? const []).where((r) => r.status == 'changes_required').length;
                        return _SectionTabButton(
                          label: 'Changes\nRequired',
                          count: count,
                          active: _section == ApprovalSection.changes,
                          onTap: () => setState(() => _section = ApprovalSection.changes),
                        );
                      },
                    ),
                  ),
                  if (_canReviewDestinations) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: FutureBuilder<List<ProfileEditRequest>>(
                        future: _destinationsFuture,
                        builder: (context, snap) {
                          final count = (snap.data ?? const []).length;
                          return _SectionTabButton(
                            label: 'Work\nDestinations',
                            count: count,
                            active: _section == ApprovalSection.destinations,
                            onTap: () => setState(() => _section = ApprovalSection.destinations),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: LightColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by name, email, phone...',
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
            const SizedBox(height: 4),
            Expanded(
              child: switch (_section) {
                ApprovalSection.registrations => _RegistrationsList(
                    future: _registrationsFuture,
                    statusFilter: 'pending',
                    emptyMessage: 'No new registrations awaiting review.',
                    searchQuery: _searchQuery,
                    onRefresh: _refreshAll,
                    onTap: _openRegistration,
                  ),
                ApprovalSection.changes => _RegistrationsList(
                    future: _registrationsFuture,
                    statusFilter: 'changes_required',
                    emptyMessage: 'No accounts currently need changes.',
                    searchQuery: _searchQuery,
                    onRefresh: _refreshAll,
                    onTap: _openRegistration,
                  ),
                ApprovalSection.renewals => _RenewalsList(
                    future: _renewalsFuture,
                    searchQuery: _searchQuery,
                    onRefresh: _refreshAll,
                    onTap: _openRenewal,
                  ),
                ApprovalSection.destinations => _DestinationsList(
                    future: _destinationsFuture,
                    searchQuery: _searchQuery,
                    busy: _destinationsBusy,
                    onRefresh: _refreshAll,
                    onApprove: _approveDestination,
                    onReject: _rejectDestination,
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTabButton extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _SectionTabButton({required this.label, required this.count, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? LightColors.gold.withOpacity(0.12) : LightColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? LightColors.gold : LightColors.border),
          ),
          child: Column(
            children: [
              Text('$count',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: active ? LightColors.goldMuted : LightColors.textPrimary,
                  )),
              const SizedBox(height: 2),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? LightColors.goldMuted : LightColors.textSecondary,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

enum _RegKind { driver, company }

class _RegistrationItem {
  final _RegKind kind;
  final Driver? driver;
  final Company? company;

  const _RegistrationItem.driver(Driver d)
      : kind = _RegKind.driver,
        driver = d,
        company = null;

  const _RegistrationItem.company(Company c)
      : kind = _RegKind.company,
        driver = null,
        company = c;

  String get id => kind == _RegKind.driver ? driver!.id : company!.id;
  String get name => kind == _RegKind.driver ? driver!.name : company!.name;
  String get email => kind == _RegKind.driver ? driver!.email : company!.email;
  String get phone => kind == _RegKind.driver ? driver!.phone : company!.phone;
  String get status => kind == _RegKind.driver ? driver!.approvalStatus : company!.approvalStatus;
  DateTime? get createdAt => kind == _RegKind.driver ? driver!.createdAt : company!.createdAt;
  String get typeLabel => kind == _RegKind.driver ? 'Driver' : 'Company';
}

class _RegistrationsList extends StatelessWidget {
  final Future<List<_RegistrationItem>> future;
  final String statusFilter;
  final String emptyMessage;
  final String searchQuery;
  final Future<void> Function() onRefresh;
  final void Function(_RegistrationItem) onTap;

  const _RegistrationsList({
    required this.future,
    required this.statusFilter,
    required this.emptyMessage,
    required this.searchQuery,
    required this.onRefresh,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_RegistrationItem>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: LightColors.gold));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Could not load requests.\n${snapshot.error}',
                textAlign: TextAlign.center, style: const TextStyle(color: LightColors.textSecondary)),
          );
        }

        var items = (snapshot.data ?? const []).where((r) => r.status == statusFilter).toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));

        if (searchQuery.isNotEmpty) {
          items = items.where((r) {
            return r.name.toLowerCase().contains(searchQuery) ||
                r.email.toLowerCase().contains(searchQuery) ||
                r.phone.toLowerCase().contains(searchQuery);
          }).toList();
        }

        if (items.isEmpty) {
          return RefreshIndicator(
            color: LightColors.gold,
            onRefresh: onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: Center(child: Text(emptyMessage, style: const TextStyle(color: LightColors.textSecondary))),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: LightColors.gold,
          onRefresh: onRefresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _RegistrationTile(item: items[i], onTap: () => onTap(items[i])),
          ),
        );
      },
    );
  }
}

class _RegistrationTile extends StatelessWidget {
  final _RegistrationItem item;
  final VoidCallback onTap;

  const _RegistrationTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDriver = item.kind == _RegKind.driver;
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
                    Text(item.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: LightColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('${item.typeLabel} · ${item.email}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: LightColors.textSecondary, fontSize: 11.5)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: LightColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _RenewalsList extends StatelessWidget {
  final Future<List<ProfileEditRequest>> future;
  final String searchQuery;
  final Future<void> Function() onRefresh;
  final void Function(ProfileEditRequest) onTap;

  const _RenewalsList({required this.future, required this.searchQuery, required this.onRefresh, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProfileEditRequest>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: LightColors.gold));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Could not load renewals.\n${snapshot.error}',
                textAlign: TextAlign.center, style: const TextStyle(color: LightColors.textSecondary)),
          );
        }

        var items = List<ProfileEditRequest>.from(snapshot.data ?? const [])
          ..sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));

        if (searchQuery.isNotEmpty) {
          items = items.where((r) => (r.userName ?? '').toLowerCase().contains(searchQuery)).toList();
        }

        if (items.isEmpty) {
          return RefreshIndicator(
            color: LightColors.gold,
            onRefresh: onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(
                      child: Text('No document renewals awaiting review.', style: TextStyle(color: LightColors.textSecondary))),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: LightColors.gold,
          onRefresh: onRefresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _RenewalTile(request: items[i], onTap: () => onTap(items[i])),
          ),
        );
      },
    );
  }
}

class _RenewalTile extends StatelessWidget {
  final ProfileEditRequest request;
  final VoidCallback onTap;

  const _RenewalTile({required this.request, required this.onTap});

  IconData get _icon => switch (request.category) {
        'company_license' => Icons.apartment_outlined,
        'truck_document' => Icons.local_shipping_outlined,
        _ => Icons.badge_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final newExpiry = request.payload['expiry_date']?.toString();
    final oldExpiry = request.oldDocument?['expiry_date']?.toString();
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
                decoration: BoxDecoration(shape: BoxShape.circle, color: LightColors.gold.withOpacity(0.12)),
                child: Icon(_icon, color: LightColors.goldMuted, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.userName ?? 'User #${request.userId}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: LightColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(request.documentTypeLabel,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: LightColors.textSecondary, fontSize: 11.5)),
                    if (oldExpiry != null || newExpiry != null)
                      Text('Expiry: ${oldExpiry ?? '—'} → ${newExpiry ?? '—'}',
                          style: const TextStyle(color: LightColors.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: LightColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Work Destinations ────────────────────────────────────────────────────

/// A driver changing which countries they cover (ProfileEditRequest
/// category 'destinations') — folded into Approvals 2026-08-28, replacing
/// the standalone AdminProfileEditRequestsPage. Unlike renewals, there's no
/// document to compare, so Approve/Reject sit right on the card instead of
/// pushing to a detail screen.
class _DestinationsList extends StatelessWidget {
  final Future<List<ProfileEditRequest>> future;
  final String searchQuery;
  final bool busy;
  final Future<void> Function() onRefresh;
  final void Function(ProfileEditRequest) onApprove;
  final void Function(ProfileEditRequest) onReject;

  const _DestinationsList({
    required this.future,
    required this.searchQuery,
    required this.busy,
    required this.onRefresh,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProfileEditRequest>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: LightColors.gold));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Could not load requests.\n${snapshot.error}',
                textAlign: TextAlign.center, style: const TextStyle(color: LightColors.textSecondary)),
          );
        }

        var items = List<ProfileEditRequest>.from(snapshot.data ?? const [])
          ..sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));

        if (searchQuery.isNotEmpty) {
          items = items.where((r) => (r.userName ?? '').toLowerCase().contains(searchQuery)).toList();
        }

        if (items.isEmpty) {
          return RefreshIndicator(
            color: LightColors.gold,
            onRefresh: onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(
                      child: Text('No work-destination changes awaiting review.', style: TextStyle(color: LightColors.textSecondary))),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: LightColors.gold,
          onRefresh: onRefresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _DestinationTile(
              request: items[i],
              busy: busy,
              onApprove: () => onApprove(items[i]),
              onReject: () => onReject(items[i]),
            ),
          ),
        );
      },
    );
  }
}

class _DestinationTile extends StatelessWidget {
  final ProfileEditRequest request;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _DestinationTile({required this.request, required this.busy, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final destinations = (request.payload['destinations'] as List?)?.join(', ') ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LightColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LightColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, color: LightColors.navy.withOpacity(0.08)),
                child: const Icon(Icons.public_outlined, color: LightColors.navy, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.userName ?? 'User #${request.userId}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: LightColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    const Text('Work destinations change', style: TextStyle(color: LightColors.goldMuted, fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(destinations.isEmpty ? '—' : destinations, style: const TextStyle(color: LightColors.textSecondary, fontSize: 12.5)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: busy ? null : onReject,
                child: const Text('Reject', style: TextStyle(color: LightColors.error, fontSize: 12)),
              ),
              TextButton(
                onPressed: busy ? null : onApprove,
                child: const Text('Approve', style: TextStyle(color: LightColors.goldMuted, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
