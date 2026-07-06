

import 'package:flutter/material.dart';
import '../API/ShipmentServices.dart';
import '../API/config.dart';
import '../models/Appuser.dart';
import '../models/Shipment.dart';
import 'AppBarWidget.dart';
import 'ShipmentDetailsPageCompany.dart';

// ── Status label helper ─────────────────────────────────────────────────────
// TODO: Adjust these cases to match your actual Shipment status codes/enum.


// ── Page ─────────────────────────────────────────────────────────────────────

class Shipmentpageadmin extends StatefulWidget {
  final AppUser user;
  Shipmentpageadmin({required this.user});

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
      backgroundColor: AppColors.bg,
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
        backgroundColor: AppColors.surface,
        title: const Text('Cancel shipment',
            style: TextStyle(color: AppColors.cream)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: AppColors.cream),
          decoration: const InputDecoration(
            hintText: 'Reason for cancellation',
            hintStyle: TextStyle(color: AppColors.muted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Confirm', style: TextStyle(color: AppColors.error)),
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
        backgroundColor: AppColors.bg,
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
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: CustomScrollView(
          slivers: [
            AppBarWidget(
              user: widget.user,
              subtitle: 'My Shipments',
            ),

            //  SEARCH BAR
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: AppColors.cream),
                  decoration: InputDecoration(
                    hintText: "Search by tracking number...",
                    hintStyle: const TextStyle(color: AppColors.muted),
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
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
                      padding: const EdgeInsets.symmetric(horizontal: 24),
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
                          selectedColor: AppColors.gold.withOpacity(0.2),
                          backgroundColor: AppColors.bg,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.gold
                                : AppColors.muted,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            fontSize: 12,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.gold
                                : AppColors.border,
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
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
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text(
              'Manage Shipment ${shipment.id}',
              style: const TextStyle(
                color: AppColors.cream,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Current status: ${statusLabel(shipment.status)}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
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
                      color: Colors.black),
                  label: const Text(
                    'Assign Driver',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            const Text(
              'Update status',
              style: TextStyle(
                color: AppColors.cream,
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
                  backgroundColor: AppColors.bg,
                  labelStyle: const TextStyle(
                    color: AppColors.cream,
                    fontSize: 12,
                  ),
                  side: const BorderSide(color: AppColors.border, width: 0.5),
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
                    color: AppColors.gold),
                label: const Text(
                  'View full details',
                  style: TextStyle(color: AppColors.gold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.gold),
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
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const Text(
              'Assign Driver',
              style: TextStyle(
                color: AppColors.cream,
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
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
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
                      tileColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(
                            color: AppColors.border, width: 0.5),
                      ),
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.bg,
                        child: Icon(Icons.person_outline,
                            color: AppColors.gold),
                      ),
                      title: Text(
                        driver.name?.toString() ?? 'Driver ${driver.id}',
                        style: const TextStyle(
                            color: AppColors.cream, fontSize: 14),
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
        child: CircularProgressIndicator(color: AppColors.gold),
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
            color: AppColors.error,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Failed to load shipments',
            style: TextStyle(
              color: AppColors.cream,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
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
            label: const Text(
              'Retry',
              style: TextStyle(color: AppColors.gold),
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
            color: AppColors.muted,
            size: 48,
          ),
          SizedBox(height: 16),
          Text(
            'No shipments yet',
            style: TextStyle(
              color: AppColors.cream,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your shipments will appear here once created.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
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

  const ShipmentItem({required this.shipment, this.onManage});

  @override
  Widget build(BuildContext context) {
    final color = shipment.statusColor;

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
              color: color.withOpacity(0.1),
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
                    fontWeight: FontWeight.w500,
                    color: AppColors.cream,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${shipment.origin} · ${shipment.destination}',
                  style:
                  const TextStyle(fontSize: 11, color: AppColors.muted),
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
                  color: color.withOpacity(0.1),
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
                const TextStyle(fontSize: 10, color: AppColors.muted),
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
                color: AppColors.gold,
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
                color: AppColors.muted,
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