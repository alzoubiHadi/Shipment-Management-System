<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class ShipmentOffer extends Model
{
    use SoftDeletes;

    /**
     * status values: pending, awaiting_manual_price, accepted, expired,
     * cancelled. Kept as a plain string column (no DB enum) so this new
     * value needed no schema change — see the 2026_08_15_000109 migration.
     */
    const STATUS_AWAITING_MANUAL_PRICE = 'awaiting_manual_price';

    protected $fillable = [
        'company_id',
        'tracking_number',
        'origin',
        'origin_lat',
        'origin_lng',
        'origin_country',
        'origin_city',
        'origin_zone_id',
        'origin_address',
        'destination',
        'destination_lat',
        'destination_lng',
        'destination_country',
        'destination_city',
        'destination_zone_id',
        'destination_address',
        'weight',
        'description',
        'needs_permit',
        'is_hazardous',
        'is_fragile',
        'order_type',
        'required_truck_type',
        'price_to_driver',
        'price_to_client',
        'pricing_mode',
        'priced_by_user_id',
        'platform_margin_percent_snapshot',
        // Zones / Smart Pricing Engine snapshot (2026-08-27) — see
        // 2026_08_27_000003_add_zone_pricing_fields_to_shipment_offers_table.php
        'pricing_reference',
        'pricing_low',
        'pricing_high',
        'pricing_confidence',
        'market_adjustment_snapshot',
        'pricing_level',
        'company_selected_price',
        'status',
        'financial_status',
        'cancellation_reason',
        'cancelled_by_user_id',
        'cancelled_at',
        'accepted_by_driver_id',
        'accepted_truck_id',
        'accepted_at',
        'expires_at',
        'matched_driver_ids',
        'matching_round',
    ];

    protected $casts = [
        'needs_permit' => 'boolean',
        'is_hazardous' => 'boolean',
        'is_fragile' => 'boolean',
        'accepted_at' => 'datetime',
        'expires_at' => 'datetime',
        'cancelled_at' => 'datetime',
        'platform_margin_percent_snapshot' => 'decimal:2',
        'origin_lat' => 'decimal:7',
        'origin_lng' => 'decimal:7',
        'destination_lat' => 'decimal:7',
        'destination_lng' => 'decimal:7',
        'matched_driver_ids' => 'array',
        'pricing_reference' => 'decimal:2',
        'pricing_low' => 'decimal:2',
        'pricing_high' => 'decimal:2',
        'market_adjustment_snapshot' => 'decimal:2',
        'company_selected_price' => 'decimal:2',
    ];

    public function company()
    {
        return $this->belongsTo(Company::class);
    }

    public function originZone()
    {
        return $this->belongsTo(Zone::class, 'origin_zone_id');
    }

    public function destinationZone()
    {
        return $this->belongsTo(Zone::class, 'destination_zone_id');
    }

    public function acceptedByDriver()
    {
        return $this->belongsTo(Driver::class, 'accepted_by_driver_id');
    }

    public function acceptedTruck()
    {
        return $this->belongsTo(Truck::class, 'accepted_truck_id');
    }

    public function pricedBy()
    {
        return $this->belongsTo(User::class, 'priced_by_user_id');
    }

    public function cancelledBy()
    {
        return $this->belongsTo(User::class, 'cancelled_by_user_id');
    }

    public function shipment()
    {
        return $this->hasOne(Shipment::class);
    }

    /** @return \Illuminate\Database\Eloquent\Relations\HasMany<ShipmentOfferMatchingRound> */
    public function matchingRounds()
    {
        return $this->hasMany(ShipmentOfferMatchingRound::class)->orderBy('round_number');
    }
}
