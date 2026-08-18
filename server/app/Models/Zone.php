<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Canonical pickup/drop-off area (e.g. "JAFZA", "Dubai, UAE"). See
 * 2026_08_27_000001_create_zones_table.php for the full rationale.
 */
class Zone extends Model
{
    protected $fillable = [
        'country',
        'city',
        'name',
        'zone_type',
        'latitude',
        'longitude',
        'is_active',
    ];

    protected $casts = [
        'latitude' => 'decimal:7',
        'longitude' => 'decimal:7',
        'is_active' => 'boolean',
    ];

    /**
     * "JAFZA, Dubai, UAE" style label — used to build the display-snapshot
     * origin/destination strings kept on shipment_offers/shipments so old
     * screens that just read a plain string keep working unchanged.
     */
    public function displayLabel(): string
    {
        return collect([$this->name, $this->city, $this->country])
            ->filter()
            ->implode(', ');
    }
}
