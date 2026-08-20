<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Country-to-country x truck_type pricing used when no exact zone lane
 * exists in price_list_entries — see PricingService::getPriceSuggestion()
 * and 2026_08_27_000004_add_zone_fields_to_price_list_entries_table.php.
 */
class FallbackPricing extends Model
{
    // 2026-08-27 (test suite fix — real bug, not just a test issue): the
    // migration creates and seeds a table literally named `fallback_pricing`
    // (singular — see 2026_08_27_000004_add_zone_fields_to_price_list_entries_table.php
    // and 2026_08_27_000007_seed_fallback_pricing_from_pricing_data.php),
    // but this model never overrode Eloquent's default plural guess
    // (`fallback_pricings`), so every read here was hitting a table that
    // never existed. In production this meant PricingService::
    // getPriceSuggestion() threw a hard SQL error (not just returned "no
    // match") for any offer whose origin/destination zone pair isn't one
    // of the exact lanes in price_list_entries — i.e. every "fallback to
    // country-level pricing" case was actually broken, not just
    // unmatched. Caught here because it's the first time this project's
    // test suite has actually been run end-to-end.
    protected $table = 'fallback_pricing';

    protected $fillable = [
        'origin_country',
        'destination_country',
        'truck_type',
        'historical_trip_count',
        'median_total',
        'typical_low',
        'typical_high',
        'recent_90d_count',
        'recent_90d_median',
        'reference_price',
        'confidence',
        'pricing_level',
    ];

    protected $casts = [
        'median_total' => 'decimal:2',
        'typical_low' => 'decimal:2',
        'typical_high' => 'decimal:2',
        'recent_90d_median' => 'decimal:2',
        'reference_price' => 'decimal:2',
    ];
}
