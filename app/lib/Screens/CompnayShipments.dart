import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../API/ShipmentServices.dart';
import '../API/config.dart';
import '../models/Appuser.dart';
import '../models/Shipment.dart';
import 'AppBarWidget.dart';
import 'ShipmentDetailsPageCompany.dart';




// ── Page ─────────────────────────────────────────────────────────────────────

class Compnayshipments extends StatefulWidget {
  final AppUser user;
  Compnayshipments({required this.user});

  @override
  State<Compnayshipments> createState() => _CompnayshipmentsState();
}

class _CompnayshipmentsState extends State<Compnayshipments> {
  final _service = ShipmentService();

  late Future<List<Shipment>> _shipmentsFuture;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _shipmentsFuture = _service.fetchShipmentscompany();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  void _refresh() => setState(() {
    _shipmentsFuture = _service.fetchShipmentscompany();
  });

  List<Shipment> _filterShipments(List<Shipment> list) {
    if (_searchQuery.isEmpty) return list;

    return list.where((s) {
      final tracking = (s.trackingNumber ?? '').toLowerCase();
      return tracking.contains(_searchQuery);
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
      backgroundColor: AppColors.bg,
      // Companies never create shipments themselves in the real workflow —
      // they call/email/WhatsApp the admin, who logs the request as a
      // shipment offer. So there is intentionally no "add shipment" button
      // here anymore.
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: CustomScrollView(
          slivers: [
            AppBarWidget(
              user: widget.user,
              subtitle: 'My Shipments',
            ),

            // 🔎 SEARCH BAR
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
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),

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
                          ShipmentItem(shipment: shipments[i]),
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

  const ShipmentItem({required this.shipment});

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

          // Status badge + time
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
              IconButton(
                icon: const Icon(Icons.visibility_outlined),
                color: AppColors.gold,
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
              )
            ],
          ),
        ],
      ),
    );
  }
}