<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * See 2026_08_27_000008_create_shipment_offer_driver_responses_table.php
 * for the full rationale — one row per (offer, driver) pairing ever
 * notified, tracking accept/decline/expire outcomes for future
 * acceptance-probability ranking.
 */
class ShipmentOfferDriverResponse extends Model
{
    const RESULT_PENDING = 'pending';
    const RESULT_ACCEPTED = 'accepted';
    const RESULT_DECLINED = 'declined';
    const RESULT_EXPIRED = 'expired';

    protected $fillable = [
        'shipment_offer_id',
        'driver_id',
        'matching_round',
        'matching_score',
        'price_to_driver_snapshot',
        'origin_zone_id',
        'destination_zone_id',
        'sent_at',
        'response_at',
        'result',
    ];

    protected $casts = [
        'matching_score' => 'decimal:4',
        'price_to_driver_snapshot' => 'decimal:2',
        'sent_at' => 'datetime',
        'response_at' => 'datetime',
    ];

    public function offer()
    {
        return $this->belongsTo(ShipmentOffer::class, 'shipment_offer_id');
    }

    public function driver()
    {
        return $this->belongsTo(Driver::class);
    }
}
