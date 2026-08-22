<?php

namespace App\Console\Commands;

use App\Models\Shipment;
use Illuminate\Console\Command;

/**
 * 2026-08-28 (support request, driver alzoubi.0020@gmail.com /
 * TRK6A81F6C668BCC): a handful of shipments created before a fix that syncs
 * the coarse `status` column to 3 (Delivered) once the driver's stage
 * timeline reaches its final stage and the company confirms receipt got
 * "stuck" on an earlier status (e.g. 1 / In Transit) forever — which then
 * keeps the app treating the driver as having a permanently active trip.
 *
 * Deliberately a targeted UPDATE, not a DELETE: this shipment already has
 * real linked financial_transactions/comments/rating history (see the
 * read-only data:inspect-shipment / data:inspect-shipment-finance audits
 * run before this) — deleting it would leave that ledger pointing at
 * nothing. Fixing the one wrong column preserves everything else.
 *
 * Refuses to touch a shipment unless BOTH safety conditions hold —
 * current_stage is already at the final stage for its order_type, AND
 * delivery_status is 'confirmed' — so this can't be mis-used on a shipment
 * that's actually still genuinely in progress or disputed. Asks for
 * interactive confirmation before writing.
 *
 * Usage: php artisan data:fix-stuck-delivered TRK6A81F6C668BCC
 */
class FixStuckDeliveredShipment extends Command
{
    protected $signature = 'data:fix-stuck-delivered {tracking}';

    protected $description = 'Set status=Delivered on a shipment whose stage timeline/delivery_status show it actually finished, but status never followed';

    const STATUS_DELIVERED = 3;

    public function handle(): int
    {
        $shipment = Shipment::where('tracking_number', $this->argument('tracking'))->first();

        if (! $shipment) {
            $this->error('No shipment found with that tracking number.');
            return self::FAILURE;
        }

        $totalStages = Shipment::totalStagesFor($shipment->order_type ?? 'internal');

        $this->info("shipment #{$shipment->id}  tracking={$shipment->tracking_number}");
        $this->line("  current status = {$shipment->status}");
        $this->line("  current_stage = {$shipment->current_stage} / {$totalStages} (order_type=" . ($shipment->order_type ?? 'internal') . ')');
        $this->line("  delivery_status = {$shipment->delivery_status}");
        $this->newLine();

        if ($shipment->status == self::STATUS_DELIVERED) {
            $this->info('status is already 3 (Delivered) — nothing to do.');
            return self::SUCCESS;
        }

        if ((int) $shipment->current_stage !== $totalStages || $shipment->delivery_status !== 'confirmed') {
            $this->error('Safety check failed: this shipment is not actually at its final stage with a confirmed delivery — refusing to change its status.'
                . ' If you believe this shipment should still be fixed, it needs manual review, not this command.');
            return self::FAILURE;
        }

        if (! $this->confirm("Set shipment #{$shipment->id}'s status from {$shipment->status} to 3 (Delivered)? Nothing else is touched.")) {
            $this->info('Cancelled — no changes made.');
            return self::SUCCESS;
        }

        $shipment->update(['status' => self::STATUS_DELIVERED]);

        $this->info("Done. shipment #{$shipment->id} status is now {$shipment->fresh()->status}.");

        return self::SUCCESS;
    }
}
