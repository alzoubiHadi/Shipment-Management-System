<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('shipments', function (Blueprint $table) {
            $table->id(); 

   

            // shipment belongs to a company
            $table->foreignId('company_id')
                  ->constrained()
                  ->cascadeOnDelete();

            // shipment may be assigned to a driver later
            $table->foreignId('driver_id')
                  ->nullable()
                  ->constrained()
                  ->nullOnDelete();

            // tracking
            $table->string('tracking_number')->unique();

            // shipment details (copy from request at approval time)
            $table->string('origin');
            $table->string('destination');
            $table->decimal('weight', 10, 2)->nullable();
            $table->text('description')->nullable();

            // status of the shipment (NOT float)
            $table->unsignedTinyInteger('status')->default(0);
            // 0=pending,1=assigned,2=in_transit,3=delivered,4=cancelled

            $table->timestamp('pickup_time')->nullable();
            $table->timestamp('delivered_at')->nullable();

            $table->timestamps();

            $table->index(['company_id']);
            $table->index(['driver_id']);
            $table->index(['status']);
            $table->softDeletes();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('shipments');
    }
};