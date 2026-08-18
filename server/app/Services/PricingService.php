<?php

namespace App\Services;

use App\Models\FallbackPricing;
use App\Models\PlatformSetting;
use App\Models\PriceListEntry;
use App\Models\Zone;

/**
 * UC-12: automatic price calculation. UC-13's manual-pricing fallback is
 * handled by the caller (ShipmentOfferController) when this returns null
 * or getPriceSuggestion() reports `matched => false` — there is simply no
 * pricing data to go on.
 */
class PricingService
{
    /**
     * LEGACY (pre-Zones): destination x truck_type -> base_price exact
     * lookup, used only by offers created before the Company Create-
     * Shipment flow collected structured origin/destination zones (no
     * origin_zone_id/destination_zone_id on the offer at all). New offers
     * go through getPriceSuggestion() below instead. Kept working as-is
     * so nothing that already depends on this behavior breaks.
     *
     * @return array{base_price: float, margin_percent: float, price_to_driver: float}|null
     */
    public function computeAutoPrice(string $destination, string $truckType): ?array
    {
        $entry = PriceListEntry::where('destination', $destination)
            ->where('truck_type', $truckType)
            ->first();

        if (! $entry) {
            return null;
        }

        $marginPercent = (float) PlatformSetting::get('profit_margin_percent', '20');
        $basePrice = (float) $entry->base_price;

        // Driver-visible price = base price minus the platform's margin.
        $priceToDriver = round($basePrice - ($basePrice * $marginPercent / 100), 2);

        return [
            'base_price' => $basePrice,
            'margin_percent' => $marginPercent,
            'price_to_driver' => $priceToDriver,
        ];
    }

    /**
     * Smart Pricing Engine (2026-08-27) — Zone-based pricing suggestion,
     * used both by the standalone pricing-preview endpoint (company sees
     * this before submitting) and by ShipmentOfferController::create()
     * (server always recomputes at submit time too — never trusts a
     * client-sent reference price).
     *
     * Lookup order:
     *   1. Exact lane: (origin_zone_id, destination_zone_id, truck_type)
     *      in price_list_entries. Reference price gets the lane's own
     *      admin-controlled market_adjustment_percent applied on top.
     *   2. Country fallback: (origin zone's country, destination zone's
     *      country, truck_type) in fallback_pricing — used when the exact
     *      zone pair has no history, or a zone id is missing entirely.
     *      No market adjustment applied here (see fallback_pricing's
     *      migration docblock for why).
     *   3. No match — the caller should fall back to the existing
     *      manual-pricing workflow (status = awaiting_manual_price).
     *
     * @return array{
     *     matched: bool,
     *     reference_price: ?float,
     *     expected_charges: ?float,
     *     suggested_price: ?float,
     *     suggested_low: ?float,
     *     suggested_high: ?float,
     *     confidence: ?string,
     *     sample_size: ?int,
     *     pricing_level: ?string,
     *     market_adjustment_percent: ?float,
     * }
     */
    public function getPriceSuggestion(?int $originZoneId, ?int $destinationZoneId, string $truckType): array
    {
        $empty = [
            'matched' => false,
            'reference_price' => null,
            'expected_charges' => null,
            'suggested_price' => null,
            'suggested_low' => null,
            'suggested_high' => null,
            'confidence' => null,
            'sample_size' => null,
            'pricing_level' => null,
            'market_adjustment_percent' => null,
        ];

        if ($originZoneId && $destinationZoneId) {
            $entry = PriceListEntry::where('origin_zone_id', $originZoneId)
                ->where('destination_zone_id', $destinationZoneId)
                ->where('truck_type', $truckType)
                ->where('is_active', true)
                ->first();

            if ($entry && $entry->reference_price !== null) {
                return [
                    'matched' => true,
                    'reference_price' => (float) $entry->reference_price,
                    'expected_charges' => $entry->median_charges !== null ? (float) $entry->median_charges : null,
                    'suggested_price' => $entry->adjustedSuggestedPrice(),
                    'suggested_low' => $entry->suggested_low !== null ? (float) $entry->suggested_low : null,
                    'suggested_high' => $entry->suggested_high !== null ? (float) $entry->suggested_high : null,
                    'confidence' => $entry->confidence,
                    'sample_size' => $entry->historical_trip_count,
                    'pricing_level' => $entry->pricing_level ?? 'exact_zone',
                    'market_adjustment_percent' => (float) $entry->market_adjustment_percent,
                ];
            }
        }

        // Fallback: need the zones' countries, not their ids.
        $originCountry = $originZoneId ? Zone::find($originZoneId)?->country : null;
        $destinationCountry = $destinationZoneId ? Zone::find($destinationZoneId)?->country : null;

        if ($originCountry && $destinationCountry) {
            $fallback = FallbackPricing::where('origin_country', $originCountry)
                ->where('destination_country', $destinationCountry)
                ->where('truck_type', $truckType)
                ->first();

            if ($fallback && $fallback->reference_price !== null) {
                return [
                    'matched' => true,
                    'reference_price' => (float) $fallback->reference_price,
                    'expected_charges' => null,
                    'suggested_price' => (float) $fallback->reference_price,
                    'suggested_low' => $fallback->typical_low !== null ? (float) $fallback->typical_low : null,
                    'suggested_high' => $fallback->typical_high !== null ? (float) $fallback->typical_high : null,
                    // Country-level fallback is inherently rougher than an
                    // exact zone-pair lane — never report it as High even
                    // if the underlying sample size happens to be large.
                    'confidence' => 'Medium',
                    'sample_size' => $fallback->historical_trip_count,
                    'pricing_level' => $fallback->pricing_level ?? 'country_fallback',
                    'market_adjustment_percent' => 0.0,
                ];
            }
        }

        return $empty;
    }
}
