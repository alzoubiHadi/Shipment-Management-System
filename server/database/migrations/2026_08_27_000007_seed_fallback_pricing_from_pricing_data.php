<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Seeds `fallback_pricing` with 60 country-to-country x truck-type
     * rows (FMS_Pricing_Data_FINAL.xlsx's Fallback_Pricing sheet, 71 raw
     * rows collapsed to 60 after mapping the sheet's 8 broad truck types
     * onto this system's canonical Truck::TRUCK_TYPES — same mapping and
     * same "keep the larger sample size on collision" rule as
     * 2026_08_27_000006's lane-pricing import; see that migration's
     * docblock for the full mapping table). Used by PricingService::
     * getPriceSuggestion() only when no exact zone-pair lane exists in
     * price_list_entries for a given offer.
     */
    public function up(): void
    {
        // [origin_country, destination_country, truck_type, historical_trip_count,
        //  median_total, typical_low, typical_high, recent_90d_count,
        //  recent_90d_median, reference_price, pricing_level]
        $rows = [
            ['UAE', 'UAE', 'Trailer 40 FT-12M-Open', 650, 1400.0, 850.0, 1900.0, 249, 1900.0, 1900.0, 'Country-to-Country + Truck'],
            ['UAE', 'UAE', 'Reefer Trailer', 302, 1200.0, 925.0, 1200.0, 159, 1200.0, 1200.0, 'Country-to-Country + Truck'],
            ['UAE', 'UAE', '7 Ton pick up', 240, 700.0, 550.0, 1100.0, 112, 900.0, 900.0, 'Country-to-Country + Truck'],
            ['KSA', 'UAE', 'Trailer 40 FT-12M-Open', 145, 2945.0, 2347.5, 4110.0, 36, 3345.0, 3345.0, 'Country-to-Country + Truck'],
            ['UAE', 'KSA', 'Trailer 40 FT-12M-Open', 133, 5980.0, 4650.0, 7000.0, 71, 6900.0, 6900.0, 'Country-to-Country + Truck'],
            ['OMAN', 'UAE', 'Trailer 40 FT-12M-Open', 94, 2800.0, 2540.0, 3710.5, 35, 3760.0, 3760.0, 'Country-to-Country + Truck'],
            ['UAE', 'KSA', '7 Ton pick up', 89, 3340.0, 2840.0, 4040.0, 46, 3590.0, 3590.0, 'Country-to-Country + Truck'],
            ['UAE', 'KSA', 'Trailer 40 FT-12M-Box', 89, 6775.0, 6400.0, 7000.0, 54, 6900.0, 6900.0, 'Country-to-Country + Truck'],
            ['UAE', 'OMAN', 'Trailer 40 FT-12M-Open', 82, 2370.5, 2340.5, 4255.0, 32, 4405.5, 4405.5, 'Country-to-Country + Truck'],
            ['KSA', 'UAE', 'Reefer Trailer', 77, 3700.0, 2300.0, 5700.0, 33, 5400.0, 5400.0, 'Country-to-Country + Truck'],
            ['UAE', 'KSA', 'Curtain Trailer 13.5M', 57, 5840.0, 4700.0, 6700.0, 27, 6130.0, 6130.0, 'Country-to-Country + Truck'],
            ['UAE', 'KUWAIT', 'Reefer Trailer', 49, 8650.0, 6600.0, 8800.0, 28, 8800.0, 8800.0, 'Country-to-Country + Truck'],
            ['UAE', 'KUWAIT', 'Trailer 40 FT-12M-Open', 47, 7095.0, 6500.0, 7930.0, 14, 8230.0, 8230.0, 'Country-to-Country + Truck'],
            ['UAE', 'OMAN', 'Reefer Trailer', 44, 3842.62, 3527.41, 4477.88, 21, 4424.4, 4424.4, 'Country-to-Country + Truck'],
            ['UAE', 'UAE', 'Lowbed Trailer - 25 Tons', 42, 3900.0, 3500.0, 5100.0, 28, 3500.0, 3500.0, 'Country-to-Country + Truck'],
            ['UAE', 'QATAR', 'Reefer Trailer', 28, 5460.0, 5030.0, 6403.75, 11, 6790.0, 6790.0, 'Country-to-Country + Truck'],
            ['UAE', 'QATAR', 'Trailer 40 FT-12M-Box', 27, 4685.0, 4660.0, 5900.0, 8, 6460.0, 6460.0, 'Country-to-Country + Truck'],
            ['UAE', 'BAHRAIN', 'Reefer Trailer', 26, 6990.5, 5713.88, 8000.0, 12, 8079.5, 8079.5, 'Country-to-Country + Truck'],
            ['UAE', 'QATAR', '7 Ton pick up', 25, 4090.0, 3290.0, 4690.0, 12, 4675.0, 4675.0, 'Country-to-Country + Truck'],
            ['UAE', 'OMAN', '7 Ton pick up', 23, 2480.5, 2258.68, 2800.38, 18, 2480.5, 2480.5, 'Country-to-Country + Truck'],
            ['UAE', 'QATAR', 'Trailer 40 FT-12M-Open', 19, 5190.0, 4555.0, 5730.0, 8, 5730.0, 5730.0, 'Country-to-Country + Truck'],
            ['UAE', 'BAHRAIN', 'Trailer 40 FT-12M-Box', 17, 6500.0, 5635.0, 7377.0, 10, 7263.9, 7263.9, 'Country-to-Country + Truck'],
            ['OMAN', 'UAE', 'Lowbed Trailer - 25 Tons', 16, 6420.25, 5445.0, 6980.5, 10, 6970.5, 6970.5, 'Country-to-Country + Truck'],
            ['UAE', 'KSA', 'Reefer Trailer', 16, 6110.0, 5381.25, 8378.5, 6, 8482.0, 8482.0, 'Country-to-Country + Truck'],
            ['UAE', 'KUWAIT', 'Trailer 40 FT-12M-Box', 16, 8601.25, 7637.5, 9462.38, 8, 9505.75, 9505.75, 'Country-to-Country + Truck'],
            ['UAE', 'OMAN', 'Curtain Trailer 13.5M', 15, 2730.5, 2530.0, 3455.0, 4, 3500.0, 3500.0, 'Country-to-Country + Truck'],
            ['KSA', 'UAE', '7 Ton pick up', 14, 1800.0, 1465.0, 3335.0, 5, 1800.0, 1800.0, 'Country-to-Country + Truck'],
            ['KSA', 'UAE', 'Curtain Trailer 13.5M', 13, 3405.0, 3192.0, 4230.0, 10, 3610.0, 3610.0, 'Country-to-Country + Truck'],
            ['OMAN', 'QATAR', 'Trailer 40 FT-12M-Open', 11, 7775.0, 7175.0, 9335.0, 5, 9370.0, 9370.0, 'Country-to-Country + Truck'],
            ['UAE', 'KUWAIT', 'Lowbed Trailer - 25 Tons', 10, 8880.0, 8680.0, 9680.0, 6, 9430.0, 9430.0, 'Country-to-Country + Truck'],
            ['UAE', 'KUWAIT', '7 Ton pick up', 9, 5060.0, 4880.0, 6472.0, 2, null, 5060.0, 'Country-to-Country + Truck'],
            ['UAE', 'JORDAN', 'Reefer Trailer', 9, 15000.0, 11500.0, 16028.4, 6, 15514.2, 15514.2, 'Country-to-Country + Truck'],
            ['UAE', 'KSA', 'Lowbed Trailer - 25 Tons', 9, 8240.0, 8240.0, 18960.0, 8, 8240.0, 8240.0, 'Country-to-Country + Truck'],
            ['JORDAN', 'UAE', 'Trailer 40 FT-12M-Box', 9, 11099.67, 11047.38, 11099.67, 3, null, 11099.67, 'Country-to-Country + Truck'],
            ['UAE', 'BAHRAIN', '7 Ton pick up', 7, 4105.0, 3920.0, 4419.5, 1, null, 4105.0, 'Country-to-Country + Truck'],
            ['UAE', 'UAE', 'Curtain Trailer 13.5M', 6, 2220.0, 1192.5, 2280.0, 2, null, 2220.0, 'Country-to-Country + Truck'],
            ['UAE', 'BAHRAIN', 'Trailer 40 FT-12M-Open', 6, 5952.5, 4928.0, 6770.0, 2, null, 5952.5, 'Country-to-Country + Truck'],
            ['UAE', 'UAE', 'Trailer 40 FT-12M-Box', 6, 1600.0, 1353.75, 1827.88, 3, null, 1600.0, 'Country-to-Country + Truck'],
            ['OMAN', 'OMAN', 'Trailer 40 FT-12M-Open', 5, 1946.67, 1940.0, 1946.67, 0, null, 1946.67, 'Country-to-Country + Truck'],
            ['UAE', 'IRAQ', 'Trailer 40 FT-12M-Open', 5, 10200.0, 10200.0, 12730.0, 2, null, 10200.0, 'Country-to-Country + Truck'],
            ['BAHRAIN', 'UAE', 'Trailer 40 FT-12M-Box', 5, 3791.7, 3458.5, 3824.0, 3, null, 3791.7, 'Country-to-Country + Truck'],
            ['UAE', 'QATAR', 'Lowbed Trailer - 25 Tons', 5, 7100.0, 6310.0, 7380.0, 4, 7240.0, 7240.0, 'Country-to-Country + Truck'],
            ['OMAN', 'QATAR', 'Trailer 40 FT-12M-Box', 4, 9210.0, 9060.0, 9395.0, 4, 9210.0, 9210.0, 'Country-to-Country + Truck'],
            ['UAE', 'JORDAN', 'Trailer 40 FT-12M-Open', 3, 11500.0, 8250.0, 12400.0, 2, null, 11500.0, 'Country-to-Country + Truck'],
            ['BAHRAIN', 'UAE', 'Reefer Trailer', 3, 3775.5, 3740.25, 3775.5, 1, null, 3775.5, 'Country-to-Country + Truck'],
            ['KSA', 'KSA', 'Trailer 40 FT-12M-Open', 2, 650.0, 575.0, 725.0, 1, null, 650.0, 'Country-to-Country + Truck'],
            ['UAE', 'JORDAN', 'Trailer 40 FT-12M-Box', 2, 10595.0, 9447.5, 11742.5, 1, null, 10595.0, 'Country-to-Country + Truck'],
            ['OMAN', 'UAE', 'Curtain Trailer 13.5M', 2, 3970.5, 3970.5, 3970.5, 2, null, 3970.5, 'Country-to-Country + Truck'],
            ['SYRIA', 'UAE', '7 Ton pick up', 1, 350.0, 350.0, 350.0, 0, null, 350.0, 'Country-to-Country + Truck'],
            ['KSA', 'UAE', 'Lowbed Trailer - 25 Tons', 1, 6345.0, 6345.0, 6345.0, 0, null, 6345.0, 'Country-to-Country + Truck'],
            ['OMAN', 'UAE', 'Reefer Trailer', 1, 7370.0, 7370.0, 7370.0, 0, null, 7370.0, 'Country-to-Country + Truck'],
            ['QATAR', 'UAE', '7 Ton pick up', 1, 3460.0, 3460.0, 3460.0, 0, null, 3460.0, 'Country-to-Country + Truck'],
            ['UAE', 'OMAN', 'Trailer 40 FT-12M-Box', 1, 7800.0, 7800.0, 7800.0, 1, null, 7800.0, 'Country-to-Country + Truck'],
            ['KSA', 'UAE', 'Trailer 40 FT-12M-Box', 1, 4300.0, 4300.0, 4300.0, 1, null, 4300.0, 'Country-to-Country + Truck'],
            ['KSA', 'KSA', '7 Ton pick up', 1, 770.0, 770.0, 770.0, 1, null, 770.0, 'Country-to-Country + Truck'],
            ['OMAN', 'UAE', 'Trailer 40 FT-12M-Box', 1, 4235.25, 4235.25, 4235.25, 1, null, 4235.25, 'Country-to-Country + Truck'],
            ['OMAN', 'UAE', '7 Ton pick up', 1, 1960.5, 1960.5, 1960.5, 1, null, 1960.5, 'Country-to-Country + Truck'],
            ['UAE', 'SYRIA', 'Reefer Trailer', 1, 13701.6, 13701.6, 13701.6, 1, null, 13701.6, 'Country-to-Country + Truck'],
            ['KSA', 'QATAR', '7 Ton pick up', 1, 2650.0, 2650.0, 2650.0, 1, null, 2650.0, 'Country-to-Country + Truck'],
            ['KUWAIT', 'UAE', 'Reefer Trailer', 1, 1700.0, 1700.0, 1700.0, 1, null, 1700.0, 'Country-to-Country + Truck'],
        ];

        $now = now();
        $data = array_map(function ($row) use ($now) {
            return [
                'origin_country' => $row[0],
                'destination_country' => $row[1],
                'truck_type' => $row[2],
                'historical_trip_count' => $row[3],
                'median_total' => $row[4],
                'typical_low' => $row[5],
                'typical_high' => $row[6],
                'recent_90d_count' => $row[7],
                'recent_90d_median' => $row[8],
                'reference_price' => $row[9],
                'pricing_level' => $row[10],
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }, $rows);

        foreach (array_chunk($data, 100) as $chunk) {
            DB::table('fallback_pricing')->upsert(
                $chunk,
                ['origin_country', 'destination_country', 'truck_type'],
                ['historical_trip_count', 'median_total', 'typical_low', 'typical_high', 'recent_90d_count',
                    'recent_90d_median', 'reference_price', 'pricing_level', 'updated_at'],
            );
        }
    }

    public function down(): void
    {
        // No-op — see 2026_08_27_000002's down() for the same reasoning.
    }
};
