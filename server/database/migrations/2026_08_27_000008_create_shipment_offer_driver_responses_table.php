<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Per-driver record of every matching-round notification and how it
     * was resolved (accepted / declined / expired) — design doc point 26/
     * 41: "after a few thousand offers this becomes a great dataset" for
     * future acceptance-probability ranking. Complements the existing
     * shipment_offer_matching_rounds table, which only tracks the
     * round-level outcome and the single accepting driver, not each of
     * the N notified drivers individually.
     *
     * Written by MatchingService::matchNextBatch() (one 'pending' row per
     * notified driver), then updated to 'accepted' (finalizeAcceptance()),
     * 'declined' (ShipmentOfferController::decline()), or 'expired'
     * (matchNextBatch()'s next call, when it closes out the previous
     * still-pending round).
     */
    public function up(): void
    {
        Schema::create('shipment_offer_driver_responses', function (Blueprint $table) {
            $table->id();
            $table->foreignId('shipment_offer_id')->constrained()->cascadeOnDelete();
            $table->foreignId('driver_id')->constrained()->cascadeOnDelete();
            $table->unsignedTinyInteger('matching_round')->nullable();
            $table->decimal('matching_score', 5, 4)->nullable();
            $table->decimal('price_to_driver_snapshot', 10, 2)->nullable();
            $table->foreignId('origin_zone_id')->nullable()->constrained('zones')->nullOnDelete();
            $table->foreignId('destination_zone_id')->nullable()->constrained('zones')->nullOnDelete();
            $table->timestamp('sent_at')->nullable();
            $table->timestamp('response_at')->nullable();
            // pending | accepted | declined | expired
            $table->string('result')->default('pending');
            $table->timestamps();

            $table->unique(['shipment_offer_id', 'driver_id']);
            $table->index(['driver_id', 'result']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('shipment_offer_driver_responses');
    }
};
