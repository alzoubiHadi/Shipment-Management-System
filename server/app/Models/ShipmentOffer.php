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
        'origin',
        'origin_lat',
        'origin_lng',
        'destination',
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
        'status',
        'financial_status',
        'cancellation_reason',
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
        'platform_margin_percent_snapshot' => 'decimal:2',
        'origin_lat' => 'decimal:7',
        'origin_lng' => 'decimal:7',
        'matched_driver_ids' => 'array',
    ];

    public function company()
    {
        return $this->belongsTo(Company::class);
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

    public function shipment()
    {
        return $this->hasOne(Shipment::class);
    }
}
