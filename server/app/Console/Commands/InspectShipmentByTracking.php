<?php

namespace App\Console\Commands;

use App\Models\Shipment;
use Illuminate\Console\Command;

/**
 * 2026-08-28 (support request): READ-ONLY — full dump of one shipment by
 * tracking number, plus every other table that references it, so we can
 * see exactly what deleting it would touch before doing anything.
 *
 * Usage: php artisan data:inspect-shipment TRK6A81F6C668BCC
 */
class InspectShipmentByTracking extends Command
{
    protected $signature = 'data:inspect-shipment {tracking}';

    protected $description = 'Read-only dump of one shipment (by tracking number) and everything referencing it';

    public function handle(): int
    {
        $shipment = Shipment::where('tracking_number', $this->argument('tracking'))->first();

        if (! $shipment) {
            $this->error('No shipment found with that tracking number.');
            return self::FAILURE;
        }

        $this->info('=== SHIPMENT ===');
        foreach ($shipment->getAttributes() as $key => $value) {
            $this->line("  {$key} = " . ($value ?? 'NULL'));
        }
        $this->newLine();

        $this->info('=== REFERENCED BY ===');
        $this->line('financial_transactions (reference_type=Shipment): '
            . \App\Models\FinancialTransaction::where('reference_type', 'Shipment')->where('reference_id', $shipment->id)->count());
        $this->line('shipment_comments: ' . \App\Models\ShipmentComment::where('shipment_id', $shipment->id)->count());
        $this->line('driver_ratings: ' . \App\Models\DriverRating::where('shipment_id', $shipment->id)->count());
        $this->line('shipment_offer (parent, shipment_offer_id=' . ($shipment->shipment_offer_id ?? 'NULL') . '): '
            . (\App\Models\ShipmentOffer::where('id', $shipment->shipment_offer_id)->exists() ? 'exists' : 'missing/none'));

        return self::SUCCESS;
    }
}
