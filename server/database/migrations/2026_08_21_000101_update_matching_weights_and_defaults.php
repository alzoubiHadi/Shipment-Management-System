<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Matching redesign (2026-08-21): the composite score gains two new
     * factors (fairness/last-matched, route experience) and drops the old
     * 50/30/20 proximity/rating/acceptance split for a
     * 40/25/15/10/10 proximity/rating/acceptance/fairness/route-experience
     * split — still sums to 1.0. Also shortens the default match-response
     * timeout from 15 to 5 minutes per round (5 drivers / 5 minutes),
     * since 15 minutes per round made the LAST batch of a large candidate
     * pool take close to an hour to reach. Both remain fully configurable
     * via PlatformSettingController — this migration only changes the
     * stored defaults for existing installs (the seed migration's values
     * are now stale/historical).
     */
    public function up(): void
    {
        DB::table('platform_settings')->where('key', 'matching_weight_proximity')->update(['value' => '0.40', 'updated_at' => now()]);
        DB::table('platform_settings')->where('key', 'matching_weight_rating')->update(['value' => '0.25', 'updated_at' => now()]);
        DB::table('platform_settings')->where('key', 'matching_weight_acceptance')->update(['value' => '0.15', 'updated_at' => now()]);
        DB::table('platform_settings')->where('key', 'matching_response_timeout_minutes')->update(['value' => '5', 'updated_at' => now()]);

        DB::table('platform_settings')->updateOrInsert(
            ['key' => 'matching_weight_fairness'],
            ['value' => '0.10', 'created_at' => now(), 'updated_at' => now()],
        );
        DB::table('platform_settings')->updateOrInsert(
            ['key' => 'matching_weight_route_experience'],
            ['value' => '0.10', 'created_at' => now(), 'updated_at' => now()],
        );

        foreach ([
            'matching_weight_proximity',
            'matching_weight_rating',
            'matching_weight_acceptance',
            'matching_weight_fairness',
            'matching_weight_route_experience',
            'matching_response_timeout_minutes',
        ] as $key) {
            Cache::forget("platform_setting:{$key}");
        }
    }

    public function down(): void
    {
        DB::table('platform_settings')->where('key', 'matching_weight_proximity')->update(['value' => '0.5', 'updated_at' => now()]);
        DB::table('platform_settings')->where('key', 'matching_weight_rating')->update(['value' => '0.3', 'updated_at' => now()]);
        DB::table('platform_settings')->where('key', 'matching_weight_acceptance')->update(['value' => '0.2', 'updated_at' => now()]);
        DB::table('platform_settings')->where('key', 'matching_response_timeout_minutes')->update(['value' => '15', 'updated_at' => now()]);

        DB::table('platform_settings')->whereIn('key', [
            'matching_weight_fairness',
            'matching_weight_route_experience',
        ])->delete();

        foreach ([
            'matching_weight_proximity',
            'matching_weight_rating',
            'matching_weight_acceptance',
            'matching_weight_fairness',
            'matching_weight_route_experience',
            'matching_response_timeout_minutes',
        ] as $key) {
            Cache::forget("platform_setting:{$key}");
        }
    }
};
