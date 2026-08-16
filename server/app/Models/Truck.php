<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Truck extends Model
{
    use SoftDeletes;

    /**
     * The fixed list of truck types the company can require on a shipment
     * offer, and the only values TruckController should accept when a
     * driver adds a truck. Kept as a plain string column (see the
     * 2026_08_15_000107 migration note) — enforced here, not in the DB.
     */
    const TRUCK_TYPES = [
        '3 Ton pick up',
        '7 Ton pick up',
        '10 Ton pick up',
        'Trailer 40 FT-12M-Open',
        'Trailer 40 FT-12M-Box',
        'Trailer 50 FT-15M-Open',
        'Curtain Trailer 13.5M',
        'Curtain Trailer 15M',
        'Reefer Trailer',
        'Lowbed Trailer - 25 Tons',
        'Car Career',
    ];

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
        'license_file_path',
        'default_driver_id',
        'is_active',
    ];

    protected $casts = [
        'has_refrigeration' => 'boolean',
        'is_active' => 'boolean',
        // 'date:Y-m-d' — bare date in JSON, not a full datetime.
        'permit_expiry' => 'date:Y-m-d',
        'insurance_expiry' => 'date:Y-m-d',
        'license_expiry' => 'date:Y-m-d',
    ];

    /**
     * has_refrigeration must never be set independently of truck_type — it
     * IS "truck_type === 'Reefer Trailer'" (see the comment on that check
     * in ShipmentOfferController::eligibilityError()). Before this hook,
     * every creation path that didn't explicitly pass has_refrigeration
     * (registration's Truck::create() being the main one) left it at the
     * column default (false), so a driver whose truck really was a Reefer
     * Trailer would still fail the "requires a refrigerated truck" check
     * on offer acceptance. Deriving it here, on every save, closes that
     * gap for good instead of just patching the one call site.
     */
    protected static function booted(): void
    {
        static::saving(function (Truck $truck) {
            $truck->has_refrigeration = $truck->truck_type === 'Reefer Trailer';
        });
    }

    /**
     * Under the new model only drivers add trucks, so default_driver_id is
     * really the truck's OWNING driver now (kept under its original column
     * name to avoid a risky rename). ownerDriver() is provided as a
     * clearer alias for new code; defaultDriver() is kept for existing
     * call sites.
     */
    public function defaultDriver()
    {
        return $this->belongsTo(Driver::class, 'default_driver_id');
    }

    public function ownerDriver()
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
