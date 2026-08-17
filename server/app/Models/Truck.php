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
        'insurance_file_path',
        'license_expiry',
        'license_file_path',
        'technical_inspection_expiry',
        'technical_inspection_file_path',
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
        'technical_inspection_expiry' => 'date:Y-m-d',
    ];

    /**
     * has_refrigeration must never be set independently of truck_type — it
     * IS "truck_type === 'Reefer Trailer'" (see the refrigeration check in
     * suitabilityIssue() below). Before this hook, every creation path that
     * didn't explicitly pass has_refrigeration (registration's
     * Truck::create() being the main one) left it at the column default
     * (false), so a driver whose truck really was a Reefer Trailer would
     * still fail the "requires a refrigerated truck" check on offer
     * acceptance. Deriving it here, on every save, closes that gap for good
     * instead of just patching the one call site.
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
     * Full append-only document history (license/insurance/technical
     * inspection renewals) — see TruckDocument::STATUSES.
     */
    public function documents()
    {
        return $this->hasMany(TruckDocument::class);
    }

    public function currentDocuments()
    {
        return $this->documents()->where('is_current', true);
    }

    /**
     * A truck is currently eligible for a new job if it is active and all of
     * its permits / insurance / registration are still valid. Unlike driver
     * documents, a missing (null) expiry here is NOT a block — insurance and
     * technical inspection are optional at registration (see
     * UserController::register / TruckController::updateMyTruck) and can be
     * added later, so only an actually-expired date disqualifies the truck.
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

        if ($this->technical_inspection_expiry && $this->technical_inspection_expiry->isPast()) {
            return false;
        }

        return true;
    }

    /**
     * Single source of truth for "can this truck actually carry this
     * shipment offer" — roadworthy, correct type, refrigerated if the cargo
     * needs it, and enough payload capacity (max_load). Returns a
     * human-readable reason on failure, or null when the truck is fully
     * suitable. Used both as a hard filter in MatchingService (so an
     * unsuitable truck's driver never even sees/gets offered the job) and
     * as a final re-check at accept-time in ShipmentOfferController.
     */
    public function suitabilityIssue(ShipmentOffer $offer): ?string
    {
        if (! $this->isRoadworthy()) {
            return 'Truck is not roadworthy (inactive, expired insurance, license, or technical inspection)';
        }

        if ($offer->required_truck_type && $this->truck_type !== $offer->required_truck_type) {
            return 'Truck type does not match what this offer requires';
        }

        // Refrigeration is implied by required_truck_type = "Reefer Trailer"
        // (there is no separate cargo_type flag for it anymore) — this is
        // a defensive double-check in case a truck was mislabeled.
        if ($offer->required_truck_type === 'Reefer Trailer' && ! $this->has_refrigeration) {
            return 'This cargo requires a refrigerated truck';
        }

        if ($offer->weight !== null && $this->max_load !== null && (float) $offer->weight > (float) $this->max_load) {
            return 'This truck\'s payload capacity is not enough for this shipment';
        }

        return null;
    }

    public function isSuitableFor(ShipmentOffer $offer): bool
    {
        return $this->suitabilityIssue($offer) === null;
    }
}
