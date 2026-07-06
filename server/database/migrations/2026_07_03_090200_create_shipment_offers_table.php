<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * A shipment offer is the "order" step: the client company contacted the
     * transport company outside the app (phone / email / WhatsApp), an admin
     * logs the order here with a price offered to the driver, the system
     * matches it against eligible & available drivers/trucks, and the first
     * driver to accept turns it into a real Shipment record (see
     * shipments.shipment_offer_id).
     */
    public function up(): void
    {
        Schema::create('shipment_offers', function (Blueprint $table) {
            $table->id();

            $table->foreignId('company_id')->constrained()->cascadeOnDelete();

            $table->string('origin');
            $table->string('destination');
            $table->decimal('weight', 10, 2)->nullable();
            $table->text('description')->nullable();

            // normal, refrigerated, hazardous
            $table->string('cargo_type')->default('normal');
            $table->boolean('requires_cross_border')->default(false);

            // required truck type to fulfil this offer, e.g. "refrigerated"
            $table->string('required_truck_type')->nullable();

            // what the transport company will pay the driver for this job
            $table->decimal('price_to_driver', 10, 2)->nullable();
            // what the client company is being charged (company's margin = this - price_to_driver)
            $table->decimal('price_to_client', 10, 2)->nullable();

            // pending, accepted, expired, cancelled
            $table->string('status')->default('pending');

            $table->foreignId('accepted_by_driver_id')
                  ->nullable()
                  ->constrained('drivers')
                  ->nullOnDelete();

            $table->foreignId('accepted_truck_id')
                  ->nullable()
                  ->constrained('trucks')
                  ->nullOnDelete();

            $table->timestamp('accepted_at')->nullable();
            $table->timestamp('expires_at')->nullable();

            $table->timestamps();
            $table->softDeletes();

            $table->index('status');
            $table->index('cargo_type');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('shipment_offers');
    }
};
