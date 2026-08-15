<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Real AED price matrix from the client's own "المتطلبات الجديدة.docx"
     * (re-extracted directly from the uploaded table, not invented). Blank
     * cells in the source document (e.g. no 3-ton pickup rate to Amman)
     * are intentionally left out of price_list_entries entirely — that
     * combination simply has no row, so an offer for it correctly falls
     * back to manual pricing (UC-13) instead of getting a wrong $0 price.
     * Sanaa-Yemen had no prices at all in the source table, so it has zero
     * rows here on purpose (always manual until Finance Admin sets one).
     *
     * Column order matches Truck::TRUCK_TYPES exactly:
     * 3 Ton pick up, 7 Ton pick up, 10 Ton pick up, Trailer 40 FT-12M-Open,
     * Trailer 40 FT-12M-Box, Trailer 50 FT-15M-Open, Curtain Trailer 13.5M,
     * Curtain Trailer 15M, Reefer Trailer, Lowbed Trailer - 25 Tons, Car Career.
     */
    public function up(): void
    {
        $truckTypes = [
            '3 Ton pick up',
            '7 Ton pick up',
            '10 Ton pick up',
            'Trailer 40 FT-12M-Open',
            'Trailer 40 FT-12M-Box',
            'Trailer 50 FT-15M-Open',
            'Curtain Trailer 13.5M',
            'Curtain Trailer 15M',
            'Reefer Trailer',
            'Lowbed Trailer - 25 Tons',
            'Car Career',
        ];

        $matrix = [
            'Dammam/Khobar/Hasa' => [2200, 3100, 3200, 3200, 4300, 3900, 3500, 4200, 3500, 4100, 6400],
            'Riyadh' => [2200, 3100, 3200, 3200, 4300, 3900, 3500, 4200, 3600, 4100, 6400],
            'Jubail' => [2300, 3200, 3300, 3200, 4400, 4000, 3600, 4300, 3700, 4200, 6500],
            'Qaseem' => [2600, 3500, 3600, 4000, 4600, 4200, 4100, 4500, 3900, 4400, 6900],
            'Jeddah/Madina/Mecca/Taif' => [2800, 4200, 4400, 4200, 5400, 5300, 4600, 5300, 4600, 5400, 7400],
            'Kuwait' => [null, 3800, 4100, 4200, 4200, 4900, null, null, 4000, 5300, 6800],
            'Bahrain' => [2200, 2900, 3000, 3000, 3500, 4000, null, null, 3500, 4200, 5200],
            'Sohar-Oman' => [null, 1500, 1700, 2000, 2200, 2400, 1600, 1800, 2100, 2800, 2600],
            'Muscat-Oman' => [null, 1700, 1900, 2100, 2300, 2500, 1700, 1900, 2500, 2900, 2700],
            'Amman-Jordan' => [null, null, null, 10100, 12900, 12400, null, null, 11300, 13300, 13300],
            'Beirut-Lebanon' => [null, null, null, 16100, 17100, 19200, null, null, 15000, 19500, 24500],
            'Damascus-Syria' => [null, null, null, 15600, 16100, 18100, null, null, 15500, 15000, 23500],
            'Cairo-Egypt' => [null, null, null, 12600, 13600, 14600, null, null, 14000, 18500, 21000],
            'Iraqi-Border' => [null, null, null, 13600, 14600, 15600, null, null, 15000, 19000, 22000],
            // Sanaa-Yemen: no prices in the source document — no rows.
        ];

        $now = now();
        $rows = [];

        foreach ($matrix as $destination => $prices) {
            foreach ($prices as $i => $price) {
                if ($price === null) {
                    continue;
                }

                $rows[] = [
                    'destination' => $destination,
                    'truck_type' => $truckTypes[$i],
                    'base_price' => $price,
                    'created_at' => $now,
                    'updated_at' => $now,
                ];
            }
        }

        // Chunk the insert to stay well under SQLite's bound-parameter limit.
        foreach (array_chunk($rows, 100) as $chunk) {
            DB::table('price_list_entries')->insert($chunk);
        }
    }

    public function down(): void
    {
        DB::table('price_list_entries')->truncate();
    }
};
