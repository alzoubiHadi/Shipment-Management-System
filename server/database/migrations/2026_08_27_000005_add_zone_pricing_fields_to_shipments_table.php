<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Mirrors 2026_08_27_000003's additions onto `shipments`, so the
     * structured zone/country fields and pricing context survive past
     * matching — once a driver accepts an offer, ShipmentOfferController::
     * finalizeAcceptance() copies these across (see that method) so the
     * permanent Shipment record (used by Reports/Finance) keeps the same
     * zone-based route and pricing snapshot the offer had, not just the
     * final price_to_client/price_to_driver numbers with no context.
     *
     * `platform_margin_percent_snapshot` did not previously exist on this
     * table at all (only on shipment_offers) — added here so Finance can
     * see the margin that actually applied to a given completed shipment
     * even after platform_settings.profit_margin_percent changes later.
     */
    public function up(): void
    {
        Schema::table('shipments', function (Blueprint $table) {
            $table->string('origin_country')->nullable()->after('origin');
            $table->string('origin_city')->nullable()->after('origin_country');
            $table->foreignId('origin_zone_id')->nullable()->after('origin_city')->constrained('zones')->nullOnDelete();
            $table->string('origin_address')->nullable()->after('origin_zone_id');

            $table->string('destination_country')->nullable()->after('destination');
            $table->string('destination_city')->nullable()->after('destination_country');
            $table->foreignId('destination_zone_id')->nullable()->after('destination_city')->constrained('zones')->nullOnDelete();
            $table->string('destination_address')->nullable()->after('destination_zone_id');

            $table->decimal('pricing_reference', 10, 2)->nullable();
            $table->string('pricing_level')->nullable();
            $table->decimal('market_adjustment_snapshot', 5, 2)->nullable();
            $table->decimal('platform_margin_percent_snapshot', 5, 2)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('shipments', function (Blueprint $table) {
            $table->dropConstrainedForeignId('origin_zone_id');
            $table->dropConstrainedForeignId('destination_zone_id');
            $table->dropColumn([
                'origin_country', 'origin_city', 'origin_address',
                'destination_country', 'destination_city', 'destination_address',
                'pricing_reference', 'pricing_level', 'market_adjustment_snapshot',
                'platform_margin_percent_snapshot',
            ]);
        });
    }
};
