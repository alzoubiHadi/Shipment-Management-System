<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Weights for the composite matching score (UC-14) — must sum to 1.0.
     * matching_batch_size is "top 5" from the spec, kept configurable
     * rather than hard-coded.
     */
    public function up(): void
    {
        DB::table('platform_settings')->insert([
            ['key' => 'matching_weight_proximity', 'value' => '0.5', 'created_at' => now(), 'updated_at' => now()],
            ['key' => 'matching_weight_rating', 'value' => '0.3', 'created_at' => now(), 'updated_at' => now()],
            ['key' => 'matching_weight_acceptance', 'value' => '0.2', 'created_at' => now(), 'updated_at' => now()],
            ['key' => 'matching_batch_size', 'value' => '5', 'created_at' => now(), 'updated_at' => now()],
        ]);
    }

    public function down(): void
    {
        DB::table('platform_settings')->whereIn('key', [
            'matching_weight_proximity',
            'matching_weight_rating',
            'matching_weight_acceptance',
            'matching_batch_size',
        ])->delete();
    }
};
