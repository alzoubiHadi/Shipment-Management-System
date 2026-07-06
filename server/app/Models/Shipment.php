<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Shipment extends Model
{
    use \Illuminate\Database\Eloquent\SoftDeletes;

    protected $fillable = [
        'shipment_offer_id',
        'company_id',
        'driver_id',
        'truck_id',
        'tracking_number',
        'origin',
        'destination',
        'weight',
        'description',
        'cargo_type',
        'price_to_driver',
        'price_to_client',
        'status',
        'cancellation_reason',
        'pickup_time',
        'delivered_at',
        'current_stage',
        'heading_to_pickup_at',
        'loaded_at',
        'departed_to_border_at',
        'border_cleared_at',
        'arrived_at_destination_at',
        'unloaded_at',
        'pod_signature',
        'pod_recipient_name',
    ];

    protected $casts = [
        'heading_to_pickup_at' => 'datetime',
        'loaded_at' => 'datetime',
        'departed_to_border_at' => 'datetime',
        'border_cleared_at' => 'datetime',
        'arrived_at_destination_at' => 'datetime',
        'unloaded_at' => 'datetime',
        'delivered_at' => 'datetime',
    ];

    /**
     * The 7-stage tracking timeline, in order. Stage 7 (delivered) is
     * handled separately by the deliver() endpoint because it requires a
     * proof-of-delivery signature rather than a plain timestamp.
     */
    const STAGE_LABELS = [
        1 => 'Heading to pickup',
        2 => 'Loaded',
        3 => 'En route to border',
        4 => 'Border cleared',
        5 => 'Arrived at destination',
        6 => 'Unloaded',
        7 => 'Delivered (signed)',
    ];

    const STAGE_COLUMNS = [
        1 => 'heading_to_pickup_at',
        2 => 'loaded_at',
        3 => 'departed_to_border_at',
        4 => 'border_cleared_at',
        5 => 'arrived_at_destination_at',
        6 => 'unloaded_at',
    ];

    public function company()
    {
        return $this->belongsTo(Company::class);
    }

    public function driver()
    {
        return $this->belongsTo(Driver::class);
    }

    public function truck()
    {
        return $this->belongsTo(Truck::class);
    }

    public function offer()
    {
        return $this->belongsTo(ShipmentOffer::class, 'shipment_offer_id');
    }
}
