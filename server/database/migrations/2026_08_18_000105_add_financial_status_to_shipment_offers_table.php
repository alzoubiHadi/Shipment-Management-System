<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Financial reservation for a shipment offer, distinct from its
     * workflow `status` column. Values:
     *  - 'none'      — no price set yet (still awaiting_manual_price), so
     *                  nothing is reserved.
     *  - 'reserved'  — price is known and holds against the company's
     *                  available balance (Company::reservedAmount()), so a
     *                  second concurrent offer can't also spend the same
     *                  headroom before this one is accepted or cancelled.
     *  - 'released'  — the offer was cancelled before acceptance; the hold
     *                  is freed, no ledger transaction was ever posted.
     *  - 'committed' — the offer was accepted by a driver; the reservation
     *                  converted into a real SHIPMENT_CHARGE ledger entry
     *                  (see LedgerService + ShipmentOfferController::finalizeAcceptance).
     */
    public function up(): void
    {
        Schema::table('shipment_offers', function (Blueprint $table) {
            $table->string('financial_status')->default('none')->after('status');
            $table->index('financial_status');
        });
    }

    public function down(): void
    {
        Schema::table('shipment_offers', function (Blueprint $table) {
            $table->dropIndex(['financial_status']);
            $table->dropColumn('financial_status');
        });
    }
};
