<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Admin Shipments redesign (2026-08-24): the admin's new unified
     * Shipments list shows a single continuous #TRK-xxxxx identity from the
     * moment a company creates an offer (still "Matching") all the way
     * through to delivery — previously only the `shipments` table (created
     * at ACCEPTANCE time) had a tracking_number, so a still-matching offer
     * had nothing to display in that slot. Generated the same way as
     * Shipment's own ('TRK' . strtoupper(uniqid())) at offer-creation time
     * — see ShipmentOfferController::create(). Nullable because existing
     * rows predate this column and are not backfilled (admin UI falls back
     * to "OFR-{id}" for those).
     */
    public function up(): void
    {
        Schema::table('shipment_offers', function (Blueprint $table) {
            $table->string('tracking_number')->nullable()->unique()->after('id');
        });
    }

    public function down(): void
    {
        Schema::table('shipment_offers', function (Blueprint $table) {
            $table->dropColumn('tracking_number');
        });
    }
};
