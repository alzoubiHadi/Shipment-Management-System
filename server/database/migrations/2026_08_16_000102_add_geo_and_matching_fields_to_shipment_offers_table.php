<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * origin_lat/origin_lng: pickup coordinates for the Haversine proximity
     * component of the matching score (UC-14). Optional — if missing, the
     * matching service falls back to a neutral proximity score rather than
     * failing, since not every company pins an exact pickup location yet.
     *
     * matched_driver_ids: running JSON list of every driver id ever pushed
     * this offer, across every re-match round — used to exclude them from
     * subsequent rounds so the same 5 aren't re-notified.
     *
     * matching_round: how many batches of 5 have been sent out so far.
     * expires_at (already existed, previously unused) is now the deadline
     * for the CURRENT round before re-matching kicks in.
     */
    public function up(): void
    {
        Schema::table('shipment_offers', function (Blueprint $table) {
            $table->decimal('origin_lat', 10, 7)->nullable()->after('origin');
            $table->decimal('origin_lng', 10, 7)->nullable()->after('origin_lat');
            $table->json('matched_driver_ids')->nullable()->after('accepted_at');
            $table->unsignedTinyInteger('matching_round')->default(0)->after('matched_driver_ids');
        });
    }

    public function down(): void
    {
        Schema::table('shipment_offers', function (Blueprint $table) {
            $table->dropColumn(['origin_lat', 'origin_lng', 'matched_driver_ids', 'matching_round']);
        });
    }
};
