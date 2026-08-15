<?php

namespace App\Console\Commands;

use App\Models\ShipmentOffer;
use App\Services\MatchingService;
use Illuminate\Console\Command;

/**
 * UC-16: for every 'pending' offer whose current matching round timed out
 * without an acceptance, push the next batch of up to 5 drivers. When no
 * eligible drivers remain, MatchingService::matchNextBatch() itself flips
 * the offer to 'escalated' for Super Admin manual assignment (UC-17).
 *
 * Must run on a schedule to actually do anything — registered in
 * bootstrap/app.php's withSchedule() to run every minute. In production
 * that requires a real cron entry running `php artisan schedule:run` every
 * minute (see Laravel's scheduler docs); in local dev, run
 * `php artisan schedule:work` in its own terminal while testing.
 */
class ProcessExpiredMatches extends Command
{
    protected $signature = 'offers:process-expired-matches';

    protected $description = 'Re-match (or escalate) every pending shipment offer whose matching round has timed out';

    public function handle(MatchingService $matchingService): int
    {
        $expired = ShipmentOffer::where('status', 'pending')
            ->where('expires_at', '<=', now())
            ->get();

        foreach ($expired as $offer) {
            $matched = $matchingService->matchNextBatch($offer);

            $this->info($matched
                ? "Offer #{$offer->id}: re-matched to " . count($matched) . ' driver(s)'
                : "Offer #{$offer->id}: no eligible drivers left — escalated");
        }

        if ($expired->isEmpty()) {
            $this->info('No expired matching rounds to process.');
        }

        return self::SUCCESS;
    }
}
