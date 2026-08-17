<?php

namespace App\Services;

use App\Models\Driver;
use App\Models\PayoutRequest;
use App\Models\PlatformSetting;
use App\Models\ShipmentOffer;
use App\Notifications\AppPushNotification;
use App\Services\ComplianceService;
use App\Support\Destinations;

/**
 * UC-14/UC-16: weighted matching of a shipment offer to eligible drivers,
 * pushed in batches of N (default 5, configurable). Re-invoked by the
 * ProcessExpiredMatches console command when a round's timeout passes
 * without an acceptance.
 *
 * Two-step design (2026-08-21 redesign):
 *   Step 1 — Hard Eligibility (eligibleDriversQuery): a driver either
 *   passes every gate below or they are not a candidate at all — no
 *   partial credit, nothing here ever influences the score.
 *   Step 2 — Ranking (score): purely a tie-breaker among drivers who
 *   already passed Step 1 in full.
 */
class MatchingService
{
    /**
     * Step 1 — Hard Eligibility. A driver only appears in this query if
     * ALL of the following hold:
     *   - Approved, available, and in good compliance standing —
     *     compliance_status 'active' always qualifies; 'expiring_soon'
     *     also qualifies as long as no critical document (the driver's own,
     *     or their truck's) expires within an order-type-based grace
     *     window: 3 days for an internal offer, 3 months for an external
     *     one (2026-08-24 grace-period follow-up — see
     *     ComplianceService::isEligibleForShipment(), the same rule
     *     re-applied at accept-time). 'action_required'/'pending_review'
     *     always disqualify.
     *   - No blocking financial/payout issue (UC-30).
     *   - Every required driver document (license/passport/residency) is
     *     present AND not expired — missing counts the same as expired
     *     (see Driver::documentIssues()); external offers additionally
     *     need >=3 months of residency left (cross-border rule).
     *   - The driver covers every country leg of the route (origin AND
     *     destination — see requiredCountriesFor()), not just the
     *     destination.
     *   - The driver has a linked truck (Driver 1<->1 Truck) that is
     *     active, has valid documents, is the correct type, refrigerated
     *     if the cargo needs it, and has enough payload capacity for this
     *     shipment's weight — mirrors Truck::suitabilityIssue(), which is
     *     the same rule re-checked at accept-time.
     *
     * Does NOT exclude drivers already notified in a previous round of
     * THIS offer (offer->matched_driver_ids) — that exclusion only makes
     * sense when picking the *next new batch* to notify (see
     * matchNextBatch()) and must NOT apply when this same query is reused
     * to decide what a driver sees in their own "Available Shipments"
     * list (ShipmentOfferController::availableForDriver()), where an
     * already-notified driver must obviously still see the offer.
     */
    public function eligibleDriversQuery(ShipmentOffer $offer)
    {
        $today = now()->toDateString();
        $requiredCountries = $this->requiredCountriesFor($offer);
        $graceCutoff = ComplianceService::graceCutoffDate($offer->order_type ?? 'internal')->toDateString();

        $query = Driver::query()
            ->where('status', 'available')
            ->where('approval_status', 'approved')
            ->where(function ($q) use ($graceCutoff) {
                $q->where('compliance_status', 'active')
                    ->orWhere(function ($q2) use ($graceCutoff) {
                        // 'expiring_soon' still counts as eligible as long as
                        // no critical document (driver's own, or their
                        // truck's) expires within the grace window — mirrors
                        // ComplianceService::isEligibleForShipment(), which
                        // re-checks this same rule at accept-time in PHP.
                        $q2->where('compliance_status', 'expiring_soon')
                            ->whereDoesntHave('documents', fn ($d) => $d
                                ->whereIn('type', ComplianceService::DRIVER_CRITICAL_TYPES)
                                ->where('is_current', true)
                                ->where('expiry_date', '<=', $graceCutoff))
                            ->whereHas('trucks', fn ($t) => $t
                                ->whereDoesntHave('documents', fn ($d) => $d
                                    ->whereIn('type', ComplianceService::TRUCK_CRITICAL_TYPES)
                                    ->where('is_current', true)
                                    ->where('expiry_date', '<=', $graceCutoff)));
                    });
            })
            ->whereDoesntHave('payoutRequests', fn ($q) => $q->whereIn('status', PayoutRequest::BLOCKING_STATUSES))
            // All required driver documents present AND valid.
            ->whereNotNull('license_expiry')
            ->where('license_expiry', '>=', $today)
            ->whereNotNull('passport_expiry')
            ->where('passport_expiry', '>=', $today)
            ->whereNotNull('residency_expiry')
            ->when(
                $offer->order_type === 'external',
                fn ($q) => $q->where('residency_expiry', '>=', now()->addMonths(3)->toDateString()),
                fn ($q) => $q->where('residency_expiry', '>=', $today),
            );

        // Driver covers Origin & Destination: every required country leg
        // needs its own DriverDestination row. Separate whereHas() calls
        // are intentional — each is its own independent EXISTS subquery,
        // so this correctly requires ALL of them, not just one.
        foreach ($requiredCountries as $country) {
            $query->whereHas('destinations', fn ($d) => $d->where('destination', $country));
        }

        // Linked truck exists, active, valid documents, correct type,
        // refrigerated if required, enough capacity — all checked against
        // the SAME truck row in one whereHas() (Driver 1<->1 Truck).
        $query->whereHas('trucks', function ($q) use ($offer, $today) {
            $q->where('is_active', true)
                ->where(fn ($q2) => $q2->whereNull('insurance_expiry')->orWhere('insurance_expiry', '>=', $today))
                ->where(fn ($q2) => $q2->whereNull('license_expiry')->orWhere('license_expiry', '>=', $today))
                ->where(fn ($q2) => $q2->whereNull('technical_inspection_expiry')->orWhere('technical_inspection_expiry', '>=', $today));

            if ($offer->required_truck_type) {
                $q->where('truck_type', $offer->required_truck_type);

                if ($offer->required_truck_type === 'Reefer Trailer') {
                    $q->where('has_refrigeration', true);
                }
            }

            if ($offer->weight !== null) {
                $q->where(fn ($q2) => $q2->whereNull('max_load')->orWhere('max_load', '>=', $offer->weight));
            }
        });

        return $query;
    }

    /**
     * Which DriverDestination country keys a driver must cover to be
     * eligible for this offer. Origin is always the UAE — every company on
     * the platform ships from a UAE base and shipment_offers has no
     * origin_country column yet — so this is the same 'internal_uae' key
     * already used for domestic matching, just also asserted as the
     * "origin leg" for external offers. That means a cross-border trip
     * (e.g. Dubai -> Riyadh) requires a driver to cover BOTH 'internal_uae'
     * AND 'saudi_arabia', not just the destination country.
     *
     * Public (not private) so ShipmentOfferController::accept() can run
     * this exact same check again at accept-time — defense in depth, since
     * a driver reaching accept() through some path other than the app's own
     * (already-filtered) Available Shipments list must still be blocked.
     */
    public function requiredCountriesFor(ShipmentOffer $offer): array
    {
        $origin = 'internal_uae';

        $destination = $offer->order_type === 'internal'
            ? 'internal_uae'
            : Destinations::countryFor($offer->destination);

        return array_values(array_unique(array_filter([$origin, $destination])));
    }

    /**
     * Step 2 — Ranking. Composite score in [0, 1] among drivers who already
     * passed Step 1 in full — truck type/documents/capacity are NOT part of
     * this score, they're binary pass/fail gates above. Weighted mix:
     * Proximity 40% + Rating 25% + Acceptance Reliability 15% +
     * Fairness/Last Matched 10% + Route Experience 10% (all configurable
     * via PlatformSetting, defaults shown here).
     */
    public function score(Driver $driver, ShipmentOffer $offer): float
    {
        $wProximity = (float) PlatformSetting::get('matching_weight_proximity', '0.40');
        $wRating = (float) PlatformSetting::get('matching_weight_rating', '0.25');
        $wAcceptance = (float) PlatformSetting::get('matching_weight_acceptance', '0.15');
        $wFairness = (float) PlatformSetting::get('matching_weight_fairness', '0.10');
        $wRouteExperience = (float) PlatformSetting::get('matching_weight_route_experience', '0.10');

        $proximityScore = $this->proximityScore($driver, $offer);
        $ratingScore = min(1.0, max(0.0, (float) $driver->rating / 5));
        $acceptanceScore = $driver->acceptanceRate();
        $fairnessScore = $this->fairnessScore($driver);
        $routeExperienceScore = $this->routeExperienceScore($driver, $offer);

        return ($wProximity * $proximityScore)
            + ($wRating * $ratingScore)
            + ($wAcceptance * $acceptanceScore)
            + ($wFairness * $fairnessScore)
            + ($wRouteExperience * $routeExperienceScore);
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

    /**
     * Load-balancing / fairness: a driver who was matched very recently
     * scores low here (0 at the instant they were last matched), ramping
     * linearly back up to a full 1.0 once 30+ minutes have passed. A
     * driver who has never been matched (or has no last_matched_at yet)
     * gets the max score, since they're the most "overdue" candidate.
     */
    private function fairnessScore(Driver $driver): float
    {
        if (! $driver->last_matched_at) {
            return 1.0;
        }

        $minutesSince = $driver->last_matched_at->diffInMinutes(now());

        return min(1.0, $minutesSince / 30);
    }

    /**
     * How familiar this driver is with this exact destination, based on
     * their own shipment history — 5+ prior trips there maxes out the
     * score. A simple count rather than a status-filtered one on purpose:
     * even an attempted/in-progress trip to a destination means the driver
     * already knows the route, border crossing, drop-off point, etc.
     */
    private function routeExperienceScore(Driver $driver, ShipmentOffer $offer): float
    {
        $priorTrips = $driver->shipments()->where('destination', $offer->destination)->count();

        return min(1.0, $priorTrips / 5);
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
     * match notification, and advances the offer's matching state. Applies
     * the already-notified exclusion on top of the pure Step 1 eligibility
     * query, since this specifically wants NEW candidates for the next
     * round. Returns the list of newly-matched Driver models (empty when
     * no more eligible drivers exist — caller should escalate to Super
     * Admin).
     */
    public function matchNextBatch(ShipmentOffer $offer): array
    {
        $batchSize = (int) PlatformSetting::get('matching_batch_size', '5');
        $alreadyNotified = $offer->matched_driver_ids ?? [];

        $candidates = $this->eligibleDriversQuery($offer)
            ->whereNotIn('id', $alreadyNotified)
            ->get();

        $ranked = $candidates
            ->map(fn (Driver $d) => ['driver' => $d, 'score' => $this->score($d, $offer)])
            ->sortByDesc('score')
            ->take($batchSize)
            ->values();

        if ($ranked->isEmpty()) {
            $offer->update(['status' => 'escalated']);
            return [];
        }

        $timeoutMinutes = (int) PlatformSetting::get('matching_response_timeout_minutes', '5');
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
