<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Simple key-value store for the handful of admin-configurable values
     * called out across the spec, so none of them are hard-coded:
     * - profit_margin_percent (Finance Admin, default 20)
     * - matching_response_timeout_minutes (Super Admin, re-match trigger)
     * - working_hours_alert_threshold_minutes (default 480 = 8h)
     * - rest_reset_minutes (default 30 — a break of this length resets the
     *   continuous on-duty timer)
     * - default_driver_rating (default 4.5, kept configurable rather than
     *   hard-coded in application code)
     */
    public function up(): void
    {
        Schema::create('platform_settings', function (Blueprint $table) {
            $table->id();
            $table->string('key')->unique();
            $table->string('value');
            $table->timestamps();
        });

        DB::table('platform_settings')->insert([
            ['key' => 'profit_margin_percent', 'value' => '20', 'created_at' => now(), 'updated_at' => now()],
            ['key' => 'matching_response_timeout_minutes', 'value' => '15', 'created_at' => now(), 'updated_at' => now()],
            ['key' => 'working_hours_alert_threshold_minutes', 'value' => '480', 'created_at' => now(), 'updated_at' => now()],
            ['key' => 'rest_reset_minutes', 'value' => '30', 'created_at' => now(), 'updated_at' => now()],
            ['key' => 'default_driver_rating', 'value' => '4.5', 'created_at' => now(), 'updated_at' => now()],
        ]);
    }

    public function down(): void
    {
        Schema::dropIfExists('platform_settings');
    }
};
