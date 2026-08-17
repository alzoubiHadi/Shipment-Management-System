import 'package:flutter/material.dart';

import '../API/AdminShipmentService.dart';
import '../API/ShipmentOfferService.dart';
import '../API/config.dart';
import 'AdminShipmentStatusStyle.dart';

/// Admin Shipments redesign (2026-08-24): opened when the admin taps a
/// still-matching offer in the Shipments list (kind: 'offer', no driver
/// accepted yet). Shows the eligible-driver count, current round, and a
/// round-by-round matching history (backed by the new
/// shipment_offer_matching_rounds table — see MatchingService::matchNextBatch()).
class MatchingStatusScreen extends StatefulWidget {
  final String trackingNumber;
  const MatchingStatusScreen({super.key, required this.trackingNumber});

  @override
  State<MatchingStatusScreen> createState() => _MatchingStatusScreenState();
}

class _MatchingStatusScreenState extends State<MatchingStatusScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _offer;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AdminShipmentService.fetchDetail(widget.trackingNumber);
      if (!mounted) return;
      setState(() {
        _offer = data['offer'] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _cancel() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LightColors.surface,
        title: const Text('Cancel this offer?', style: TextStyle(color: LightColors.textPrimary, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: reasonCtrl,
          style: const TextStyle(color: LightColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Cancellation reason'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel offer', style: TextStyle(color: LightColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || reasonCtrl.text.trim().isEmpty) return;

    setState(() => _cancelling = true);
    final ok = await ShipmentOfferService.cancelOffer(offerId: _offer!['id'] as int, reason: reasonCtrl.text.trim());
    if (!mounted) return;
    setState(() => _cancelling = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offer cancelled')));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not cancel the offer'), backgroundColor: LightColors.error));
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
        title: Text('#${widget.trackingNumber}', style: const TextStyle(color: LightColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: LightColors.navy));
    }
    if (_error != null || _offer == null) {
      return Center(child: Text(_error ?? 'Not found', style: const TextStyle(color: LightColors.textSecondary)));
    }

    final offer = _offer!;
    final company = offer['company'] as Map<String, dynamic>?;
    final rounds = (offer['matching_rounds'] as List? ?? []).cast<Map<String, dynamic>>();
    final eligibleCount = offer['eligible_drivers_count'];
    final offersSent = rounds.fold<int>(0, (sum, r) => sum + ((r['driver_count'] as int?) ?? 0));
    final cancellation = offer['cancellation'] as Map<String, dynamic>?;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${offer['origin']} → ${offer['destination']}',
                    style: const TextStyle(color: LightColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              AdminStatusPill(label: offer['status_label']?.toString() ?? '', statusGroup: 'pending'),
            ],
          ),
          if (company != null) ...[
            const SizedBox(height: 4),
            Text(company['name']?.toString() ?? '', style: const TextStyle(color: LightColors.textSecondary, fontSize: 13)),
          ],
          const SizedBox(height: 24),
          if (offer['status'] == 'pending') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(color: LightColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LightColors.border)),
              child: Column(
                children: [
                  const Icon(Icons.local_shipping_outlined, size: 44, color: LightColors.pending),
                  const SizedBox(height: 12),
                  const Text('Waiting for Driver', style: TextStyle(color: LightColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text('We are finding the best matched drivers for this shipment.',
                        textAlign: TextAlign.center, style: TextStyle(color: LightColors.textSecondary, fontSize: 12.5)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _StatBox(label: 'Eligible Drivers', value: '${eligibleCount ?? '—'}')),
                const SizedBox(width: 10),
                Expanded(child: _StatBox(label: 'Offers Sent', value: '$offersSent')),
                const SizedBox(width: 10),
                Expanded(child: _StatBox(label: 'Current Round', value: '${offer['matching_round'] ?? 0}')),
              ],
            ),
          ] else if (cancellation != null) ...[
            _InfoCard(title: 'Cancellation', rows: [
              MapEntry('Reason', cancellation['reason']?.toString() ?? '—'),
              MapEntry('Cancelled by', cancellation['cancelled_by']?.toString() ?? '—'),
              MapEntry('Cancelled at', _fmt(cancellation['cancelled_at'])),
            ]),
          ],
          const SizedBox(height: 24),
          const Text('Matching Timeline', style: TextStyle(color: LightColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (rounds.isEmpty)
            const Text('No matching rounds yet.', style: TextStyle(color: LightColors.textSecondary, fontSize: 12.5))
          else
            ...rounds.map((r) => _RoundTile(round: r)),
          if (offer['status'] == 'pending') ...[
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _cancelling ? null : _cancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: LightColors.error,
                  side: const BorderSide(color: LightColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _cancelling
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: LightColors.error))
                    : const Text('Cancel Offer'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(dynamic raw) {
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return raw.toString();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: LightColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: LightColors.border)),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: LightColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: LightColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _RoundTile extends StatelessWidget {
  final Map<String, dynamic> round;
  const _RoundTile({required this.round});

  @override
  Widget build(BuildContext context) {
    final outcome = round['outcome']?.toString() ?? 'waiting';
    final (icon, color, label) = switch (outcome) {
      'accepted' => (Icons.check_circle, LightColors.success, 'Accepted${round['accepted_by_driver_name'] != null ? ' by ${round['accepted_by_driver_name']}' : ''}'),
      'no_acceptance' => (Icons.remove_circle_outline, LightColors.textSecondary, 'No acceptance'),
      'escalated' => (Icons.priority_high_rounded, LightColors.error, 'Escalated'),
      _ => (Icons.access_time_rounded, LightColors.pending, 'Waiting for response'),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Round ${round['round_number']} • ${round['driver_count']} driver(s) notified',
                    style: const TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                Text(label, style: TextStyle(color: color, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<MapEntry<String, String>> rows;
  const _InfoCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: LightColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: LightColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(width: 110, child: Text(row.key, style: const TextStyle(color: LightColors.textSecondary, fontSize: 12))),
                  Expanded(child: Text(row.value, style: const TextStyle(color: LightColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
