<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Admin Shipments redesign (2026-08-24): one row per matching round of a
 * ShipmentOffer, written by MatchingService::matchNextBatch() — see that
 * table's migration docblock for why this exists (shipment_offers itself
 * only ever tracked the CURRENT round + a cumulative driver list, with no
 * per-round breakdown).
 */
class ShipmentOfferMatchingRound extends Model
{
    const OUTCOME_WAITING = 'waiting';

    const OUTCOME_NO_ACCEPTANCE = 'no_acceptance';

    const OUTCOME_ACCEPTED = 'accepted';

    const OUTCOME_ESCALATED = 'escalated';

    protected $fillable = [
        'shipment_offer_id',
        'round_number',
        'driver_ids',
        'notified_at',
        'outcome',
        'accepted_by_driver_id',
        'resolved_at',
    ];

    protected $casts = [
        'driver_ids' => 'array',
        'notified_at' => 'datetime',
        'resolved_at' => 'datetime',
    ];

    public function offer()
    {
        return $this->belongsTo(ShipmentOffer::class, 'shipment_offer_id');
    }

    public function acceptedByDriver()
    {
        return $this->belongsTo(Driver::class, 'accepted_by_driver_id');
    }
}
