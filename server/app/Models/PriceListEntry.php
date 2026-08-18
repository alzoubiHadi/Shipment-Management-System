<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PriceListEntry extends Model
{
    protected $fillable = [
        // Legacy destination-string lookup — still supported for any row
        // seeded before Zones existed (2026_08_16_000105). New rows leave
        // these null; see PricingService::computeAutoPrice() (legacy) vs
        // getPriceSuggestion() (zone-based, current).
        'destination',
        'truck_type',
        'base_price',

        // Zone-based Smart Pricing Engine fields (2026-08-27) — see
        // 2026_08_27_000004_add_zone_fields_to_price_list_entries_table.php
        'origin_zone_id',
        'destination_zone_id',
        'truck_size',
        'median_base_price',
        'median_charges',
        'reference_price',
        'suggested_low',
        'suggested_high',
        'historical_trip_count',
        'confidence',
        'market_adjustment_percent',
        'last_historical_date',
        'pricing_level',
        'is_active',
    ];

    protected $casts = [
        'base_price' => 'decimal:2',
        'median_base_price' => 'decimal:2',
        'median_charges' => 'decimal:2',
        'reference_price' => 'decimal:2',
        'suggested_low' => 'decimal:2',
        'suggested_high' => 'decimal:2',
        'market_adjustment_percent' => 'decimal:2',
        'last_historical_date' => 'date',
        'is_active' => 'boolean',
    ];

    public function originZone()
    {
        return $this->belongsTo(Zone::class, 'origin_zone_id');
    }

    public function destinationZone()
    {
        return $this->belongsTo(Zone::class, 'destination_zone_id');
    }

    /**
     * Reference price after applying this lane's admin-controlled market
     * adjustment — the number PricingService::getPriceSuggestion() actually
     * shows the company as "Suggested Price". See the design doc's point
     * 12/33: the historical reference itself is never edited, only this
     * adjustment on top of it.
     */
    public function adjustedSuggestedPrice(): ?float
    {
        if ($this->reference_price === null) {
            return null;
        }

        $pct = (float) ($this->market_adjustment_percent ?? 0);

        return round((float) $this->reference_price * (1 + $pct / 100), 2);
    }
}
