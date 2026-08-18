<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class DriverDestination extends Model
{
    /**
     * Country-level dropdown shown at sign-up / in the driver's profile
     * (UC-3 / driver management). Coarser than the price-table's city-level
     * destinations (e.g. "Riyadh", "Jeddah/Madina/Mecca/Taif" both fall
     * under 'saudi_arabia' here) — the matching algorithm (Phase 4) is
     * responsible for mapping an offer's specific destination city to its
     * country to compare against this list.
     */
    const DESTINATIONS = [
        'internal_uae' => 'Internal (UAE)',
        'saudi_arabia' => 'Saudi Arabia',
        'oman' => 'Oman',
        'kuwait' => 'Kuwait',
        'bahrain' => 'Bahrain',
        'jordan' => 'Jordan',
        'lebanon' => 'Lebanon',
        'syria' => 'Syria',
        'egypt' => 'Egypt',
        'iraq' => 'Iraq',
        'yemen' => 'Yemen',
        // Added 2026-08-27 for Zones/Smart Pricing — the real historical
        // lane data (FMS_Pricing_Data_FINAL.xlsx) includes UAE<->Qatar
        // routes, which had no country key here at all before.
        'qatar' => 'Qatar',
    ];

    protected $fillable = [
        'driver_id',
        'destination',
    ];

    public function driver()
    {
        return $this->belongsTo(Driver::class);
    }
}
