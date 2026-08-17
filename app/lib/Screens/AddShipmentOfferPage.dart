import 'package:flutter/material.dart';

import '../API/ShipmentOfferService.dart';
import '../API/config.dart';
import '../utils/countries.dart';
import '../utils/ksa_locations.dart';
import 'register_shared.dart';

/// Company self-service screen (UC-11), redesigned as a light-themed
/// step-by-step wizard (2026-08-17 mockup — "Create Shipment", Phase 2 of
/// the company redesign) — this app's real creation flow is posting a
/// shipment OFFER (no admin middleman, no price fields, no company
/// picker), which only becomes a Shipment once a driver accepts it.
///
/// Scope note: the mockup's wizard shows 6 steps including Pickup/Delivery
/// Date & Time fields the backend doesn't collect (ShipmentOfferService.
/// createOffer has no date params). Rather than add UI for fields that go
/// nowhere, this reduces to 4 steps built from the fields that actually
/// exist on the offer — same call the user already made for the company
/// registration wizard ("4 fields, faster" over the fuller mockup).
class AddShipmentOfferPage extends StatefulWidget {
  const AddShipmentOfferPage({super.key});

  @override
  State<AddShipmentOfferPage> createState() => _AddShipmentOfferPageState();
}

class _AddShipmentOfferPageState extends State<AddShipmentOfferPage> {
  final PageController _pageController = PageController();
  int _step = 0;
  static const int _totalSteps = 4;

  // Pickup (2026-08-17 feedback: Country + City dropdowns instead of free
  // text). The company isn't tied to one home country, so Country offers
  // the full list; City is a real dropdown only for countries we have a
  // curated list for (see ksa_locations.dart), else a free-text fallback.
  String? _originCountry;
  String? _originCity;
  final _originCityFreeTextController = TextEditingController();

  // Drop-off for order_type == 'internal' (same Country + City pattern).
  // order_type == 'external' keeps its existing fixed-list dropdown below
  // (those exact strings must match the backend price matrix).
  String? _destCountry;
  String? _destCity;
  final _destCityFreeTextController = TextEditingController();

  final _weightController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _orderType = 'internal'; // 'internal' (domestic) or 'external' (cross-border)
  String? _selectedExternalDestination;
  String? _selectedTruckType;

  bool _needsPermit = false;
  bool _isHazardous = false;
  bool _isFragile = false;

  bool _isSaving = false;
  String? _errorMessage;

  late Future<List<String>> _destinationsFuture;

  static const _stepTitles = [
    'Route',
    'Cargo Details',
    'Truck & Requirements',
    'Review & Submit',
  ];
  static const _stepSubtitles = [
    'Where is this shipment going?',
    'Tell us what\'s being shipped',
    'What kind of truck does this need?',
    'Check everything before creating the offer',
  ];

  @override
  void initState() {
    super.initState();
    _destinationsFuture = ShipmentOfferService.fetchExternalDestinations();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _originCityFreeTextController.dispose();
    _destCityFreeTextController.dispose();
    _weightController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String get _origin {
    if (_originCountry == null) return '';
    final city = citiesFor(_originCountry) != null ? (_originCity ?? '') : _originCityFreeTextController.text.trim();
    if (city.isEmpty) return '';
    return '$city, $_originCountry';
  }

  String get _destination {
    if (_orderType == 'external') return _selectedExternalDestination ?? '';
    if (_destCountry == null) return '';
    final city = citiesFor(_destCountry) != null ? (_destCity ?? '') : _destCityFreeTextController.text.trim();
    if (city.isEmpty) return '';
    return '$city, $_destCountry';
  }

  String? _validateStep(int step) {
    switch (step) {
      case 0:
        if (_origin.isEmpty) return 'Please select the pickup country and city';
        if (_destination.isEmpty) return 'Please select or enter a destination';
        return null;
      case 1:
        if (_weightController.text.trim().isNotEmpty && double.tryParse(_weightController.text.trim()) == null) {
          return 'Weight must be a number';
        }
        return null;
      case 2:
        if (_selectedTruckType == null) return 'Please select a required truck type';
        return null;
      default:
        return null;
    }
  }

  void _next() {
    if (_step == _totalSteps - 1) {
      _submit();
      return;
    }
    final error = _validateStep(_step);
    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }
    setState(() => _errorMessage = null);
    _pageController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _errorMessage = null);
    _pageController.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _submit() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final result = await ShipmentOfferService.createOffer(
        origin: _origin,
        destination: _destination,
        weight: _weightController.text.trim().isEmpty ? null : _weightController.text.trim(),
        description: _descriptionController.text.trim(),
        needsPermit: _needsPermit,
        isHazardous: _isHazardous,
        isFragile: _isFragile,
        orderType: _orderType,
        requiredTruckType: _selectedTruckType!,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final status = result['offer']?['status'];
        final message = status == 'awaiting_manual_price'
            ? 'Offer created — no automatic price found, CRM will set one shortly'
            : 'Offer created — matching drivers now';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: LightColors.success),
        );
        Navigator.pop(context, true);
      } else {
        setState(() => _errorMessage = result['message']?.toString());
      }
    } on Exception catch (e) {
      if (mounted) setState(() => _errorMessage = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: LightColors.textPrimary), onPressed: _back),
        title: const Text('Create Shipment',
            style: TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: LightStepProgress(current: _step, total: _totalSteps),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _step = i),
                children: [
                  _pageScaffold(0, [_routeStep()]),
                  _pageScaffold(1, [_cargoStep()]),
                  _pageScaffold(2, [_truckStep()]),
                  _pageScaffold(3, [_reviewStep()]),
                ],
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _pageScaffold(int stepIndex, List<Widget> children) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_stepTitles[stepIndex],
              style: const TextStyle(color: LightColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(_stepSubtitles[stepIndex], style: const TextStyle(color: LightColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(color: LightColors.surface, border: Border(top: BorderSide(color: LightColors.border))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_errorMessage != null) ...[
            LightErrorBanner(message: _errorMessage!),
            const SizedBox(height: 10),
          ],
          LightPrimaryButton(
            label: _step == _totalSteps - 1 ? 'Create Offer' : 'Next',
            loading: _isSaving,
            onPressed: _next,
          ),
        ],
      ),
    );
  }

  // ── Step 1: Route ────────────────────────────────────────────────────

  Widget _routeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(color: LightColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: LightColors.border)),
          child: Row(
            children: [
              Expanded(child: _orderTypeTab('internal', 'Domestic')),
              Expanded(child: _orderTypeTab('external', 'Cross-border')),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Pickup', style: TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _countryCityPicker(
          countryLabel: 'Pickup Country',
          cityLabel: 'Pickup City',
          country: _originCountry,
          city: _originCity,
          freeTextController: _originCityFreeTextController,
          onCountrySelected: (v) => setState(() {
            _originCountry = v;
            _originCity = null;
            _originCityFreeTextController.clear();
          }),
          onCitySelected: (v) => setState(() => _originCity = v),
        ),
        const SizedBox(height: 20),
        const Text('Drop-off', style: TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (_orderType == 'external')
          FutureBuilder<List<String>>(
            future: _destinationsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(color: LightColors.gold),
                );
              }
              final destinations = snapshot.data ?? [];
              return LightPickerField(
                label: 'Destination',
                value: _selectedExternalDestination,
                hint: 'Select a destination',
                icon: Icons.flag_outlined,
                onTap: () => _pickFromList(
                  title: 'Destination',
                  options: destinations,
                  selected: _selectedExternalDestination,
                  onSelected: (v) => setState(() => _selectedExternalDestination = v),
                ),
              );
            },
          )
        else
          _countryCityPicker(
            countryLabel: 'Drop-off Country',
            cityLabel: 'Drop-off City',
            country: _destCountry,
            city: _destCity,
            freeTextController: _destCityFreeTextController,
            onCountrySelected: (v) => setState(() {
              _destCountry = v;
              _destCity = null;
              _destCityFreeTextController.clear();
            }),
            onCitySelected: (v) => setState(() => _destCity = v),
          ),
      ],
    );
  }

  // Shared Country dropdown (full kCountries list) + City field — a real
  // dropdown when we have a curated city list for the chosen country,
  // otherwise a free-text fallback (see ksa_locations.dart).
  Widget _countryCityPicker({
    required String countryLabel,
    required String cityLabel,
    required String? country,
    required String? city,
    required TextEditingController freeTextController,
    required ValueChanged<String> onCountrySelected,
    required ValueChanged<String> onCitySelected,
  }) {
    final curatedCities = citiesFor(country);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LightPickerField(
          label: countryLabel,
          value: country,
          hint: 'Select a country',
          icon: Icons.public_outlined,
          onTap: () => _pickFromList(
            title: countryLabel,
            options: kCountries.map((c) => c.name).toList(),
            selected: country,
            onSelected: onCountrySelected,
          ),
        ),
        const SizedBox(height: 12),
        if (curatedCities != null)
          LightPickerField(
            label: cityLabel,
            value: city,
            hint: 'Select a city',
            icon: Icons.location_city_outlined,
            onTap: () => _pickFromList(
              title: cityLabel,
              options: curatedCities,
              selected: city,
              onSelected: onCitySelected,
            ),
          )
        else
          buildLightTextField(
            controller: freeTextController,
            label: cityLabel,
            hint: country == null ? 'Select a country first' : 'Enter the city',
            enabled: country != null,
          ),
      ],
    );
  }

  Widget _orderTypeTab(String value, String label) {
    final selected = _orderType == value;
    return InkWell(
      onTap: () => setState(() => _orderType = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: selected ? LightColors.navy : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.center,
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(color: selected ? Colors.white : LightColors.textSecondary, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, fontSize: 13)),
      ),
    );
  }

  // ── Step 2: Cargo Details ────────────────────────────────────────────

  Widget _cargoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildLightTextField(
          controller: _weightController,
          label: 'Weight (kg)',
          hint: 'Optional',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        buildLightTextField(
          controller: _descriptionController,
          label: 'Cargo Description',
          hint: 'Optional — what\'s being shipped',
          maxLines: 3,
        ),
      ],
    );
  }

  // ── Step 3: Truck & Requirements ─────────────────────────────────────

  Widget _truckStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LightPickerField(
          label: 'Required Truck Type',
          value: _selectedTruckType,
          hint: 'Select a truck type',
          icon: Icons.local_shipping_outlined,
          onTap: () => _pickFromList(
            title: 'Required Truck Type',
            options: kTruckTypes,
            selected: _selectedTruckType,
            onSelected: (v) => setState(() => _selectedTruckType = v),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(color: LightColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: LightColors.border)),
          child: Column(
            children: [
              _switchTile('Requires special permit', _needsPermit, (v) => setState(() => _needsPermit = v)),
              const Divider(height: 1, color: LightColors.border),
              _switchTile('Hazardous cargo', _isHazardous, (v) => setState(() => _isHazardous = v)),
              const Divider(height: 1, color: LightColors.border),
              _switchTile('Fragile cargo', _isFragile, (v) => setState(() => _isFragile = v)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _switchTile(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(label, style: const TextStyle(color: LightColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
      activeColor: LightColors.gold,
    );
  }

  // ── Step 4: Review & Submit ──────────────────────────────────────────

  Widget _reviewStep() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: LightColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: LightColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _reviewRow('Type', _orderType == 'internal' ? 'Domestic' : 'Cross-border'),
          _reviewRow('Origin', _origin),
          _reviewRow('Destination', _destination),
          _reviewRow('Weight', _weightController.text.trim().isEmpty ? '—' : '${_weightController.text.trim()} kg'),
          _reviewRow('Description', _descriptionController.text.trim().isEmpty ? '—' : _descriptionController.text.trim()),
          _reviewRow('Truck Type', _selectedTruckType ?? '—'),
          _reviewRow('Special Permit', _needsPermit ? 'Yes' : 'No'),
          _reviewRow('Hazardous', _isHazardous ? 'Yes' : 'No'),
          _reviewRow('Fragile', _isFragile ? 'Yes' : 'No'),
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: LightColors.textSecondary, fontSize: 12.5))),
          Expanded(child: Text(value, style: const TextStyle(color: LightColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  // ── Shared picker sheet ──────────────────────────────────────────────

  Future<void> _pickFromList({
    required String title,
    required List<String> options,
    required String? selected,
    required ValueChanged<String> onSelected,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: LightColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title, style: const TextStyle(color: LightColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: options.map((o) {
                  final active = o == selected;
                  return ListTile(
                    title: Text(o, style: TextStyle(color: active ? LightColors.goldMuted : LightColors.textPrimary, fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
                    trailing: active ? const Icon(Icons.check, color: LightColors.gold) : null,
                    onTap: () {
                      onSelected(o);
                      Navigator.pop(ctx);
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
