<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Driver extends Model
{
    //
    use SoftDeletes;
    protected $fillable = [
        'name',
        'phone',
        'truck_number',
        'truck_type',
        'nationality',
        'age',
        'driver_license',
        'license_expiry',
        'user_id',
        'employment_type',
        'status',
        'residency_expiry',
        'passport_expiry',
        'blood_type',
    ];

    protected $casts = [
        'license_expiry' => 'date',
        'residency_expiry' => 'date',
        'passport_expiry' => 'date',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function trucks()
    {
        return $this->hasMany(Truck::class, 'default_driver_id');
    }

    public function shipments()
    {
        return $this->hasMany(Shipment::class);
    }

    /**
     * A driver is eligible to be offered a new job if they are currently
     * marked available and none of their required documents have expired.
     */
    public function isEligibleForNewJob(): bool
    {
        if ($this->status !== 'available') {
            return false;
        }

        $today = now()->toDateString();

        if ($this->license_expiry && $this->license_expiry->isPast()) {
            return false;
        }

        if ($this->passport_expiry && $this->passport_expiry->isPast()) {
            return false;
        }

        if ($this->residency_expiry && $this->residency_expiry->isPast()) {
            return false;
        }

        return true;
    }

    /**
     * For international (cross-border) offers the driver's residency must
     * still have at least 3 months left when entering another country.
     */
    public function meetsCrossBorderResidencyRule(): bool
    {
        if (! $this->residency_expiry) {
            return false;
        }

        return $this->residency_expiry->greaterThanOrEqualTo(now()->addMonths(3));
    }
}
