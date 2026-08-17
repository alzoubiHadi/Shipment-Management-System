<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Admin Shipments redesign (2026-08-24), Matching Status screen: before
     * this, shipment_offers only stored the CURRENT matching_round number
     * and a single cumulative matched_driver_ids array (every driver ever
     * notified, across all rounds, merged into one list) — there was no way
     * to show "Round 1: 5 drivers notified, no acceptance; Round 2:
     * waiting" per the admin's requested design. This table gives each
     * round its own row, written by MatchingService::matchNextBatch().
     *
     * outcome: 'waiting' (still within its response window) ->
     * 'no_acceptance' (window expired, superseded by a later round) or
     * 'accepted' (a driver from this round accepted the offer) or
     * 'escalated' (this was the last round, no eligible drivers left, or
     * the round it happened in and the offer went to escalated).
     */
    public function up(): void
    {
        Schema::create('shipment_offer_matching_rounds', function (Blueprint $table) {
            $table->id();
            $table->foreignId('shipment_offer_id')->constrained()->cascadeOnDelete();
            $table->unsignedTinyInteger('round_number');
            $table->json('driver_ids');
            $table->timestamp('notified_at');
            $table->string('outcome')->default('waiting');
            $table->foreignId('accepted_by_driver_id')->nullable()->constrained('drivers')->nullOnDelete();
            $table->timestamp('resolved_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('shipment_offer_matching_rounds');
    }
};
