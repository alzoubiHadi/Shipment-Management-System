<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Truck extends Model
{
    use SoftDeletes;

    protected $fillable = [
        'truck_number',
        'truck_type',
        'max_load',
        'length',
        'width',
        'height',
        'has_refrigeration',
        'permit_type',
        'permit_expiry',
        'insurance_expiry',
        'license_expiry',
        'default_driver_id',
        'is_active',
    ];

    protected $casts = [
        'has_refrigeration' => 'boolean',
        'is_active' => 'boolean',
        'permit_expiry' => 'date',
        'insurance_expiry' => 'date',
        'license_expiry' => 'date',
    ];

    public function defaultDriver()
    {
        return $this->belongsTo(Driver::class, 'default_driver_id');
    }

    public function shipments()
    {
        return $this->hasMany(Shipment::class);
    }

    /**
     * A truck is currently eligible for a new job if it is active and all of
     * its permits / insurance / registration are still valid.
     */
    public function isRoadworthy(): bool
    {
        $today = now()->toDateString();

        if (! $this->is_active) {
            return false;
        }

        if ($this->insurance_expiry && $this->insurance_expiry->isPast()) {
            return false;
        }

        if ($this->license_expiry && $this->license_expiry->isPast()) {
            return false;
        }

        return true;
    }
}
