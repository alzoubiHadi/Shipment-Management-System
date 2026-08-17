<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Admin Shipments redesign (2026-08-24): the Trip Report / Live
     * Tracking screens want a straight-line "Distance" figure, which needs
     * BOTH ends of the trip as coordinates. shipment_offers already had
     * origin_lat/origin_lng (2026_08_16_000102); this adds the matching
     * destination_lat/destination_lng, populated at offer-creation time for
     * external offers only (via App\Support\Destinations::coordsFor()) —
     * internal (UAE) destinations stay free text with no fixed coordinates,
     * so distance is simply omitted for those rather than guessed.
     *
     * shipments gets its own copies of all four columns (origin + dest lat/
     * lng), snapshotted from the offer at accept-time in
     * ShipmentOfferController::finalizeAcceptance() — mirrors the existing
     * price_to_driver/price_to_client copy-over pattern. Keeping a
     * shipment-local copy means the Trip Report never has to join back to
     * the (possibly soft-deleted) offer just to plot the route.
     */
    public function up(): void
    {
        Schema::table('shipment_offers', function (Blueprint $table) {
            $table->decimal('destination_lat', 10, 7)->nullable()->after('origin_lng');
            $table->decimal('destination_lng', 10, 7)->nullable()->after('destination_lat');
        });

        Schema::table('shipments', function (Blueprint $table) {
            $table->decimal('origin_lat', 10, 7)->nullable()->after('origin');
            $table->decimal('origin_lng', 10, 7)->nullable()->after('origin_lat');
            $table->decimal('destination_lat', 10, 7)->nullable()->after('destination');
            $table->decimal('destination_lng', 10, 7)->nullable()->after('destination_lat');
        });
    }

    public function down(): void
    {
        Schema::table('shipment_offers', function (Blueprint $table) {
            $table->dropColumn(['destination_lat', 'destination_lng']);
        });

        Schema::table('shipments', function (Blueprint $table) {
            $table->dropColumn(['origin_lat', 'origin_lng', 'destination_lat', 'destination_lng']);
        });
    }
};
