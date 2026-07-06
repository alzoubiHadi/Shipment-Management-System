<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * A truck is kept as its own entity (not glued to a single driver) because
     * a truck can be used by more than one driver at different times, and a
     * driver can drive more than one truck. The current driver assigned to a
     * shipment is chosen together with a truck at offer-acceptance time.
     */
    public function up(): void
    {
        Schema::create('trucks', function (Blueprint $table) {
            $table->id();

            $table->string('truck_number')->unique();
            // normal, refrigerated, tanker, flatbed, etc.
            $table->string('truck_type');

            // load capacity in kg
            $table->decimal('max_load', 10, 2)->nullable();

            // dimensions in meters
            $table->decimal('length', 8, 2)->nullable();
            $table->decimal('width', 8, 2)->nullable();
            $table->decimal('height', 8, 2)->nullable();

            $table->boolean('has_refrigeration')->default(false);

            // permit for hazardous / chemical / oversized cargo, etc.
            $table->string('permit_type')->nullable();
            $table->date('permit_expiry')->nullable();

            $table->date('insurance_expiry')->nullable();
            $table->date('license_expiry')->nullable(); // vehicle registration/license

            // default/primary driver (optional) — a truck may still be driven
            // by other drivers, tracked per-shipment via shipments.driver_id
            $table->foreignId('default_driver_id')
                  ->nullable()
                  ->constrained('drivers')
                  ->nullOnDelete();

            $table->boolean('is_active')->default(true);

            $table->timestamps();
            $table->softDeletes();

            $table->index('truck_type');
            $table->index('is_active');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('trucks');
    }
};
