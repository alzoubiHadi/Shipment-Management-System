<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Smart Pricing Engine (2026-08-27): price_list_entries moves from a
     * flat (destination, truck_type) -> base_price lookup to a
     * (origin_zone_id, destination_zone_id, truck_type) -> historical
     * pricing lookup, backed by real ALBATRANS trip data (see
     * 2026_08_27_000006's import of 861 lanes).
     *
     * The old destination/truck_type/base_price columns and their unique
     * index are NOT dropped — any pre-existing legacy row keeps working
     * exactly as before via PricingService::computeAutoPrice(). New
     * zone-based rows leave destination/base_price null (a unique index
     * on nullable Postgres columns allows any number of NULLs, so this
     * doesn't collide with the legacy constraint). Going forward,
     * PricingService::getPriceSuggestion() is the only thing that reads
     * the new columns.
     */
    public function up(): void
    {
        Schema::table('price_list_entries', function (Blueprint $table) {
            $table->foreignId('origin_zone_id')->nullable()->after('destination')->constrained('zones')->nullOnDelete();
            $table->foreignId('destination_zone_id')->nullable()->after('origin_zone_id')->constrained('zones')->nullOnDelete();
            // Original Excel size label (e.g. "13.5 m", "27 t") for the
            // winning row when several Excel size-variants collapsed into
            // the same canonical truck_type for a given zone pair — see
            // the import migration's aggregation note. Informational only,
            // never matched against the offer (offers don't carry a size).
            $table->string('truck_size')->nullable();

            $table->decimal('median_base_price', 10, 2)->nullable();
            $table->decimal('median_charges', 10, 2)->nullable();
            $table->decimal('reference_price', 10, 2)->nullable(); // historical total (base + charges)
            $table->decimal('suggested_low', 10, 2)->nullable();
            $table->decimal('suggested_high', 10, 2)->nullable();
            $table->unsignedInteger('historical_trip_count')->nullable(); // "Truck Units" sample size
            $table->string('confidence')->nullable(); // High / Medium / Low
            $table->decimal('market_adjustment_percent', 5, 2)->default(0);
            $table->date('last_historical_date')->nullable();
            $table->string('pricing_level')->nullable(); // e.g. "Exact Zone + Truck"
            $table->boolean('is_active')->default(true);

            $table->unique(['origin_zone_id', 'destination_zone_id', 'truck_type'], 'price_list_entries_zone_truck_unique');
            $table->index(['origin_zone_id', 'destination_zone_id']);
        });

        /**
         * Country-to-country fallback used when no exact zone lane exists
         * (see PricingService::getPriceSuggestion()) — e.g. JAFZA -> NEOM
         * has no direct history, but UAE -> KSA (General Truck) does.
         * Deliberately no market_adjustment_percent here: fallback prices
         * are already a rougher estimate ("Medium confidence" per the
         * design doc), and admin market-adjustment control is scoped to
         * exact lanes only (price_list_entries) for V1.
         */
        Schema::create('fallback_pricing', function (Blueprint $table) {
            $table->id();
            $table->string('origin_country');
            $table->string('destination_country');
            $table->string('truck_type');
            $table->unsignedInteger('historical_trip_count')->nullable();
            $table->decimal('median_total', 10, 2)->nullable();
            $table->decimal('typical_low', 10, 2)->nullable();
            $table->decimal('typical_high', 10, 2)->nullable();
            $table->unsignedInteger('recent_90d_count')->nullable();
            $table->decimal('recent_90d_median', 10, 2)->nullable();
            $table->decimal('reference_price', 10, 2)->nullable();
            $table->string('confidence')->nullable();
            $table->string('pricing_level')->nullable();
            $table->timestamps();

            $table->unique(['origin_country', 'destination_country', 'truck_type']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('fallback_pricing');

        Schema::table('price_list_entries', function (Blueprint $table) {
            $table->dropUnique('price_list_entries_zone_truck_unique');
            $table->dropConstrainedForeignId('origin_zone_id');
            $table->dropConstrainedForeignId('destination_zone_id');
            $table->dropColumn([
                'truck_size', 'median_base_price', 'median_charges', 'reference_price',
                'suggested_low', 'suggested_high', 'historical_trip_count', 'confidence',
                'market_adjustment_percent', 'last_historical_date', 'pricing_level', 'is_active',
            ]);
        });
    }
};
