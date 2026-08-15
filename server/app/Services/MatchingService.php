<?php

namespace App\Services;

use App\Models\Driver;
use App\Models\PlatformSetting;
use App\Models\ShipmentOffer;
use App\Notifications\AppPushNotification;
use App\Support\Destinations;

/**
 * UC-14/UC-16: weighted matching of a shipment offer to eligible drivers,
 * pushed in batches of N (default 5, configurable). Re-invoked by the
 * ProcessExpiredMatches console command when a round's timeout passes
 * without an acceptance.
 */
class MatchingService
{
    /**
     * Eligible: available for work, approved, compliance-active, roadworthy
     * documents, destination reachable (country match via DriverDestination,
     * or 'internal_uae' for internal offers), cross-border residency rule
     * for external offers, and not already notified in a previous round of
     * THIS offer.
     */
    public function eligibleDriversQuery(ShipmentOffer $offer)
    {
        $alreadyNotified = $offer->matched_driver_ids ?? [];

        $countryKey = $offer->order_type === 'internal'
            ? 'internal_uae'
            : Destinations::countryFor($offer->destination);

        return Driver::query()
            ->where('status', 'available')
            ->where('approval_status', 'approved')
            ->where('compliance_status', 'active')
            ->whereNotIn('id', $alreadyNotified)
            ->where(function ($q) {
                $q->whereNull('license_expiry')->orWhere('license_expiry', '>=', now()->toDateString());
            })
            ->where(function ($q) {
                $q->whereNull('passport_expiry')->orWhere('passport_expiry', '>=', now()->toDateString());
            })
            ->where(function ($q) {
                $q->whereNull('residency_expiry')->orWhere('residency_expiry', '>=', now()->toDateString());
            })
            ->when($offer->order_type === 'external', function ($q) {
                $q->where('residency_expiry', '>=', now()->addMonths(3)->toDateString());
            })
            ->when($countryKey, function ($q) use ($countryKey) {
                $q->whereHas('destinations', fn ($d) => $d->where('destination', $countryKey));
            });
    }

    /**
     * Composite score in [0, 1]: weighted proximity + rating + acceptance
     * rate, all normalized to [0, 1] before weighting. A small load-balance
     * bonus is folded into the proximity/recency mix so the same top
     * drivers aren't always favored.
     */
    public function score(Driver $driver, ShipmentOffer $offer): float
    {
        $wProximity = (float) PlatformSetting::get('matching_weight_proximity', '0.5');
        $wRating = (float) PlatformSetting::get('matching_weight_rating', '0.3');
        $wAcceptance = (float) PlatformSetting::get('matching_weight_acceptance', '0.2');

        $proximityScore = $this->proximityScore($driver, $offer);
        $ratingScore = min(1.0, max(0.0, (float) $driver->rating / 5));
        $acceptanceScore = $driver->acceptanceRate();

        $base = ($wProximity * $proximityScore)
            + ($wRating * $ratingScore)
            + ($wAcceptance * $acceptanceScore);

        // Load-balancing: a driver who was matched very recently gets a
        // small penalty (up to -0.05) that fades over 30 minutes, so a
        // string of new offers doesn't keep landing on the same person.
        if ($driver->last_matched_at) {
            $minutesSince = $driver->last_matched_at->diffInMinutes(now());
            $recencyPenalty = max(0, 0.05 * (1 - min($minutesSince, 30) / 30));
            $base -= $recencyPenalty;
        }

        return $base;
    }

    /**
     * Haversine distance between the driver's last known location and the
     * offer's pickup point, converted to a 0..1 score (closer = higher).
     * Falls back to a neutral 0.5 when either coordinate pair is missing,
     * so proximity never disqualifies a driver outright — it just stops
     * influencing the ranking.
     */
    private function proximityScore(Driver $driver, ShipmentOffer $offer): float
    {
        if (! $driver->last_lat || ! $driver->last_lng || ! $offer->origin_lat || ! $offer->origin_lng) {
            return 0.5;
        }

        $distanceKm = $this->haversineKm(
            (float) $driver->last_lat,
            (float) $driver->last_lng,
            (float) $offer->origin_lat,
            (float) $offer->origin_lng,
        );

        // Phase-one linear falloff: 0km -> 1.0, 200km+ -> 0.0. A real
        // routing-API-based ETA is a later upgrade (per the spec's own
        // "phase one Haversine, real routing API later" note).
        return max(0.0, 1 - min($distanceKm, 200) / 200);
    }

    private function haversineKm(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $earthRadiusKm = 6371;
        $dLat = deg2rad($lat2 - $lat1);
        $dLng = deg2rad($lng2 - $lng1);

        $a = sin($dLat / 2) ** 2
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;
        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));

        return $earthRadiusKm * $c;
    }

    /**
     * Sends the next batch (default 5) of top-scored eligible drivers a
     * match notification, and advances the offer's matching state.
     * Returns the list of newly-matched Driver models (empty when no more
     * eligible drivers exist — caller should escalate to Super Admin).
     */
    public function matchNextBatch(ShipmentOffer $offer): array
    {
        $batchSize = (int) PlatformSetting::get('matching_batch_size', '5');

        $candidates = $this->eligibleDriversQuery($offer)->get();

        $ranked = $candidates
            ->map(fn (Driver $d) => ['driver' => $d, 'score' => $this->score($d, $offer)])
            ->sortByDesc('score')
            ->take($batchSize)
            ->values();

        if ($ranked->isEmpty()) {
            $offer->update(['status' => 'escalated']);
            return [];
        }

        $timeoutMinutes = (int) PlatformSetting::get('matching_response_timeout_minutes', '15');
        $newlyMatched = $ranked->pluck('driver');
        $newIds = $newlyMatched->pluck('id')->all();

        $offer->update([
            'matched_driver_ids' => array_values(array_unique(array_merge($offer->matched_driver_ids ?? [], $newIds))),
            'matching_round' => $offer->matching_round + 1,
            'expires_at' => now()->addMinutes($timeoutMinutes),
        ]);

        foreach ($newlyMatched as $driver) {
            $driver->increment('offers_received_count');
            $driver->update(['last_matched_at' => now()]);

            if ($driver->user) {
                $driver->user->notify(new AppPushNotification(
                    'offer_matched',
                    'New shipment offer available',
                    sprintf('%s -> %s (%s)', $offer->origin, $offer->destination, $offer->required_truck_type ?? 'any truck'),
                    ['offer_id' => $offer->id],
                ));
            }
        }

        return $newlyMatched->all();
    }
}
