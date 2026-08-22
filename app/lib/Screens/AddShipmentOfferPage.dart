import 'package:flutter/material.dart';

import '../API/ShipmentOfferService.dart';
import '../API/config.dart';
import '../l10n/app_localizations.dart';
import 'register_shared.dart';

/// Company self-service screen (UC-11), redesigned as a light-themed
/// step-by-step wizard (2026-08-17 mockup — "Create Shipment").
///
/// Zones / Smart Pricing Engine (2026-08-27): origin/destination are now
/// collected as a Country -> City -> Zone cascade sourced from `GET /zones`
/// (see design doc points 4-13) instead of the old free-text/curated-list
/// pattern — this is what lets the backend resolve a historical-pricing
/// suggestion and a zone-aware driver match. order_type is no longer a
/// user toggle: it's derived automatically from comparing the two zones'
/// countries, same rule the server re-applies authoritatively in
/// ShipmentOfferController::create(), so nothing here needs to be trusted.
class AddShipmentOfferPage extends StatefulWidget {
  const AddShipmentOfferPage({super.key});

  @override
  State<AddShipmentOfferPage> createState() => _AddShipmentOfferPageState();
}

class _AddShipmentOfferPageState extends State<AddShipmentOfferPage> {
  final PageController _pageController = PageController();
  int _step = 0;
  static const int _totalSteps = 4;

  List<ZoneOption>? _zones;
  String? _zonesLoadError;

  // Pickup.
  String? _originCountry;
  String? _originCity;
  ZoneOption? _originZone;
  final _originAddressController = TextEditingController();

  // Drop-off.
  String? _destCountry;
  String? _destCity;
  ZoneOption? _destZone;
  final _destAddressController = TextEditingController();

  final _weightController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedTruckType;
  final _yourPriceController = TextEditingController();

  bool _needsPermit = false;
  bool _isHazardous = false;
  bool _isFragile = false;

  bool _isSaving = false;
  String? _errorMessage;

  // Pricing preview (Smart Pricing Engine) — re-fetched whenever both
  // zones + truck type are known. Null = not fetched yet for the current
  // combination; the request itself is tracked so the UI can show a
  // spinner without re-triggering on every rebuild.
  Map<String, dynamic>? _pricingSuggestion;
  bool _pricingLoading = false;
  String? _pricingFetchKey;

  List<String> _stepTitles(AppLocalizations t) => [
        t.addShipmentStepRoute,
        t.addShipmentStepCargo,
        t.addShipmentStepTruckPricing,
        t.addShipmentStepReview,
      ];
  List<String> _stepSubtitles(AppLocalizations t) => [
        t.addShipmentSubtitleRoute,
        t.addShipmentSubtitleCargo,
        t.addShipmentSubtitleTruckPricing,
        t.addShipmentSubtitleReview,
      ];

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  Future<void> _loadZones() async {
    try {
      final zones = await ShipmentOfferService.fetchZones();
      if (!mounted) return;
      setState(() => _zones = zones);
    } catch (e) {
      if (!mounted) return;
      final t = AppLocalizations.of(context)!;
      setState(() => _zonesLoadError = t.addShipmentFailedToLoadZones(e.toString()));
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _originAddressController.dispose();
    _destAddressController.dispose();
    _weightController.dispose();
    _descriptionController.dispose();
    _yourPriceController.dispose();
    super.dispose();
  }

  // ── Derived data from the flat zones list ───────────────────────────

  List<String> get _countries {
    final set = <String>{};
    for (final z in _zones ?? const <ZoneOption>[]) {
      set.add(z.country);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<String> _citiesFor(String? country) {
    if (country == null) return const [];
    final set = <String>{};
    for (final z in _zones ?? const <ZoneOption>[]) {
      if (z.country == country && z.city != null && z.city!.isNotEmpty) set.add(z.city!);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<ZoneOption> _zonesFor(String? country, String? city) {
    if (country == null || city == null) return const [];
    return (_zones ?? const <ZoneOption>[]).where((z) => z.country == country && z.city == city).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  String? get _orderType {
    if (_originCountry == null || _destCountry == null) return null;
    return _originCountry == _destCountry ? 'internal' : 'external';
  }

  String get _origin => _originZone == null ? '' : '${_originZone!.name}, ${_originCity ?? ''}, ${_originCountry ?? ''}';
  String get _destination => _destZone == null ? '' : '${_destZone!.name}, ${_destCity ?? ''}, ${_destCountry ?? ''}';

  String get _pricingKey => '${_originZone?.id}-${_destZone?.id}-${_selectedTruckType ?? ''}';

  Future<void> _maybeFetchPricingPreview() async {
    if (_originZone == null || _destZone == null || _selectedTruckType == null) return;
    final key = _pricingKey;
    if (key == _pricingFetchKey) return; // already fetched (or in flight) for this exact combination

    _pricingFetchKey = key;
    setState(() {
      _pricingLoading = true;
      _pricingSuggestion = null;
    });

    final result = await ShipmentOfferService.fetchPricingPreview(
      originZoneId: _originZone!.id,
      destinationZoneId: _destZone!.id,
      requiredTruckType: _selectedTruckType!,
    );

    if (!mounted || key != _pricingFetchKey) return; // stale response from a since-changed selection
    setState(() {
      _pricingLoading = false;
      _pricingSuggestion = result;
      if (result['success'] == true && result['matched'] == true) {
        final suggested = (result['suggested_price'] as num?)?.toDouble();
        if (suggested != null) _yourPriceController.text = suggested.toStringAsFixed(0);
      } else {
        _yourPriceController.clear();
      }
    });
  }

  String? _validateStep(AppLocalizations t, int step) {
    switch (step) {
      case 0:
        if (_originZone == null) return t.addShipmentSelectPickupZone;
        if (_destZone == null) return t.addShipmentSelectDropoffZone;
        return null;
      case 1:
        if (_weightController.text.trim().isNotEmpty && double.tryParse(_weightController.text.trim()) == null) {
          return t.addShipmentWeightMustBeNumber;
        }
        return null;
      case 2:
        if (_selectedTruckType == null) return t.addShipmentSelectTruckTypeRequired;
        return null;
      default:
        return null;
    }
  }

  void _next() {
    final t = AppLocalizations.of(context)!;
    if (_step == _totalSteps - 1) {
      _submit();
      return;
    }
    final error = _validateStep(t, _step);
    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }
    setState(() => _errorMessage = null);
    if (_step == 1) {
      // Entering the Truck & Pricing step — kick off a preview fetch as
      // soon as the truck type is already known from a previous visit.
      _maybeFetchPricingPreview();
    }
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
    final t = AppLocalizations.of(context)!;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final matched = _pricingSuggestion?['success'] == true && _pricingSuggestion?['matched'] == true;
    final yourPrice = matched ? double.tryParse(_yourPriceController.text.trim()) : null;

    try {
      final result = await ShipmentOfferService.createOffer(
        origin: _origin,
        destination: _destination,
        weight: _weightController.text.trim().isEmpty ? null : _weightController.text.trim(),
        description: _descriptionController.text.trim(),
        needsPermit: _needsPermit,
        isHazardous: _isHazardous,
        isFragile: _isFragile,
        orderType: _orderType ?? 'internal',
        requiredTruckType: _selectedTruckType!,
        originCountry: _originCountry,
        originCity: _originCity,
        originZoneId: _originZone?.id,
        originAddress: _originAddressController.text.trim().isEmpty ? null : _originAddressController.text.trim(),
        destinationCountry: _destCountry,
        destinationCity: _destCity,
        destinationZoneId: _destZone?.id,
        destinationAddress: _destAddressController.text.trim().isEmpty ? null : _destAddressController.text.trim(),
        companySelectedPrice: yourPrice,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final status = result['offer']?['status'];
        final message = status == 'awaiting_manual_price'
            ? t.addShipmentSuccessNoAutoPrice
            : t.addShipmentSuccessMatching;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: LightColors.success),
        );
        Navigator.pop(context, true);
      } else {
        setState(() => _errorMessage = result['message']?.toString());
      }
    } on Exception catch (e) {
      if (mounted) setState(() => _errorMessage = t.addShipmentSomethingWentWrong(e.toString()));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: LightColors.textPrimary), onPressed: _back),
        title: Text(t.addShipmentTitle,
            style: const TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: _zones == null ? _loadingOrErrorBody(t) : _wizardBody(t),
      ),
    );
  }

  Widget _loadingOrErrorBody(AppLocalizations t) {
    if (_zonesLoadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LightErrorBanner(message: _zonesLoadError!),
              const SizedBox(height: 16),
              LightPrimaryButton(
                label: t.commonRetry,
                onPressed: () => setState(() {
                  _zonesLoadError = null;
                  _loadZones();
                }),
              ),
            ],
          ),
        ),
      );
    }
    return const Center(child: CircularProgressIndicator(color: LightColors.gold));
  }

  Widget _wizardBody(AppLocalizations t) {
    return Column(
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
              _pageScaffold(t, 0, [_routeStep(t)]),
              _pageScaffold(t, 1, [_cargoStep(t)]),
              _pageScaffold(t, 2, [_truckAndPricingStep(t)]),
              _pageScaffold(t, 3, [_reviewStep(t)]),
            ],
          ),
        ),
        _bottomBar(t),
      ],
    );
  }

  Widget _pageScaffold(AppLocalizations t, int stepIndex, List<Widget> children) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_stepTitles(t)[stepIndex],
              style: const TextStyle(color: LightColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(_stepSubtitles(t)[stepIndex], style: const TextStyle(color: LightColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _bottomBar(AppLocalizations t) {
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
            label: _step == _totalSteps - 1 ? t.addShipmentCreateOfferButton : t.commonNext,
            loading: _isSaving,
            onPressed: _next,
          ),
        ],
      ),
    );
  }

  // ── Step 1: Route ────────────────────────────────────────────────────

  Widget _routeStep(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_orderType != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: LightColors.navy.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_orderType == 'internal' ? Icons.map_outlined : Icons.flight_takeoff_outlined, size: 15, color: LightColors.navy),
                const SizedBox(width: 6),
                Text(
                  _orderType == 'internal' ? t.addShipmentDomestic : t.addShipmentCrossBorder,
                  style: const TextStyle(color: LightColors.navy, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(t.addShipmentPickupLabel, style: const TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _zoneCascadePicker(
          t,
          countryLabel: t.addShipmentPickupCountry,
          cityLabel: t.addShipmentPickupCity,
          zoneLabel: t.addShipmentPickupZone,
          country: _originCountry,
          city: _originCity,
          zone: _originZone,
          onCountrySelected: (v) => setState(() {
            _originCountry = v;
            _originCity = null;
            _originZone = null;
          }),
          onCitySelected: (v) => setState(() {
            _originCity = v;
            _originZone = null;
          }),
          onZoneSelected: (v) => setState(() => _originZone = v),
        ),
        const SizedBox(height: 10),
        buildLightTextField(
          controller: _originAddressController,
          label: t.addShipmentPickupAddressOptional,
          hint: t.addShipmentAddressHint,
        ),
        const SizedBox(height: 20),
        Text(t.addShipmentDropoffLabel, style: const TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _zoneCascadePicker(
          t,
          countryLabel: t.addShipmentDropoffCountry,
          cityLabel: t.addShipmentDropoffCity,
          zoneLabel: t.addShipmentDropoffZone,
          country: _destCountry,
          city: _destCity,
          zone: _destZone,
          onCountrySelected: (v) => setState(() {
            _destCountry = v;
            _destCity = null;
            _destZone = null;
          }),
          onCitySelected: (v) => setState(() {
            _destCity = v;
            _destZone = null;
          }),
          onZoneSelected: (v) => setState(() => _destZone = v),
        ),
        const SizedBox(height: 10),
        buildLightTextField(
          controller: _destAddressController,
          label: t.addShipmentDropoffAddressOptional,
          hint: t.addShipmentAddressHint,
        ),
      ],
    );
  }

  // Country -> City -> Zone cascade, all sourced from the real zones list
  // (GET /zones) rather than free text — see design doc points 4-13.
  Widget _zoneCascadePicker(
    AppLocalizations t, {
    required String countryLabel,
    required String cityLabel,
    required String zoneLabel,
    required String? country,
    required String? city,
    required ZoneOption? zone,
    required ValueChanged<String> onCountrySelected,
    required ValueChanged<String> onCitySelected,
    required ValueChanged<ZoneOption> onZoneSelected,
  }) {
    final cities = _citiesFor(country);
    final zoneOptions = _zonesFor(country, city);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LightPickerField(
          label: countryLabel,
          value: country,
          hint: t.addShipmentSelectCountry,
          icon: Icons.public_outlined,
          onTap: () => _pickFromStrings(
            title: countryLabel,
            options: _countries,
            selected: country,
            onSelected: onCountrySelected,
          ),
        ),
        const SizedBox(height: 12),
        LightPickerField(
          label: cityLabel,
          value: city,
          hint: country == null ? t.addShipmentSelectCountryFirst : t.addShipmentSelectCity,
          icon: Icons.location_city_outlined,
          onTap: country == null
              ? () {}
              : () => _pickFromStrings(
                    title: cityLabel,
                    options: cities,
                    selected: city,
                    onSelected: onCitySelected,
                  ),
        ),
        const SizedBox(height: 12),
        LightPickerField(
          label: zoneLabel,
          value: zone?.name,
          hint: city == null ? t.addShipmentSelectCityFirst : t.addShipmentSelectZone,
          icon: Icons.pin_drop_outlined,
          onTap: city == null
              ? () {}
              : () => _pickZone(
                    t,
                    title: zoneLabel,
                    options: zoneOptions,
                    selected: zone,
                    onSelected: onZoneSelected,
                  ),
        ),
      ],
    );
  }

  // ── Step 2: Cargo Details ────────────────────────────────────────────

  Widget _cargoStep(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildLightTextField(
          controller: _weightController,
          label: t.addShipmentWeightKg,
          hint: t.commonOptional,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        buildLightTextField(
          controller: _descriptionController,
          label: t.addShipmentCargoDescription,
          hint: t.addShipmentCargoDescriptionHint,
          maxLines: 3,
        ),
      ],
    );
  }

  // ── Step 3: Truck & Pricing ───────────────────────────────────────────

  Widget _truckAndPricingStep(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LightPickerField(
          label: t.addShipmentRequiredTruckType,
          value: _selectedTruckType,
          hint: t.addShipmentSelectTruckType,
          icon: Icons.local_shipping_outlined,
          onTap: () => _pickFromStrings(
            title: t.addShipmentRequiredTruckType,
            options: kTruckTypes,
            selected: _selectedTruckType,
            onSelected: (v) {
              setState(() => _selectedTruckType = v);
              _maybeFetchPricingPreview();
            },
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(color: LightColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: LightColors.border)),
          child: Column(
            children: [
              _switchTile(t.addShipmentRequiresPermit, _needsPermit, (v) => setState(() => _needsPermit = v)),
              const Divider(height: 1, color: LightColors.border),
              _switchTile(t.addShipmentHazardousCargo, _isHazardous, (v) => setState(() => _isHazardous = v)),
              const Divider(height: 1, color: LightColors.border),
              _switchTile(t.addShipmentFragileCargo, _isFragile, (v) => setState(() => _isFragile = v)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(t.addShipmentPricingLabel, style: const TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _pricingCard(t),
      ],
    );
  }

  Widget _pricingCard(AppLocalizations t) {
    if (_selectedTruckType == null || _originZone == null || _destZone == null) {
      return _infoBanner(t.addShipmentPricingSelectPrompt);
    }
    if (_pricingLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(color: LightColors.gold)),
      );
    }
    final suggestion = _pricingSuggestion;
    if (suggestion == null) {
      return _infoBanner(t.addShipmentPricingNotLoaded);
    }
    if (suggestion['success'] != true || suggestion['matched'] != true) {
      return _infoBanner(t.addShipmentPricingNoHistorical);
    }

    final reference = (suggestion['reference_price'] as num?)?.toDouble();
    final low = (suggestion['suggested_low'] as num?)?.toDouble();
    final high = (suggestion['suggested_high'] as num?)?.toDouble();
    final confidence = suggestion['confidence']?.toString();
    final sampleSize = suggestion['sample_size'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: LightColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: LightColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph_outlined, size: 16, color: LightColors.gold),
              const SizedBox(width: 6),
              Text(t.addShipmentHistoricalReference(reference != null ? 'AED ${reference.toStringAsFixed(0)}' : '—'),
                  style: const TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (confidence != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: LightColors.gold.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text(confidence, style: const TextStyle(color: LightColors.goldMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          if (low != null && high != null) ...[
            const SizedBox(height: 4),
            Text(
                t.addShipmentTypicalRange(
                    'AED ${low.toStringAsFixed(0)} – ${high.toStringAsFixed(0)}${sampleSize != null ? ' (${t.addShipmentPastTrips(sampleSize is int ? sampleSize : int.tryParse(sampleSize.toString()) ?? 0)})' : ''}'),
                style: const TextStyle(color: LightColors.textSecondary, fontSize: 12)),
          ],
          const SizedBox(height: 14),
          buildLightTextField(
            controller: _yourPriceController,
            label: t.addShipmentYourPriceLabel,
            hint: t.addShipmentYourPriceHint,
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  Widget _infoBanner(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: LightColors.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: LightColors.border)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: LightColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: LightColors.textSecondary, fontSize: 12.5))),
        ],
      ),
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

  Widget _reviewStep(AppLocalizations t) {
    final matched = _pricingSuggestion?['success'] == true && _pricingSuggestion?['matched'] == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: LightColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: LightColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _reviewRow(t.addShipmentReviewType,
              _orderType == 'internal' ? t.addShipmentDomesticShort : (_orderType == 'external' ? t.addShipmentCrossBorderShort : '—')),
          _reviewRow(t.addShipmentReviewOrigin, _origin.isEmpty ? '—' : _origin),
          _reviewRow(t.addShipmentReviewDestination, _destination.isEmpty ? '—' : _destination),
          _reviewRow(t.addShipmentReviewWeight, _weightController.text.trim().isEmpty ? '—' : '${_weightController.text.trim()} kg'),
          _reviewRow(t.addShipmentReviewDescription, _descriptionController.text.trim().isEmpty ? '—' : _descriptionController.text.trim()),
          _reviewRow(t.addShipmentReviewTruckType, _selectedTruckType ?? '—'),
          _reviewRow(t.addShipmentReviewSpecialPermit, _needsPermit ? t.commonYes : t.commonNo),
          _reviewRow(t.addShipmentReviewHazardous, _isHazardous ? t.commonYes : t.commonNo),
          _reviewRow(t.addShipmentReviewFragile, _isFragile ? t.commonYes : t.commonNo),
          _reviewRow(t.addShipmentReviewYourPrice,
              matched && _yourPriceController.text.trim().isNotEmpty ? 'AED ${_yourPriceController.text.trim()}' : t.addShipmentSetByCrm),
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

  // ── Shared picker sheets ─────────────────────────────────────────────

  Future<void> _pickFromStrings({
    required String title,
    required List<String> options,
    required String? selected,
    required ValueChanged<String> onSelected,
  }) async {
    final t = AppLocalizations.of(context)!;
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
                alignment: AlignmentDirectional.centerStart,
                child: Text(title, style: const TextStyle(color: LightColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            Flexible(
              child: options.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(t.addShipmentNoOptionsAvailable, style: const TextStyle(color: LightColors.textSecondary)),
                    )
                  : ListView(
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

  Future<void> _pickZone(
    AppLocalizations t, {
    required String title,
    required List<ZoneOption> options,
    required ZoneOption? selected,
    required ValueChanged<ZoneOption> onSelected,
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
                alignment: AlignmentDirectional.centerStart,
                child: Text(title, style: const TextStyle(color: LightColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            Flexible(
              child: options.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(t.addShipmentNoZonesForCity, style: const TextStyle(color: LightColors.textSecondary)),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: options.map((o) {
                        final active = o.id == selected?.id;
                        return ListTile(
                          title: Text(o.name, style: TextStyle(color: active ? LightColors.goldMuted : LightColors.textPrimary, fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
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
