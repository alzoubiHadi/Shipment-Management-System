<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class ShipmentOffer extends Model
{
    use SoftDeletes;

    protected $fillable = [
        'company_id',
        'origin',
        'destination',
        'weight',
        'description',
        'cargo_type',
        'requires_cross_border',
        'required_truck_type',
        'price_to_driver',
        'price_to_client',
        'status',
        'cancellation_reason',
        'accepted_by_driver_id',
        'accepted_truck_id',
        'accepted_at',
    ];

    protected $casts = [
        'requires_cross_border' => 'boolean',
        'accepted_at' => 'datetime',
        'expires_at' => 'datetime',
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

    public function shipment()
    {
        return $this->hasOne(Shipment::class);
    }
}
