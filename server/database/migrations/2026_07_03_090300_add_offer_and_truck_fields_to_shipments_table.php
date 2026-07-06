<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('shipments', function (Blueprint $table) {
            $table->foreignId('shipment_offer_id')
                  ->nullable()
                  ->after('id')
                  ->constrained('shipment_offers')
                  ->nullOnDelete();

            $table->foreignId('truck_id')
                  ->nullable()
                  ->after('driver_id')
                  ->constrained('trucks')
                  ->nullOnDelete();

            $table->string('cargo_type')->default('normal')->after('description');

            $table->decimal('price_to_driver', 10, 2)->nullable()->after('cargo_type');
            $table->decimal('price_to_client', 10, 2)->nullable()->after('price_to_driver');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('shipments', function (Blueprint $table) {
            $table->dropConstrainedForeignId('shipment_offer_id');
            $table->dropConstrainedForeignId('truck_id');
            $table->dropColumn(['cargo_type', 'price_to_driver', 'price_to_client']);
        });
    }
};
