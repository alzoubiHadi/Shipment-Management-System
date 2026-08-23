<?php

namespace App\Console\Commands;

use App\Models\PriceListEntry;
use Illuminate\Console\Command;

/**
 * 2026-08-29: read-only helper for a presentation slide ("from historical
 * data to a data-driven system") — pulls ONE real, well-supported
 * origin+destination+truck_type lane from price_list_entries to use as a
 * concrete example instead of a purely theoretical slide. No writes.
 */
class PricingSlideExample extends Command
{
    protected $signature = 'data:pricing-slide-example {--count=3 : how many example lanes to print}';

    protected $description = 'Read-only: print real origin/destination/truck-type pricing lanes for a presentation slide.';

    public function handle(): int
    {
        $n = (int) $this->option('count');

        $this->info('=== Real pricing lanes (highest historical_trip_count first) ===');
        $this->newLine();

        $entries = PriceListEntry::whereNotNull('origin_zone_id')
            ->whereNotNull('destination_zone_id')
            ->whereNotNull('historical_trip_count')
            ->with(['originZone', 'destinationZone'])
            ->orderByDesc('historical_trip_count')
            ->take($n)
            ->get();

        if ($entries->isEmpty()) {
            $this->warn('No zone-based price_list_entries rows with historical_trip_count found.');

            return self::SUCCESS;
        }

        foreach ($entries as $e) {
            $origin = $e->originZone?->displayLabel() ?? "zone#{$e->origin_zone_id}";
            $dest = $e->destinationZone?->displayLabel() ?? "zone#{$e->destination_zone_id}";

            $this->line("Lane: {$origin}  ->  {$dest}   truck_type={$e->truck_type}" . ($e->truck_size ? " ({$e->truck_size})" : ''));
            $this->line("  historical_trip_count (sample size) = {$e->historical_trip_count}");
            $this->line('  median_base_price = ' . ($e->median_base_price ?? 'n/a'));
            $this->line('  median_charges    = ' . ($e->median_charges ?? 'n/a'));
            $this->line('  reference_price   = ' . ($e->reference_price ?? 'n/a'));
            $this->line('  suggested_low (P25)  = ' . ($e->suggested_low ?? 'n/a'));
            $this->line('  suggested_high (P75) = ' . ($e->suggested_high ?? 'n/a'));
            $this->line('  confidence        = ' . ($e->confidence ?? 'n/a'));
            $this->line('  pricing_level     = ' . ($e->pricing_level ?? 'n/a'));
            $this->line('  last_historical_date = ' . ($e->last_historical_date ?? 'n/a'));
            $this->newLine();
        }

        $this->info('=== END — read-only, no data changed ===');

        return self::SUCCESS;
    }
}
