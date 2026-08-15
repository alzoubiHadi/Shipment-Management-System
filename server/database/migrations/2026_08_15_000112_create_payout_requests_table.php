<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Driver -> platform withdrawal request (UC-30/UC-31/UC-32). Actual
     * money movement happens outside the app (no payment gateway yet):
     * Finance Admin transfers manually and attaches a transfer receipt
     * here ('paid'); the driver's balance is only decremented once the
     * driver explicitly confirms receipt ('confirmed'). A driver cannot
     * accept a new shipment offer while they have a pending/unconfirmed
     * payout request (enforced in ShipmentOfferController, not here).
     */
    public function up(): void
    {
        Schema::create('payout_requests', function (Blueprint $table) {
            $table->id();
            $table->foreignId('driver_id')->constrained()->cascadeOnDelete();
            $table->decimal('amount', 12, 2);
            $table->enum('status', ['pending', 'paid', 'confirmed', 'rejected'])->default('pending');

            $table->string('transfer_receipt_file_path')->nullable();
            $table->foreignId('paid_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('paid_at')->nullable();

            $table->timestamp('confirmed_at')->nullable();
            $table->string('rejection_reason')->nullable();

            $table->timestamps();

            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('payout_requests');
    }
};
