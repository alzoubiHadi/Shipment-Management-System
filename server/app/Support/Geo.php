<?php

namespace App\Support;

/**
 * Admin Shipments redesign (2026-08-24): small shared geo-math helper.
 * Previously this exact Haversine formula lived only as a private method on
 * MatchingService (used for the proximity ranking score) — pulled out here
 * so it can also back the Trip Report / Live Tracking "Distance" figure
 * without duplicating the formula.
 */
class Geo
{
    /** Great-circle distance between two lat/lng points, in kilometers. */
    public static function haversineKm(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $earthRadiusKm = 6371;
        $dLat = deg2rad($lat2 - $lat1);
        $dLng = deg2rad($lng2 - $lng1);

        $a = sin($dLat / 2) ** 2
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;
        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));

        return $earthRadiusKm * $c;
    }
}
