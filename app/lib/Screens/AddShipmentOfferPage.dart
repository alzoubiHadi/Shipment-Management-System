import 'package:flutter/material.dart';

import '../API/ShipmentOfferService.dart';
import '../API/config.dart';

/// Company self-service screen (UC-11): the company creates its own
/// shipment offer directly — no admin middleman, no company picker (the
/// backend resolves the company from the logged-in user), and no manual
/// price fields (pricing is computed automatically from the central price
/// list, or the offer waits for CRM Admin to set one).
class AddShipmentOfferPage extends StatefulWidget {
  const AddShipmentOfferPage({super.key});

  @override
  State<AddShipmentOfferPage> createState() => _AddShipmentOfferPageState();
}

class _AddShipmentOfferPageState extends State<AddShipmentOfferPage> {
  final _formKey = GlobalKey<FormState>();

  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _weightController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _orderType = 'internal'; // 'internal' or 'external'
  String? _selectedExternalDestination;
  String? _selectedTruckType;

  bool _needsPermit = false;
  bool _isHazardous = false;
  bool _isFragile = false;

  bool _isSaving = false;
  String? _errorMessage;

  late Future<List<String>> _destinationsFuture;

  @override
  void initState() {
    super.initState();
    _destinationsFuture = ShipmentOfferService.fetchExternalDestinations();
  }

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

    if (_selectedTruckType == null) {
      setState(() => _errorMessage = 'Please select a required truck type');
      return;
    }

    final destination = _orderType == 'external'
        ? (_selectedExternalDestination ?? '')
        : _destinationController.text.trim();

    if (destination.isEmpty) {
      setState(() => _errorMessage = 'Please select or enter a destination');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final result = await ShipmentOfferService.createOffer(
      origin: _originController.text.trim(),
      destination: destination,
      weight: _weightController.text.trim().isEmpty
          ? null
          : _weightController.text.trim(),
      description: _descriptionController.text.trim(),
      needsPermit: _needsPermit,
      isHazardous: _isHazardous,
      isFragile: _isFragile,
      orderType: _orderType,
      requiredTruckType: _selectedTruckType!,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result['success'] == true) {
      final status = result['offer']?['status'];
      final message = status == 'awaiting_manual_price'
          ? 'Offer created — no automatic price found, CRM will set one shortly'
          : 'Offer created — matching drivers now';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.success),
      );
      Navigator.pop(context, true);
    } else {
      setState(() => _errorMessage = result['message']?.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.cream),
        title: const Text(
          'New Shipment Offer',
          style: TextStyle(color: AppColors.cream),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: AppColors.error.withOpacity(0.4)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style:
                        const TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ),
              ],

              // Internal vs. external order type
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _orderTypeTab('internal', 'Internal (KSA)'),
                    ),
                    Expanded(
                      child: _orderTypeTab('external', 'External (Cross-border)'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              TextFormField(
                controller: _originController,
                style: const TextStyle(color: AppColors.cream),
                decoration: _decoration('Origin'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),

              const SizedBox(height: 14),
              if (_orderType == 'external')
                FutureBuilder<List<String>>(
                  future: _destinationsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(color: AppColors.gold),
                      );
                    }
                    final destinations = snapshot.data ?? [];
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedExternalDestination,
                      dropdownColor: AppColors.surface,
                      style: const TextStyle(color: AppColors.cream),
                      decoration: _decoration('Destination'),
                      items: destinations
                          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedExternalDestination = v),
                    );
                  },
                )
              else
                TextFormField(
                  controller: _destinationController,
                  style: const TextStyle(color: AppColors.cream),
                  decoration: _decoration('Destination'),
                  validator: (v) => _orderType == 'internal' &&
                          (v == null || v.trim().isEmpty)
                      ? 'Required'
                      : null,
                ),

              const SizedBox(height: 14),
              TextFormField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.cream),
                decoration: _decoration('Weight (kg) — optional'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                style: const TextStyle(color: AppColors.cream),
                decoration: _decoration('Description — optional'),
              ),

              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _selectedTruckType,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: AppColors.cream),
                decoration: _decoration('Required truck type'),
                items: kTruckTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedTruckType = v),
              ),

              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _needsPermit,
                      onChanged: (v) => setState(() => _needsPermit = v),
                      title: const Text('Requires special permit',
                          style: TextStyle(
                              color: AppColors.cream, fontSize: 14)),
                      activeColor: AppColors.gold,
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    SwitchListTile(
                      value: _isHazardous,
                      onChanged: (v) => setState(() => _isHazardous = v),
                      title: const Text('Hazardous cargo',
                          style: TextStyle(
                              color: AppColors.cream, fontSize: 14)),
                      activeColor: AppColors.gold,
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    SwitchListTile(
                      value: _isFragile,
                      onChanged: (v) => setState(() => _isFragile = v),
                      title: const Text('Fragile cargo',
                          style: TextStyle(
                              color: AppColors.cream, fontSize: 14)),
                      activeColor: AppColors.gold,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.bg,
                          ),
                        )
                      : const Text(
                          'Create Offer',
                          style: TextStyle(
                            color: AppColors.bg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orderTypeTab(String value, String label) {
    final selected = _orderType == value;
    return InkWell(
      onTap: () => setState(() {
        _orderType = value;
        _errorMessage = null;
      }),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? AppColors.bg : AppColors.muted,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.gold),
      ),
    );
  }
}
