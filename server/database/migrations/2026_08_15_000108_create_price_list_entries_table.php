<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Central price matrix: destination x truck_type -> base price (AED).
     * Managed by Finance Admin via Excel download/edit/upload (UC-33), not
     * a manual per-cell UI. When an offer's (destination, truck_type)
     * combo has no row here, the offer falls back to the manual-pricing
     * flow (UC-13).
     *
     * driver-visible price = base_price - (base_price * platform_margin_percent).
     * platform_margin_percent itself lives in platform_settings (default 20),
     * editable only by Finance Admin, so it is NOT duplicated per row here.
     */
    public function up(): void
    {
        Schema::create('price_list_entries', function (Blueprint $table) {
            $table->id();
            $table->string('destination');
            $table->string('truck_type');
            $table->decimal('base_price', 10, 2);
            $table->timestamps();

            $table->unique(['destination', 'truck_type']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('price_list_entries');
    }
};
