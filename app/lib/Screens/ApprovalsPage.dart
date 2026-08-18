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
enum ApprovalSection { registrations, renewals, changes }

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

  @override
  void initState() {
    super.initState();
    _section = (widget.initialSection == ApprovalSection.renewals && !_canReviewRenewals)
        ? ApprovalSection.registrations
        : widget.initialSection;
    _registrationsFuture = _loadRegistrations();
    _renewalsFuture = _loadRenewals();
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

  Future<void> _refreshAll() async {
    setState(() {
      _registrationsFuture = _loadRegistrations();
      _renewalsFuture = _loadRenewals();
    });
    await Future.wait([_registrationsFuture, _renewalsFuture]);
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
                          label: 'New\nRegistrations',
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
