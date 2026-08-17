

import 'package:flutter/material.dart';
import '../API/ShipmentServices.dart';
import '../API/config.dart';
import '../models/Appuser.dart';
import '../models/Shipment.dart';
import 'ShipmentDetailsPageCompany.dart';

// ── Page ─────────────────────────────────────────────────────────────────────

/// Admin Phase 3 (2026-08-20) redesign to LightColors, matching the rest of
/// the admin dashboard redesign. "View" already pointed at
/// ShipmentDetailsPageCompany, which was redesigned to LightColors in an
/// earlier company-side phase — left unchanged here.
class Shipmentpageadmin extends StatefulWidget {
  final AppUser user;
  Shipmentpageadmin({super.key, required this.user});

  @override
  State<Shipmentpageadmin> createState() => _CompnayshipmentsState();
}

class _CompnayshipmentsState extends State<Shipmentpageadmin> {
  final _service = ShipmentService();

  late Future<List<Shipment>> _shipmentsFuture;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // ── Status filter state ──────────────────────────────────────────────────
  String _selectedStatus = "All";
  List<String> _statusOptions = ["All"];

  @override
  void initState() {
    super.initState();
    _shipmentsFuture = _service.fetchShipmentsadmin();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  void _refresh() => setState(() {
    _shipmentsFuture = _service.fetchShipmentsadmin();
  });

  void _buildStatusOptions(List<Shipment> list) {
    final statuses = list
        .map((s) => statusLabel(s.status))
        .toSet()
        .toList();
    statuses.sort();
    _statusOptions = ["All", ...statuses];
  }

  List<Shipment> _filterShipments(List<Shipment> list) {
    var filtered = list;

    if (_selectedStatus != "All") {
      filtered = filtered
          .where((s) => statusLabel(s.status) == _selectedStatus)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((s) {
        final tracking = (s.trackingNumber ?? '').toLowerCase();
        return tracking.contains(_searchQuery);
      }).toList();
    }

    return filtered;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onManage(Shipment shipment) async {
    final result = await showModalBottomSheet<_ManageSheetResult>(
      context: context,
      backgroundColor: LightColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _ManageShipmentSheet(
          shipment: shipment,
          statusOptions: _statusOptions.where((s) => s != "All").toList(),
        );
      },
    );

    if (result == null) return;

    if (result.assignDriver) {
      await _onAssignDriver(shipment);
      return;
    }

    final newStatus = result.newStatus;
    if (newStatus != null && newStatus != statusLabel(shipment.status)) {
      final numericStatus = statusValue(newStatus);

      String? reason;
      if (numericStatus == 4) {
        // Cancelling requires a reason (missing documents, client
        // declined, etc.) — the server rejects the request without one.
        reason = await _promptCancellationReason();
        if (reason == null || reason.trim().isEmpty) return;
      }

      try {
        await _service.updateShipmentStatus(
          shipmentId: shipment.id,
          // Send the numeric code, not the label — the server expects an
          // int and silently defaulted to 0 when given text like "Cancelled".
          status: numericStatus.toString(),
          cancellationReason: reason,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Shipment status updated to $newStatus')),
        );
        _refresh();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Future<String?> _promptCancellationReason() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LightColors.surface,
        title: const Text('Cancel shipment',
            style: TextStyle(color: LightColors.textPrimary)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: LightColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Reason for cancellation',
            hintStyle: TextStyle(color: LightColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back', style: TextStyle(color: LightColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Confirm', style: TextStyle(color: LightColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _onAssignDriver(Shipment shipment) async {
    try {

      final drivers = await _service.fetchDrivers();

      if (!mounted) return;

      final selectedDriver = await showModalBottomSheet<dynamic>(
        context: context,
        backgroundColor: LightColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return _AssignDriverSheet(drivers: drivers);
        },
      );

      if (selectedDriver == null) return;
        print(shipment.id.runtimeType);


      final success = await _service.assignDriver(
        shipmentId: shipment.id,
        driverId: int.parse(selectedDriver.id),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Driver ${selectedDriver.name} assigned')),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to assign driver: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: LightColors.textPrimary),
        title: const Text('Shipments', style: TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, color: LightColors.textSecondary),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: LightColors.gold,
        onRefresh: () async => _refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            //  SEARCH BAR
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: LightColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Search by tracking number...",
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

            //  STATUS FILTER
            SliverToBoxAdapter(
              child: FutureBuilder<List<Shipment>>(
                future: _shipmentsFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();

                  _buildStatusOptions(snapshot.data!);

                  return SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _statusOptions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final status = _statusOptions[index];
                        final isSelected = status == _selectedStatus;

                        return ChoiceChip(
                          label: Text(status),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _selectedStatus = status;
                            });
                          },
                          selectedColor: LightColors.gold.withOpacity(0.16),
                          backgroundColor: LightColors.surface,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? LightColors.goldMuted
                                : LightColors.textSecondary,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            fontSize: 12,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? LightColors.gold
                                : LightColors.border,
                            width: 0.5,
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            SliverToBoxAdapter(
              child: FutureBuilder<List<Shipment>>(
                future: _shipmentsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const _LoadingState();
                  }

                  if (snapshot.hasError) {
                    return _ErrorState(
                      message: snapshot.error.toString(),
                      onRetry: _refresh,
                    );
                  }

                  final shipments =
                  _filterShipments(snapshot.data ?? []);

                  if (shipments.isEmpty) {
                    return const _EmptyState();
                  }

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Column(
                      children: [
                        for (int i = 0; i < shipments.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          ShipmentItem(
                            shipment: shipments[i],
                            onManage: () => _onManage(shipments[i]),
                          ),
                        ],
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

// ── Manage Sheet Result ──────────────────────────────────────────────────────

class _ManageSheetResult {
  final String? newStatus;
  final bool assignDriver;

  _ManageSheetResult.status(this.newStatus) : assignDriver = false;
  _ManageSheetResult.assignDriverAction()
      : newStatus = null,
        assignDriver = true;
}

// ── Manage Bottom Sheet ──────────────────────────────────────────────────────

class _ManageShipmentSheet extends StatelessWidget {
  final Shipment shipment;
  final List<String> statusOptions;

  const _ManageShipmentSheet({
    required this.shipment,
    required this.statusOptions,
  });

  @override
  Widget build(BuildContext context) {
    // status == 0 means "New" — only then do we allow assigning a driver
    final isNew = shipment.status == 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: LightColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text(
              'Manage Shipment ${shipment.id}',
              style: const TextStyle(
                color: LightColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Current status: ${statusLabel(shipment.status)}',
              style: const TextStyle(color: LightColors.textSecondary, fontSize: 12),
            ),

            if (isNew) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(
                    context,
                    _ManageSheetResult.assignDriverAction(),
                  ),
                  icon: const Icon(Icons.local_shipping_outlined,
                      color: LightColors.textPrimary),
                  label: const Text(
                    'Assign Driver',
                    style: TextStyle(
                        color: LightColors.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LightColors.gold,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            const Text(
              'Update status',
              style: TextStyle(
                color: LightColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: statusOptions.map((status) {
                return ActionChip(
                  label: Text(status),
                  backgroundColor: LightColors.bg,
                  labelStyle: const TextStyle(
                    color: LightColors.textPrimary,
                    fontSize: 12,
                  ),
                  side: const BorderSide(color: LightColors.border, width: 0.5),
                  onPressed: () => Navigator.pop(
                    context,
                    _ManageSheetResult.status(status),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShipmentDetailsPageCompany(
                        shipment: shipment,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.visibility_outlined,
                    color: LightColors.goldMuted),
                label: const Text(
                  'View full details',
                  style: TextStyle(color: LightColors.goldMuted),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: LightColors.gold),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Assign Driver Sheet ──────────────────────────────────────────────────────

class _AssignDriverSheet extends StatelessWidget {
  final List<dynamic> drivers; // TODO: replace dynamic with your Driver model type

  const _AssignDriverSheet({required this.drivers});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: LightColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const Text(
              'Assign Driver',
              style: TextStyle(
                color: LightColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            if (drivers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No drivers available',
                    style: TextStyle(color: LightColors.textSecondary, fontSize: 13),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: drivers.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final driver = drivers[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      tileColor: LightColors.bg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(
                            color: LightColors.border, width: 0.5),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: LightColors.gold.withOpacity(0.12),
                        child: const Icon(Icons.person_outline,
                            color: LightColors.goldMuted),
                      ),
                      title: Text(
                        driver.name?.toString() ?? 'Driver ${driver.id}',
                        style: const TextStyle(
                            color: LightColors.textPrimary, fontSize: 14),
                      ),
                      onTap: () => Navigator.pop(context, driver),
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

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: LightColors.error,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Failed to load shipments',
            style: TextStyle(
              color: LightColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
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
            label: const Text(
              'Retry',
              style: TextStyle(color: LightColors.gold),
            ),
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
          Icon(
            Icons.inventory_2_outlined,
            color: LightColors.textSecondary,
            size: 48,
          ),
          SizedBox(height: 16),
          Text(
            'No shipments yet',
            style: TextStyle(
              color: LightColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your shipments will appear here once created.',
            textAlign: TextAlign.center,
            style: TextStyle(color: LightColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── ShipmentItem ─────────────────────────────────────────────────────────────

class ShipmentItem extends StatelessWidget {
  final Shipment shipment;
  final VoidCallback? onManage;

  const ShipmentItem({super.key, required this.shipment, this.onManage});

  @override
  Widget build(BuildContext context) {
    final color = shipment.statusColor;

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
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(shipment.icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),

          // ID + route
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shipment.id.toString(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: LightColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${shipment.origin} · ${shipment.destination}',
                  style:
                  const TextStyle(fontSize: 11, color: LightColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Status badge + weight
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel(shipment.status),
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                shipment.weight,
                style:
                const TextStyle(fontSize: 10, color: LightColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(width: 4),

          // View + Manage buttons
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility_outlined),
                color: LightColors.goldMuted,
                tooltip: 'View',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShipmentDetailsPageCompany(
                        shipment: shipment,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                color: LightColors.textSecondary,
                tooltip: 'Manage',
                onPressed: onManage,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
