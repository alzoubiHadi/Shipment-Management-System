<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * A driver selects one or more destinations they are willing to travel
     * to (Middle-East countries, or "internal (UAE)"). Used by the
     * matching algorithm to filter eligible drivers by the offer's
     * destination country. All shipments currently depart from the UAE.
     */
    public function up(): void
    {
        Schema::create('driver_destinations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('driver_id')->constrained()->cascadeOnDelete();
            $table->string('destination'); // e.g. "internal_uae", "saudi_arabia", "oman", ...
            $table->timestamps();

            $table->unique(['driver_id', 'destination']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('driver_destinations');
    }
};
