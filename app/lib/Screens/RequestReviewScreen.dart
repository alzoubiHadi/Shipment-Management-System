import 'package:flutter/material.dart';

import '../API/CompanyService.dart';
import '../API/DriverService.dart';
import '../API/config.dart';
import '../models/Company.dart';
import '../models/Driver.dart';
import '../models/DriverDocument.dart';
import '../models/Truck.dart';
import 'DecisionConfirmationScreen.dart';

/// The tabbed request-review + decision screen (2026-08-21 mockup, Phase 3
/// of the admin dashboard redesign) — replaces the interim link to the
/// dark-themed DriverDetailsPage/CompanyDetailsPage that RegistrationRequestsScreen
/// used in Phase 2.
///
/// Scope notes (data actually available today):
/// - Driver tabs: Driver Info / Documents / Truck Info. The mockup splits
///   "Truck Info" and "Truck Documents" into two tabs — folded into one
///   here since both come from the same Truck fetch and there wasn't a
///   strong reason to force a 4th tab.
/// - Company tabs: Company Info / Documents only (mockup also shows
///   Contacts/Address tabs, but Company has no address/contact-person
///   fields in this data model — same reduced-scope call the user already
///   made for the company registration wizard: 4 fields, not the fuller
///   mockup).
/// - Approve/Reject/Request Changes all call the SAME backend endpoints the
///   old dark-themed detail pages used (DriverController::approve/reject/
///   returnForCompletion, CompanyController ditto) — no new decision logic,
///   just a new light-themed tabbed UI over it.
enum _ReqKind { driver, company }

class RequestReviewScreen extends StatefulWidget {
  final _ReqKind kind;
  final Driver? driver;
  final Company? company;

  const RequestReviewScreen.driver(Driver driver, {super.key})
      : kind = _ReqKind.driver,
        driver = driver,
        company = null;

  const RequestReviewScreen.company(Company company, {super.key})
      : kind = _ReqKind.company,
        driver = null,
        company = company;

  @override
  State<RequestReviewScreen> createState() => _RequestReviewScreenState();
}

class _RequestReviewScreenState extends State<RequestReviewScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _busy = false;

  // Mutable local copies so approve/reject/request-changes can update the
  // header/stepper/action-bar immediately without needing the caller to
  // refetch — mirrors the copyWith pattern CompanyDetailsPage already uses.
  late Driver? _driver = widget.driver;
  late Company? _company = widget.company;

  bool get _isDriver => widget.kind == _ReqKind.driver;

  String get _status => _isDriver ? _driver!.approvalStatus : _company!.approvalStatus;
  String get _name => _isDriver ? _driver!.name : _company!.name;
  String get _email => _isDriver ? _driver!.email : _company!.email;
  String get _phone => _isDriver ? _driver!.phone : _company!.phone;
  String get _rejectionReason => (_isDriver ? _driver!.rejectionReason : _company!.rejectionReason) ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _isDriver ? 3 : 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _code {
    final prefix = _isDriver ? 'DR' : 'CO';
    final id = int.tryParse(_isDriver ? _driver!.id : _company!.id) ?? 0;
    return '$prefix-${id.toString().padLeft(4, '0')}';
  }

  /// 2026-08-27 (security review, item 7): documents moved to the private
  /// disk — each tab now builds the right authenticated download URL
  /// itself (driver/truck/company id varies per tab), this just opens it.
  Future<void> _openFile(String? url) async {
    if (url == null || url.isEmpty) return;
    await viewSecureFile(context, url);
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? LightColors.error : null),
    );
  }

  Future<void> _approve() async {
    setState(() => _busy = true);
    final result = _isDriver
        ? await DriverService.approveDriver(_driver!.id)
        : await CompanyService.approveCompany(_company!.id);
    setState(() => _busy = false);

    final success = result is Map ? result['success'] == true : result == true;
    final message = result is Map ? (result['message']?.toString() ?? '') : (success ? 'Approved' : 'Could not approve');
    if (success) {
      _afterDecision(DecisionOutcome.approved);
    } else {
      _snack(message, isError: true);
    }
  }

  Future<void> _reject() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ReasonDialog(
        title: 'Reject Request',
        hint: 'Reason (optional)',
        confirmLabel: 'Reject',
        confirmColor: LightColors.error,
        controller: reasonCtrl,
        requireText: false,
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    bool success;
    String message;
    if (_isDriver) {
      success = await DriverService.rejectDriver(_driver!.id, reason: reasonCtrl.text.trim());
      message = success ? 'Driver rejected' : 'Could not reject driver';
    } else {
      success = await CompanyService.rejectCompany(_company!.id, reason: reasonCtrl.text.trim());
      message = success ? 'Company rejected' : 'Could not reject company';
    }
    setState(() => _busy = false);
    if (success) {
      _afterDecision(DecisionOutcome.rejected);
    } else {
      _snack(message, isError: true);
    }
  }

  Future<void> _requestChanges() async {
    final messageCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ReasonDialog(
        title: 'Request Changes',
        hint: 'What needs to be fixed? (required)',
        confirmLabel: 'Send',
        confirmColor: LightColors.gold,
        confirmTextColor: LightColors.textPrimary,
        controller: messageCtrl,
        requireText: true,
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    final result = _isDriver
        ? await DriverService.returnDriverForCompletion(_driver!.id, messageCtrl.text.trim())
        : await CompanyService.returnCompanyForCompletion(_company!.id, messageCtrl.text.trim());
    setState(() => _busy = false);

    final success = result['success'] == true;
    if (success) {
      _afterDecision(DecisionOutcome.changesRequired);
    } else {
      _snack(result['message']?.toString() ?? '', isError: true);
    }
  }

  /// Replaces this screen with the matching outcome confirmation screen
  /// (2026-08-21 mockup's 3 outcome screens) instead of just popping with a
  /// SnackBar. That confirmation screen's "Back to Requests" button then
  /// pops straight back to RegistrationRequestsScreen (it now sits directly
  /// above it in the stack) and tells it to refresh.
  void _afterDecision(DecisionOutcome outcome) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DecisionConfirmationScreen(outcome: outcome, name: _name, isDriver: _isDriver),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: LightColors.textPrimary),
        title: const Text('Request Details',
            style: TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          _buildHeader(),
          _StatusStepper(status: _status),
          const SizedBox(height: 4),
          TabBar(
            controller: _tabController,
            labelColor: LightColors.textPrimary,
            unselectedLabelColor: LightColors.textSecondary,
            indicatorColor: LightColors.gold,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            tabs: _isDriver
                ? const [Tab(text: 'Driver Info'), Tab(text: 'Documents'), Tab(text: 'Truck Info')]
                : const [Tab(text: 'Company Info'), Tab(text: 'Documents')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _isDriver
                  ? [_DriverInfoTab(driver: _driver!), _DriverDocumentsTab(driver: _driver!, onOpenFile: _openFile), _TruckInfoTab(driver: _driver!, onOpenFile: _openFile)]
                  : [_CompanyInfoTab(company: _company!), _CompanyDocumentsTab(company: _company!, onOpenFile: _openFile)],
            ),
          ),
          if (_status == 'pending' || _status == 'changes_required') _buildActionBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isDriver ? LightColors.navy.withOpacity(0.08) : LightColors.gold.withOpacity(0.12),
            ),
            child: Icon(
              _isDriver ? Icons.person_outline : Icons.apartment_outlined,
              color: _isDriver ? LightColors.navy : LightColors.goldMuted,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(_name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: LightColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(status: _status),
                  ],
                ),
                const SizedBox(height: 2),
                Text(_isDriver ? 'Driver Registration' : 'Company Registration',
                    style: const TextStyle(color: LightColors.textSecondary, fontSize: 12)),
                Text(_code, style: const TextStyle(color: LightColors.textSecondary, fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: LightColors.surface,
        border: Border(top: BorderSide(color: LightColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : _reject,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: LightColors.error),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Reject', style: TextStyle(color: LightColors.error, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : _requestChanges,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: LightColors.gold),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Request Changes', style: TextStyle(color: LightColors.goldMuted, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: _busy ? null : _approve,
              style: ElevatedButton.styleFrom(
                backgroundColor: LightColors.success,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _busy
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonDialog extends StatefulWidget {
  final String title;
  final String hint;
  final String confirmLabel;
  final Color confirmColor;
  final Color confirmTextColor;
  final TextEditingController controller;
  final bool requireText;

  const _ReasonDialog({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.confirmColor,
    this.confirmTextColor = Colors.white,
    required this.controller,
    required this.requireText,
  });

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: LightColors.surface,
      title: Text(widget.title, style: const TextStyle(color: LightColors.textPrimary, fontWeight: FontWeight.w700)),
      content: TextField(
        controller: widget.controller,
        maxLines: 3,
        style: const TextStyle(color: LightColors.textPrimary),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(color: LightColors.textSecondary),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: LightColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: LightColors.gold)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: LightColors.textSecondary)),
        ),
        TextButton(
          onPressed: (widget.requireText && widget.controller.text.trim().isEmpty) ? null : () => Navigator.pop(context, true),
          style: TextButton.styleFrom(backgroundColor: widget.confirmColor),
          child: Text(widget.confirmLabel, style: TextStyle(color: widget.confirmTextColor, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'pending' => LightColors.pending,
      'changes_required' => LightColors.goldMuted,
      'rejected' => LightColors.error,
      'approved' => LightColors.success,
      _ => LightColors.textSecondary,
    };
    final bg = switch (status) {
      'pending' => LightColors.pendingBg,
      'changes_required' => LightColors.gold.withOpacity(0.12),
      'rejected' => LightColors.errorBg,
      'approved' => LightColors.successBg,
      _ => LightColors.border,
    };
    final label = switch (status) {
      'pending' => 'PENDING',
      'changes_required' => 'CHANGES',
      'rejected' => 'REJECTED',
      'approved' => 'APPROVED',
      _ => status.toUpperCase(),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _StatusStepper extends StatelessWidget {
  final String status;
  const _StatusStepper({required this.status});

  @override
  Widget build(BuildContext context) {
    // Submitted is always done. "Under Review" counts as done once the
    // admin has made ANY decision (approved/rejected/changes_required) —
    // changes_required loops back to the applicant but the review step
    // itself did happen. Approved/Rejected are alternate terminal nodes;
    // only the one matching the current status lights up.
    final reviewed = status != 'pending';
    final steps = [
      (_StepIcon.check, 'Submitted', true),
      (_StepIcon.dot, 'Under Review', reviewed || status == 'pending'),
      (_StepIcon.check, 'Approved', status == 'approved'),
      (_StepIcon.close, 'Rejected', status == 'rejected'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            _StepDot(active: steps[i].$3, icon: steps[i].$1, label: steps[i].$2, current: i == 1 && status == 'pending'),
            if (i != steps.length - 1)
              Expanded(child: Container(height: 2, color: LightColors.border, margin: const EdgeInsets.only(bottom: 16))),
          ],
        ],
      ),
    );
  }
}

enum _StepIcon { check, dot, close }

class _StepDot extends StatelessWidget {
  final bool active;
  final bool current;
  final _StepIcon icon;
  final String label;

  const _StepDot({required this.active, required this.icon, required this.label, this.current = false});

  @override
  Widget build(BuildContext context) {
    final color = active ? LightColors.gold : LightColors.border;
    return Column(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? LightColors.gold : LightColors.surface,
            border: Border.all(color: color, width: current ? 2.5 : 1.5),
          ),
          child: active
              ? Icon(
                  icon == _StepIcon.close ? Icons.close : Icons.check,
                  size: 13,
                  color: Colors.white,
                )
              : null,
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 9.5, color: active ? LightColors.textPrimary : LightColors.textSecondary)),
      ],
    );
  }
}

// ── Driver tabs ──────────────────────────────────────────────────────────

class _DriverInfoTab extends StatelessWidget {
  final Driver driver;
  const _DriverInfoTab({required this.driver});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        if (driver.documentIssues.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: LightColors.errorBg, borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: driver.documentIssues.map((i) => Text('• $i', style: const TextStyle(color: LightColors.error, fontSize: 12.5))).toList(),
            ),
          ),
        _InfoCard(title: 'Personal Information', rows: [
          ('Full Name', driver.name),
          ('Nationality', driver.nationality),
          ('Age', driver.age),
          ('Email', driver.email),
          ('Phone', driver.phone),
          ('Blood Type', driver.bloodType),
          ('Health Conditions', driver.healthConditions ?? ''),
        ]),
        const SizedBox(height: 14),
        _InfoCard(title: 'License Information', rows: [
          ('License No.', driver.driver_license),
          ('License Expiry', driver.license_expiry),
        ]),
        const SizedBox(height: 14),
        _InfoCard(title: 'Passport & Residency', rows: [
          ('Passport Expiry', driver.passportExpiry),
          ('Residency Expiry', driver.residencyExpiry),
        ]),
      ],
    );
  }
}

class _DriverDocumentsTab extends StatefulWidget {
  final Driver driver;
  final Future<void> Function(String? path) onOpenFile;
  const _DriverDocumentsTab({required this.driver, required this.onOpenFile});

  @override
  State<_DriverDocumentsTab> createState() => _DriverDocumentsTabState();
}

class _DriverDocumentsTabState extends State<_DriverDocumentsTab> {
  late Future<List<DriverDocument>> _future;

  @override
  void initState() {
    super.initState();
    _future = DriverService.fetchDocumentsFor(widget.driver.user_id);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DriverDocument>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: LightColors.gold));
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Could not load documents', style: TextStyle(color: LightColors.textSecondary)));
        }
        final all = snapshot.data ?? [];
        final current = <String, DriverDocument>{};
        for (final d in all) {
          if (d.isCurrent) current[d.type] = d;
        }
        final docs = current.values.toList();
        return _DocumentListView(
          docs: docs
              .map((d) => _DocRow(
                    label: driverDocumentTypeLabel(d.type),
                    path: d.filePath,
                    viewUrl: '$baseUrl/driver-documents/${d.id}/file',
                    expiry: d.expiryDate,
                    expired: d.isExpired,
                  ))
              .toList(),
          onOpenFile: widget.onOpenFile,
        );
      },
    );
  }
}

class _TruckInfoTab extends StatefulWidget {
  final Driver driver;
  final Future<void> Function(String? path) onOpenFile;
  const _TruckInfoTab({required this.driver, required this.onOpenFile});

  @override
  State<_TruckInfoTab> createState() => _TruckInfoTabState();
}

class _TruckInfoTabState extends State<_TruckInfoTab> {
  late Future<Truck?> _future;

  @override
  void initState() {
    super.initState();
    _future = DriverService.fetchTruckForDriver(widget.driver.id);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Truck?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: LightColors.gold));
        }
        final truck = snapshot.data;
        if (truck == null) {
          return const Center(child: Text('No truck on file for this driver', style: TextStyle(color: LightColors.textSecondary)));
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          children: [
            _InfoCard(title: 'Truck Details', rows: [
              ('Plate Number', truck.truckNumber),
              ('Truck Type', truck.truckType),
              ('Refrigerated', truck.hasRefrigeration ? 'Yes' : 'No'),
              ('Permit Type', truck.permitType ?? ''),
              ('Permit Expiry', _fmtDate(truck.permitExpiry)),
            ]),
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Truck Documents', style: TextStyle(color: LightColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            _DocumentListView(
              docs: [
                _DocRow(label: 'Vehicle Registration', path: truck.licenseFilePath, viewUrl: '$baseUrl/trucks/${truck.id}/file/license', expiry: truck.licenseExpiry, expired: _isExpired(truck.licenseExpiry)),
                _DocRow(label: 'Insurance Certificate', path: truck.insuranceFilePath, viewUrl: '$baseUrl/trucks/${truck.id}/file/insurance', expiry: truck.insuranceExpiry, expired: _isExpired(truck.insuranceExpiry)),
                _DocRow(label: 'Technical Inspection', path: truck.technicalInspectionFilePath, viewUrl: '$baseUrl/trucks/${truck.id}/file/technical_inspection', expiry: truck.technicalInspectionExpiry, expired: _isExpired(truck.technicalInspectionExpiry)),
              ],
              onOpenFile: widget.onOpenFile,
              showSummary: false,
            ),
          ],
        );
      },
    );
  }

  bool _isExpired(DateTime? d) => d != null && d.isBefore(DateTime.now());
  String _fmtDate(DateTime? d) => d == null ? '' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ── Company tabs ─────────────────────────────────────────────────────────

class _CompanyInfoTab extends StatelessWidget {
  final Company company;
  const _CompanyInfoTab({required this.company});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        if (company.approvalStatus == 'rejected' && company.rejectionReason != null && company.rejectionReason!.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: LightColors.errorBg, borderRadius: BorderRadius.circular(10)),
            child: Text('Reason: ${company.rejectionReason}', style: const TextStyle(color: LightColors.error, fontSize: 12.5)),
          ),
        _InfoCard(title: 'Company Information', rows: [
          ('Company Name', company.name),
          ('Email', company.email),
          ('Phone', company.phone),
          ('Account Status', company.accountStatus),
        ]),
      ],
    );
  }
}

class _CompanyDocumentsTab extends StatelessWidget {
  final Company company;
  final Future<void> Function(String? path) onOpenFile;
  const _CompanyDocumentsTab({required this.company, required this.onOpenFile});

  @override
  Widget build(BuildContext context) {
    final hasLicense = (company.licenseFilePath ?? '').isNotEmpty;
    return _DocumentListView(
      docs: [
        _DocRow(
          label: 'Trade License',
          path: company.licenseFilePath,
          viewUrl: '$baseUrl/companies/${company.id}/license/file',
          expiry: null,
          expired: false,
          missing: !hasLicense,
        ),
      ],
      onOpenFile: onOpenFile,
      showSummary: false,
    );
  }
}

// ── Shared building blocks ──────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;
  const _InfoCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LightColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LightColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: LightColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 130, child: Text(row.$1, style: const TextStyle(color: LightColors.textSecondary, fontSize: 12.5))),
                  Expanded(child: Text(row.$2.isEmpty ? '—' : row.$2, style: const TextStyle(color: LightColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w500))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DocRow {
  final String label;
  final String? path;
  // 2026-08-27 (security review, item 7): the fully-built authenticated
  // download URL for this specific document (varies by source — driver
  // document id, truck id + file type, or company id) — `path` is kept
  // only to detect "missing" (empty/null), viewing goes through this URL.
  final String? viewUrl;
  final DateTime? expiry;
  final bool expired;
  final bool missing;
  _DocRow({required this.label, required this.path, this.viewUrl, required this.expiry, required this.expired, this.missing = false});
}

class _DocumentListView extends StatelessWidget {
  final List<_DocRow> docs;
  final Future<void> Function(String? path) onOpenFile;
  final bool showSummary;

  const _DocumentListView({required this.docs, required this.onOpenFile, this.showSummary = true});

  @override
  Widget build(BuildContext context) {
    final total = docs.length;
    final valid = docs.where((d) => !d.expired && !d.missing).length;
    final expiringSoon = docs.where((d) => d.expiry != null && !d.expired && d.expiry!.isBefore(DateTime.now().add(const Duration(days: 30)))).length;
    final expired = docs.where((d) => d.expired).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        for (final doc in docs)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: LightColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: LightColors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.description_outlined, color: doc.missing ? LightColors.textSecondary : (doc.expired ? LightColors.error : LightColors.goldMuted), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doc.label, style: const TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      if (doc.expiry != null)
                        Text('exp. ${doc.expiry!.year}-${doc.expiry!.month.toString().padLeft(2, '0')}-${doc.expiry!.day.toString().padLeft(2, '0')}',
                            style: TextStyle(color: doc.expired ? LightColors.error : LightColors.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                if (doc.missing)
                  const Text('Missing', style: TextStyle(color: LightColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600))
                else
                  TextButton(
                    onPressed: () => onOpenFile(doc.viewUrl),
                    child: const Text('View', style: TextStyle(color: LightColors.goldMuted, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
        if (docs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text('No documents uploaded yet', style: TextStyle(color: LightColors.textSecondary))),
          ),
        if (showSummary && docs.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: LightColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: LightColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Documents Summary', style: TextStyle(color: LightColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                _summaryRow('Total Documents', '$total'),
                _summaryRow('Valid', '$valid', color: LightColors.success),
                _summaryRow('Expiring Soon', '$expiringSoon', color: LightColors.pending),
                _summaryRow('Expired', '$expired', color: LightColors.error),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _summaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: LightColors.textSecondary, fontSize: 12)),
          Text(value, style: TextStyle(color: color ?? LightColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
