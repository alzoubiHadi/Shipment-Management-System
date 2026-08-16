<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * One-time data fix for the "reefer truck rejected as non-refrigerated"
     * bug: every existing truck row created before the Truck::booted()
     * saving hook (see app/Models/Truck.php) has has_refrigeration=false
     * even when truck_type is 'Reefer Trailer', because nothing ever set
     * it. This just re-derives it for rows that already exist — the model
     * hook keeps it correct going forward.
     */
    public function up(): void
    {
        DB::table('trucks')
            ->where('truck_type', 'Reefer Trailer')
            ->update(['has_refrigeration' => true]);

        DB::table('trucks')
            ->where('truck_type', '!=', 'Reefer Trailer')
            ->update(['has_refrigeration' => false]);
    }

    public function down(): void
    {
        // Not reversible in a meaningful way — the pre-fix state was a bug.
    }
};
