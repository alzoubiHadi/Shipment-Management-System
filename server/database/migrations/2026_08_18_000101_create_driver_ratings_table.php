<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * UC-23 (company rates a driver after a confirmed delivery) and UC-24
     * (Super Admin rates/adjusts a driver directly, not tied to any one
     * shipment). Driver::rating is a recency-weighted average recomputed
     * from every row here every time one is added — see
     * Driver::recalculateRating(). shipment_id is nullable specifically so
     * UC-24 admin ratings can exist without a shipment, and unique so a
     * company can only rate a given shipment's driver once.
     */
    public function up(): void
    {
        Schema::create('driver_ratings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('driver_id')->constrained()->cascadeOnDelete();
            $table->foreignId('shipment_id')->nullable()->unique()->constrained()->nullOnDelete();
            $table->foreignId('rated_by_user_id')->nullable()->constrained('users')->nullOnDelete();

            $table->enum('source', ['company', 'super_admin']);
            $table->unsignedTinyInteger('score'); // 1-5
            $table->text('comment')->nullable();

            $table->timestamps();

            $table->index(['driver_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('driver_ratings');
    }
};
