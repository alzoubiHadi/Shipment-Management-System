<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Smart Pricing Engine / Zone-based Matching (2026-08-27) — see
     * PricingService::getPriceSuggestion() and MatchingService's zone-aware
     * eligibility/route-experience for how this is used.
     *
     * A Zone is a named pickup/drop-off area within a city (e.g. "JAFZA",
     * "DIP" both within Dubai, UAE) — the canonical, de-duplicated form of
     * what companies used to type as free-text destinations. Deliberately
     * NOT a GIS system: no polygons, no geofencing, just a flat lookup
     * table seeded from real historical trip data (see
     * 2026_08_27_000002_import_zones_from_pricing_data.php). Aliases used
     * to normalize raw historical strings into these canonical zones are
     * NOT stored as their own table — they're only needed once, at import
     * time (see the import migration's ALIAS_MAP).
     */
    public function up(): void
    {
        Schema::create('zones', function (Blueprint $table) {
            $table->id();
            $table->string('country'); // e.g. 'UAE', 'KSA', 'QATAR' — matches DriverDestination-mappable country names
            $table->string('city')->nullable();
            $table->string('name'); // canonical zone name, e.g. 'JAFZA', 'RIYADH'
            // Excel's "Zone Type" (Area / City, Region, ...) — kept for
            // admin-facing context only, nothing branches on it in code.
            $table->string('zone_type')->nullable();
            // No coordinates in the source data yet — left nullable.
            // MatchingService's proximity score already treats missing
            // coordinates as neutral (0.5), so this degrades gracefully;
            // see the design doc's point 23.
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->unique(['country', 'city', 'name']);
            $table->index(['country', 'city']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('zones');
    }
};
