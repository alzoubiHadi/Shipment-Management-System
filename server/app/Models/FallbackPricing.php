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
