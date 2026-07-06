import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../API/ShipmentServices.dart';
import '../API/config.dart';
import '../models/Shipment.dart';
import 'package:uuid/uuid.dart';





class AddShipmentForm extends StatefulWidget {
  /// Called with the new [Shipment] when the form is submitted successfully.
  final void Function(Shipment shipment)? onSubmit;

  const AddShipmentForm({super.key, this.onSubmit});

  @override
  State<AddShipmentForm> createState() => _AddShipmentFormState();
}

class _AddShipmentFormState extends State<AddShipmentForm> {
  final _formKey = GlobalKey<FormState>();

  final _originController      = TextEditingController();
  final _destinationController = TextEditingController();
  final _weightController      = TextEditingController();
  final _descriptionController = TextEditingController();

  // Auto-generated tracking number — shown read-only
  final String _trackingNumber =
      'TRK-${const Uuid().v4().substring(0, 8).toUpperCase()}';

  bool _isLoading = false;

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _weightController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final shipment = Shipment(
        id: 0,
        trackingNumber: _trackingNumber,
        origin: _originController.text.trim(),
        destination: _destinationController.text.trim(),
        weight: _weightController.text.trim(),
        description: _descriptionController.text.trim(),
        status: 0,
        pickup_time: '',
        delivered_at: '',
        created_at: '',
      );

      final saved = await ShipmentService().addShipment(shipment: shipment);

      if (!mounted) return;

      if (saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Shipment added successfully',
                  style: TextStyle(color: AppColors.cream),
                ),
              ],
            ),
            backgroundColor: AppColors.surfaceHigh,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
        widget.onSubmit?.call(shipment);
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: AppColors.error, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Failed to add shipment',
                  style: TextStyle(color: AppColors.cream),
                ),
              ],
            ),
            backgroundColor: AppColors.surfaceHigh,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      debugPrint(e.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: AppColors.error, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  e.toString(),
                  style: TextStyle(color: AppColors.cream),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.surfaceHigh,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.cream,
        title: Text(
          'New Shipment',
          style: TextStyle(color: AppColors.cream, fontWeight: FontWeight.w500),
        ),
        iconTheme: IconThemeData(color: AppColors.gold),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Shipment Info ──────────────────────────────────────────
            _SectionLabel('Shipment Info'),
            const SizedBox(height: 10),

            _ReadOnlyField(
              label: 'Tracking Number',
              value: _trackingNumber,
              badge: 'AUTO',
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _InputField(
                    controller: _originController,
                    label: 'Origin',
                    hint: 'e.g. Dubai',
                    icon: Icons.location_on_outlined,
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InputField(
                    controller: _destinationController,
                    label: 'Destination',
                    hint: 'e.g. London',
                    icon: Icons.location_on_outlined,
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 16),

            // ── Package Details ────────────────────────────────────────
            _SectionLabel('Package Details'),
            const SizedBox(height: 10),

            _InputField(
              controller: _weightController,
              label: 'Weight',
              hint: 'Enter weight',
              suffix: 'kg',
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (double.tryParse(v.trim()) == null) {
                  return 'Enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            _InputField(
              controller: _descriptionController,
              label: 'Description',
              hint: 'Describe the contents...',
              maxLines: 4,
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),

            const SizedBox(height: 20),
            Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 16),

            // ── Status ─────────────────────────────────────────────────
            _SectionLabel('Status'),
            const SizedBox(height: 10),

            const _StatusField(),

            const SizedBox(height: 28),

            // ── Submit ─────────────────────────────────────────────────
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.bg,
                  ),
                )
                    : const Icon(Icons.local_shipping_outlined),
                label: Text(_isLoading ? 'Saving...' : 'Add Shipment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.bg,
                  disabledBackgroundColor: AppColors.goldMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Reusable widgets ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.goldMuted,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  final String? badge;

  const _ReadOnlyField({
    required this.label,
    required this.value,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.cream,
                  fontFamily: 'monospace',
                ),
              ),
              if (badge != null)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.goldMuted.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.goldMuted.withOpacity(0.4)),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? suffix;
  final IconData? icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.suffix,
    this.icon,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: AppColors.cream, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.muted, fontSize: 13),
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.mutedLight, fontSize: 13),
        suffixText: suffix,
        suffixStyle: TextStyle(color: AppColors.muted),
        suffixIcon: icon != null
            ? Icon(icon, size: 18, color: AppColors.mutedLight)
            : null,
        filled: true,
        fillColor: AppColors.surfaceHigh,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.gold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error, width: 1.5),
        ),
        errorStyle: TextStyle(color: AppColors.error),
      ),
    );
  }
}

class _StatusField extends StatelessWidget {
  const _StatusField();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Initial Status',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          Row(
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.info.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.info,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Pending (0)',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.info,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.lock_outline, size: 16, color: AppColors.mutedLight),
            ],
          ),
        ],
      ),
    );
  }
}
