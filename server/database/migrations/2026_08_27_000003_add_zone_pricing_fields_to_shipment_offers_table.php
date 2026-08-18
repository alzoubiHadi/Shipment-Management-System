<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Smart Pricing Engine / Zones (2026-08-27). Adds the structured
     * origin/destination fields (country/city/zone/address) the new
     * Company Create-Shipment flow collects, plus a snapshot of the
     * pricing suggestion shown to the company at the time they created
     * the offer.
     *
     * The existing plain-string `origin`/`destination` columns are NOT
     * removed or repurposed — they stay as a "display snapshot" (e.g.
     * "JAFZA, Dubai, UAE"), built server-side from the structured fields
     * below when present, so every screen that just reads
     * `offer.origin`/`offer.destination` as a string keeps working
     * unchanged. All new columns are nullable so offers created by an
     * un-migrated older app build still work exactly as before (falls
     * back to PricingService::computeAutoPrice() / the old
     * destination-string flow — see ShipmentOfferController::create()).
     *
     * Snapshotting matters because price_list_entries changes over time
     * (see 2026_08_27_000004) — an offer must keep the exact reference
     * price/range/confidence it was shown, not whatever the lane's
     * current numbers happen to be later.
     */
    public function up(): void
    {
        Schema::table('shipment_offers', function (Blueprint $table) {
            $table->string('origin_country')->nullable()->after('origin');
            $table->string('origin_city')->nullable()->after('origin_country');
            $table->foreignId('origin_zone_id')->nullable()->after('origin_city')->constrained('zones')->nullOnDelete();
            $table->string('origin_address')->nullable()->after('origin_zone_id');

            $table->string('destination_country')->nullable()->after('destination');
            $table->string('destination_city')->nullable()->after('destination_country');
            $table->foreignId('destination_zone_id')->nullable()->after('destination_city')->constrained('zones')->nullOnDelete();
            $table->string('destination_address')->nullable()->after('destination_zone_id');

            // Pricing suggestion snapshot — see PricingService::
            // getPriceSuggestion(). platform_margin_percent_snapshot and
            // pricing_mode already exist on this table from an earlier
            // migration and are reused as-is.
            $table->decimal('pricing_reference', 10, 2)->nullable();
            $table->decimal('pricing_low', 10, 2)->nullable();
            $table->decimal('pricing_high', 10, 2)->nullable();
            $table->string('pricing_confidence')->nullable(); // High / Medium / Low
            $table->decimal('market_adjustment_snapshot', 5, 2)->nullable();
            // 'exact_zone' | 'country_fallback' | 'manual' | null (legacy,
            // pre-zones offer) — separate from pricing_mode ('auto'/
            // 'manual'), which only says who set the price.
            $table->string('pricing_level')->nullable();
            // What the company actually typed into "Your Price" before
            // the server recalculated price_to_client/price_to_driver —
            // kept for audit ("suggested X, company chose Y").
            $table->decimal('company_selected_price', 10, 2)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('shipment_offers', function (Blueprint $table) {
            $table->dropConstrainedForeignId('origin_zone_id');
            $table->dropConstrainedForeignId('destination_zone_id');
            $table->dropColumn([
                'origin_country', 'origin_city', 'origin_address',
                'destination_country', 'destination_city', 'destination_address',
                'pricing_reference', 'pricing_low', 'pricing_high', 'pricing_confidence',
                'market_adjustment_snapshot', 'pricing_level', 'company_selected_price',
            ]);
        });
    }
};
