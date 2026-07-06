import 'package:flutter/material.dart';

import '../API/CompanyService.dart';
import '../API/ShipmentOfferService.dart';
import '../API/config.dart';
import '../models/Company.dart';

/// Admin screen: logs an order that came in over phone / email / WhatsApp
/// as a shipment offer, which the system then matches against eligible
/// drivers automatically.
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
  final _requiredTruckTypeController = TextEditingController();
  final _priceToDriverController = TextEditingController();
  final _priceToClientController = TextEditingController();

  final _companyService = CompanyService();
  late Future<List<Company>> _companiesFuture;
  Company? _selectedCompany;

  String _cargoType = 'normal';
  bool _requiresCrossBorder = false;
  bool _isSaving = false;
  String? _errorMessage;

  static const _cargoTypes = ['normal', 'refrigerated', 'hazardous'];

  @override
  void initState() {
    super.initState();
    _companiesFuture = _companyService.fetchCompaines();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _weightController.dispose();
    _descriptionController.dispose();
    _requiredTruckTypeController.dispose();
    _priceToDriverController.dispose();
    _priceToClientController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCompany == null) {
      setState(() => _errorMessage = 'Please select a company');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final result = await ShipmentOfferService.createOffer(
      companyId: int.parse(_selectedCompany!.id),
      origin: _originController.text.trim(),
      destination: _destinationController.text.trim(),
      weight: _weightController.text.trim().isEmpty
          ? null
          : _weightController.text.trim(),
      description: _descriptionController.text.trim(),
      cargoType: _cargoType,
      requiresCrossBorder: _requiresCrossBorder,
      requiredTruckType: _requiredTruckTypeController.text.trim().isEmpty
          ? null
          : _requiredTruckTypeController.text.trim(),
      priceToDriver: _priceToDriverController.text.trim().isEmpty
          ? null
          : _priceToDriverController.text.trim(),
      priceToClient: _priceToClientController.text.trim().isEmpty
          ? null
          : _priceToClientController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result['success'] == true) {
      final count = result['eligible_drivers_count'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Offer created — $count eligible driver(s) right now'),
          backgroundColor: AppColors.success,
        ),
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

              // Company picker
              FutureBuilder<List<Company>>(
                future: _companiesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator(color: AppColors.gold),
                    );
                  }
                  final companies = snapshot.data ?? [];
                  return DropdownButtonFormField<Company>(
                    initialValue: _selectedCompany,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: AppColors.cream),
                    decoration: _decoration('Client company'),
                    items: companies
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c.name),
                            ))
                        .toList(),
                    onChanged: (c) => setState(() => _selectedCompany = c),
                  );
                },
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
              TextFormField(
                controller: _destinationController,
                style: const TextStyle(color: AppColors.cream),
                decoration: _decoration('Destination'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                initialValue: _cargoType,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: AppColors.cream),
                decoration: _decoration('Cargo type'),
                items: _cargoTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _cargoType = v ?? 'normal'),
              ),

              const SizedBox(height: 14),
              TextFormField(
                controller: _requiredTruckTypeController,
                style: const TextStyle(color: AppColors.cream),
                decoration: _decoration(
                    'Required truck type — optional (e.g. Reefer)'),
              ),

              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: SwitchListTile(
                  value: _requiresCrossBorder,
                  onChanged: (v) =>
                      setState(() => _requiresCrossBorder = v),
                  title: const Text(
                    'Crosses a border (GCC / Middle East)',
                    style: TextStyle(color: AppColors.cream, fontSize: 14),
                  ),
                  activeColor: AppColors.gold,
                ),
              ),

              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceToDriverController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.cream),
                      decoration: _decoration('Price to driver'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _priceToClientController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.cream),
                      decoration: _decoration('Price to client'),
                    ),
                  ),
                ],
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
