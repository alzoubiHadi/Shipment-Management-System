<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Zones / Smart Pricing Engine V1 (2026-08-27): rebalances the
     * matching score from 40/25/15/10/10 (proximity/rating/acceptance/
     * fairness/route-experience) to proximity 30%, route/zone experience
     * 25%, rating 20%, acceptance 15%, fairness 10% — still sums to 1.0.
     * Proximity previously weighed the most of any factor, which
     * over-weights physical closeness for international road freight;
     * route/zone experience becomes much more meaningful now that it can
     * match on an exact origin-zone -> destination-zone lane instead of
     * just a destination string (see MatchingService::
     * routeExperienceScore()). Deliberately does NOT add a price-behavior
     * factor yet — not enough accept/decline history exists (see the new
     * shipment_offer_driver_responses table, which starts building that
     * dataset from this release onward).
     */
    public function up(): void
    {
        DB::table('platform_settings')->where('key', 'matching_weight_proximity')->update(['value' => '0.30', 'updated_at' => now()]);
        DB::table('platform_settings')->where('key', 'matching_weight_rating')->update(['value' => '0.20', 'updated_at' => now()]);
        DB::table('platform_settings')->where('key', 'matching_weight_acceptance')->update(['value' => '0.15', 'updated_at' => now()]);
        DB::table('platform_settings')->where('key', 'matching_weight_fairness')->update(['value' => '0.10', 'updated_at' => now()]);
        DB::table('platform_settings')->where('key', 'matching_weight_route_experience')->update(['value' => '0.25', 'updated_at' => now()]);

        foreach ([
            'matching_weight_proximity',
            'matching_weight_rating',
            'matching_weight_acceptance',
            'matching_weight_fairness',
            'matching_weight_route_experience',
        ] as $key) {
            Cache::forget("platform_setting:{$key}");
        }
    }

    public function down(): void
    {
        DB::table('platform_settings')->where('key', 'matching_weight_proximity')->update(['value' => '0.40', 'updated_at' => now()]);
        DB::table('platform_settings')->where('key', 'matching_weight_rating')->update(['value' => '0.25', 'updated_at' => now()]);
        DB::table('platform_settings')->where('key', 'matching_weight_acceptance')->update(['value' => '0.15', 'updated_at' => now()]);
        DB::table('platform_settings')->where('key', 'matching_weight_fairness')->update(['value' => '0.10', 'updated_at' => now()]);
        DB::table('platform_settings')->where('key', 'matching_weight_route_experience')->update(['value' => '0.10', 'updated_at' => now()]);

        foreach ([
            'matching_weight_proximity',
            'matching_weight_rating',
            'matching_weight_acceptance',
            'matching_weight_fairness',
            'matching_weight_route_experience',
        ] as $key) {
            Cache::forget("platform_setting:{$key}");
        }
    }
};
