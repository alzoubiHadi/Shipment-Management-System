<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Seeds the 164 canonical zones from FMS_Pricing_Data_FINAL.xlsx's
     * Final_Zones sheet (2026-08-27, provided by the team). Each row is
     * [country, city, canonical zone name, zone type]. This is the
     * "final clean" output of a separate normalization pass over ~2,100
     * historical ALBATRANS trip lines and 258 raw-string aliases — the
     * alias mapping itself isn't imported anywhere in the app; it only
     * mattered for producing this already-normalized list and the
     * Final_Lane_Pricing rows seeded in
     * 2026_08_27_000004_seed_price_list_from_pricing_data.php, which
     * already reference these same canonical zone names.
     */
    public function up(): void
    {
        $rows = [
            ['BAHRAIN', null, 'BAHRAIN', 'Area / City'],
            ['IRAQ', 'Safwan', 'SAFWAN', 'Area / City'],
            ['JORDAN', 'Amman', 'AMMAN', 'Area / City'],
            ['JORDAN', 'Aqaba', 'AQABA', 'Area / City'],
            ['JORDAN', null, 'JOR', 'Area / City'],
            ['JORDAN', null, 'JORDAN GENERAL', 'Country / General'],
            ['JORDAN', 'Irbid', 'SHEIKH HUSSEIN BRIDGE', 'Area / City'],
            ['JORDAN', 'Zarqa', 'ZARQA', 'Area / City'],
            ['KSA', 'Abha', 'ABHA', 'Area / City'],
            ['KSA', 'Al Batha', 'AL BATHA', 'Area / City'],
            ['KSA', 'Al Ahsa', 'AL HASSA', 'Area / City'],
            ['KSA', 'Al Ahsa', 'AL HOFUF', 'Area / City'],
            ['KSA', 'Al Kharj', 'AL KHARJ', 'Area / City'],
            ['KSA', 'Al Khobar', 'AL KHOBAR', 'Area / City'],
            ['KSA', null, 'AL KHOBAR / RIYADH', 'Area / City'],
            ['KSA', 'Riyadh', 'AL NARIYAH', 'Area / City'],
            ['KSA', 'Al Qassim', 'AL QASSEM', 'Area / City'],
            ['KSA', 'Tabuk', 'AMALA', 'Area / City'],
            ['KSA', 'Arar', 'ARAR', 'Area / City'],
            ['KSA', 'Abha', 'ASIR', 'Area / City'],
            ['KSA', null, 'BADAR', 'Area / City'],
            ['KSA', null, 'BADER', 'Area / City'],
            ['KSA', 'Dammam', 'DAMMAM', 'Area / City'],
            ['KSA', 'Duba', 'DUBA', 'Area / City'],
            ['KSA', 'Riyadh', 'HAYAT MALL', 'Area / City'],
            ['KSA', 'Jeddah', 'JEDDAH', 'Area / City'],
            ['KSA', 'Jeddah', 'JEDDAH ISLAMIC PORT', 'Logistics / Industrial'],
            ['KSA', 'Jubail', 'JUBAIL', 'Area / City'],
            ['KSA', 'Dammam', 'KFIA', 'Airport'],
            ['KSA', 'Khamis Mushait', 'KHAMIS MUSHAIT', 'Area / City'],
            ['KSA', 'Jeddah', 'KING ABDULLAH ECONOMIC CITY', 'Area / City'],
            ['KSA', 'Madinah', 'MADINAH', 'Area / City'],
            ['KSA', 'Makkah', 'MAKKAH', 'Area / City'],
            ['KSA', 'Tabuk', 'NEOM', 'Area / City'],
            ['KSA', 'Rabigh', 'RABIGH', 'Area / City'],
            ['KSA', null, 'RED SEA', 'Area / City'],
            ['KSA', 'Riyadh', 'RIYADH', 'Area / City'],
            ['KSA', null, 'RIYADH / AL QASSEM', 'Area / City'],
            ['KSA', 'Rumah', 'RUMAH', 'Area / City'],
            ['KSA', 'Riyadh', 'SUDHAIR', 'Area / City'],
            ['KSA', 'Tanajib', 'TANAJEEB', 'Area / City'],
            ['KSA', 'Turaif', 'TURAIF', 'Area / City'],
            ['KSA', 'Wadi Al Dawasir', 'WADI AL DAWASIR', 'Area / City'],
            ['KSA', 'Yanbu', 'YANBU', 'Area / City'],
            ['KUWAIT', null, 'KUWAIT', 'Area / City'],
            ['OMAN', 'Barka', 'BARKA', 'Area / City'],
            ['OMAN', 'Muscat', 'BARKA / MISFA', 'Area / City'],
            ['OMAN', 'Duqm', 'DUQM', 'Area / City'],
            ['OMAN', 'Muscat', 'GHALA', 'Area / City'],
            ['OMAN', 'Muscat', 'MABELA', 'Area / City'],
            ['OMAN', 'Muscat', 'MISFA', 'Area / City'],
            ['OMAN', 'Muscat', 'MUSCAT', 'Area / City'],
            ['OMAN', 'Nizwa', 'NIZWA', 'Area / City'],
            ['OMAN', null, 'OMAN GENERAL', 'Country / General'],
            ['OMAN', 'Salalah', 'SALALAH', 'Area / City'],
            ['OMAN', 'Sohar', 'SOHAR', 'Area / City'],
            ['OMAN', 'Muscat', 'WADI KABER', 'Area / City'],
            ['QATAR', 'Doha', 'DOHA', 'Area / City'],
            ['QATAR', 'Doha', 'QATAR', 'Area / City'],
            ['SYRIA', 'Daraa', "DARA'A", 'Area / City'],
            ['SYRIA', 'Idlib', 'IDLIB', 'Area / City'],
            ['UAE', 'Abu Dhabi', 'ABU DHABI', 'Area / City'],
            ['UAE', 'Abu Dhabi', 'AD AIRPORT', 'Airport'],
            ['UAE', 'Ajman', 'AJMAN', 'Area / City'],
            ['UAE', 'Al Ain', 'AL AIN', 'Area / City'],
            ['UAE', 'Dubai', 'AL AWEER', 'Area / City'],
            ['UAE', 'Dubai', 'AL AWIR', 'Area / City'],
            ['UAE', 'Dubai', 'AL BARARI', 'Area / City'],
            ['UAE', 'Dubai', 'AL BARSHA', 'Area / City'],
            ['UAE', 'Fujairah', 'AL BIDYAH', 'Area / City'],
            ['UAE', 'Abu Dhabi', 'AL FAYA', 'Area / City'],
            ['UAE', 'Dubai', 'AL GARHOUD', 'Area / City'],
            ['UAE', 'Ras Al Khaimah', 'AL GHAIL', 'Area / City'],
            ['UAE', 'Ras Al Khaimah', 'AL HAMRA', 'Area / City'],
            ['UAE', 'Dubai', 'AL KHAWANEEJ', 'Area / City'],
            ['UAE', 'Al Ain', 'AL KHUBAISI', 'Area / City'],
            ['UAE', 'Abu Dhabi', 'AL MARFA', 'Area / City'],
            ['UAE', 'Abu Dhabi', 'AL MARYAH ISLAND', 'Area / City'],
            ['UAE', 'Dubai', 'AL QUOZ', 'Area / City'],
            ['UAE', 'Dubai', 'AL QUOZ / JAFZA', 'Area / City'],
            ['UAE', 'Abu Dhabi', 'AL REEM ISLAND', 'Area / City'],
            ['UAE', 'Dubai', 'AL RUWAYYAH', 'Area / City'],
            ['UAE', 'Abu Dhabi', 'AL SAAD', 'Area / City'],
            ['UAE', 'Dubai', 'AL SAFA', 'Area / City'],
            ['UAE', 'Fujairah', 'AL TAWEEN', 'Area / City'],
            ['UAE', 'Abu Dhabi', 'AL WATHBA', 'Area / City'],
            ['UAE', 'Sharjah', 'AL ZAHIA', 'Area / City'],
            ['UAE', 'Abu Dhabi', 'BANI YAS', 'Area / City'],
            ['UAE', 'Abu Dhabi', 'BARAKAH', 'Area / City'],
            ['UAE', 'Dubai', 'BARSHA', 'Area / City'],
            ['UAE', 'Dubai', 'BUR DUBAI', 'Area / City'],
            ['UAE', 'Dubai', 'BUSINESS BAY', 'Area / City'],
            ['UAE', null, 'CARREFOUR - UAE', 'Area / City'],
            ['UAE', 'Dubai', 'DAMAC HILLS', 'Area / City'],
            ['UAE', 'Dubai', 'DIC', 'Industrial'],
            ['UAE', 'Dubai', 'DIC / DIP', 'Industrial'],
            ['UAE', 'Dubai', 'DIP', 'Industrial'],
            ['UAE', 'Dubai', 'DIP / DIC', 'Industrial'],
            ['UAE', 'Dubai', 'DUBAI DESIGN DISTRICT', 'Area / City'],
            ['UAE', 'Dubai', 'DUBAI HILLS', 'Area / City'],
            ['UAE', 'Dubai', 'DUBAI ISLAND', 'Area / City'],
            ['UAE', 'Dubai', 'DUBAI LAND', 'Area / City'],
            ['UAE', 'Dubai', 'DUBAI MALL', 'Area / City'],
            ['UAE', 'Dubai', 'DUBAI MARINA', 'Area / City'],
            ['UAE', 'Dubai', 'DUBAI SILICON OASIS', 'Area / City'],
            ['UAE', 'Dubai', 'DUBAI SOUTH', 'Area / City'],
            ['UAE', 'Dubai', 'DUBAI SPORTS CITY', 'Logistics / Industrial'],
            ['UAE', 'Dubai', 'DUBAI STUDIO CITY', 'Area / City'],
            ['UAE', 'Dubai', 'DWC', 'Logistics / Industrial'],
            ['UAE', 'Dubai', 'DXB', 'Area / City'],
            ['UAE', 'Dubai', 'DXB AIRPORT', 'Airport'],
            ['UAE', 'Dubai', 'DXB PALM', 'Area / City'],
            ['UAE', 'Fujairah', 'FUJ', 'Area / City'],
            ['UAE', 'Abu Dhabi', 'GHAYATHI', 'Area / City'],
            ['UAE', 'Abu Dhabi', 'HABSHAN', 'Area / City'],
            ['UAE', 'Abu Dhabi', 'HAMEEM', 'Area / City'],
            ['UAE', 'Sharjah', 'HAMRIYAH', 'Logistics / Industrial'],
            ['UAE', 'Abu Dhabi', 'ICAD', 'Industrial'],
            ['UAE', 'Dubai', 'JAFZA', 'Logistics / Industrial'],
            ['UAE', 'Dubai', 'JAFZA / AL AWEER', 'Area / City'],
            ['UAE', 'Dubai', 'JAFZA / AL QUOZ', 'Area / City'],
            ['UAE', 'Dubai', 'JEBEL ALI', 'Area / City'],
            ['UAE', 'Dubai', 'JLT', 'Area / City'],
            ['UAE', null, 'JUMERA', 'Area / City'],
            ['UAE', 'Dubai', 'JVC', 'Area / City'],
            ['UAE', 'Sharjah', 'KALBA', 'Area / City'],
            ['UAE', 'Sharjah', 'KHALID PORT', 'Logistics / Industrial'],
            ['UAE', 'Abu Dhabi', 'KHALIFA PORT', 'Logistics / Industrial'],
            ['UAE', 'Sharjah', 'KHOR FAKKAN', 'Area / City'],
            ['UAE', 'Abu Dhabi', 'KIZAD', 'Logistics / Industrial'],
            ['UAE', 'Dubai', 'LAHBAB', 'Area / City'],
            ['UAE', 'Abu Dhabi', 'MADINAT ZAYED', 'Area / City'],
            ['UAE', 'Abu Dhabi', 'MAFRAQ', 'Area / City'],
            ['UAE', 'Dubai', 'MAYDAN', 'Area / City'],
            ['UAE', 'Dubai', 'MEDIA CITY', 'Area / City'],
            ['UAE', 'Abu Dhabi', 'MUSAFFAH', 'Area / City'],
            ['UAE', 'Dubai', 'NAD AL SAFA', 'Area / City'],
            ['UAE', 'Dubai', 'NAD AL SHEBA', 'Area / City'],
            ['UAE', 'Dubai', 'NIP', 'Area / City'],
            ['UAE', 'Dubai', 'PALM DUBAI', 'Area / City'],
            ['UAE', 'Dubai', 'PARCO', 'Area / City'],
            ['UAE', 'Dubai', 'PARCO / DIC', 'Industrial'],
            ['UAE', 'Dubai', 'PDC', 'Area / City'],
            ['UAE', 'Dubai', 'QUSAIS', 'Area / City'],
            ['UAE', 'Ras Al Khaimah', 'RAK', 'Area / City'],
            ['UAE', 'Dubai', 'RAS AL KHOR', 'Area / City'],
            ['UAE', 'Dubai', 'RAS AL KHOR / AL QUOZ', 'Area / City'],
            ['UAE', 'Dubai', 'RAS AL KHOR / DIC', 'Industrial'],
            ['UAE', 'Dubai', 'RASHID PORT', 'Logistics / Industrial'],
            ['UAE', 'Dubai', 'RASHIDIYA', 'Area / City'],
            ['UAE', 'Abu Dhabi', 'RUWAIS', 'Area / City'],
            ['UAE', 'Sharjah', 'SAIF ZONE', 'Logistics / Industrial'],
            ['UAE', 'Sharjah', 'SAJJA', 'Area / City'],
            ['UAE', 'Abu Dhabi', 'SHAHAMA', 'Area / City'],
            ['UAE', 'Sharjah', 'SHJ', 'Area / City'],
            ['UAE', 'Abu Dhabi', 'SILA', 'Area / City'],
            ['UAE', 'Abu Dhabi', 'SWEIHAN', 'Area / City'],
            ['UAE', 'Abu Dhabi', 'TAWEELAH', 'Area / City'],
            ['UAE', 'Dubai', 'TECHNO PARK', 'Industrial'],
            ['UAE', 'Umm Al Quwain', 'UAQ', 'Area / City'],
            ['UAE', 'Dubai', 'UMM RAMOOL', 'Area / City'],
            ['UAE', 'Dubai', 'WARSAN', 'Area / City'],
            ['UAE', 'Abu Dhabi', 'YAS ISLAND', 'Area / City'],
            ['UAE', 'Abu Dhabi', 'YAS ISLAND / KHALIFA PORT', 'Logistics / Industrial'],
        ];

        $now = now();
        $data = array_map(function ($row) use ($now) {
            return [
                'country' => $row[0],
                'city' => $row[1],
                'name' => $row[2],
                'zone_type' => $row[3],
                'is_active' => true,
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }, $rows);

        // Chunked upsert (not a plain insert) so this migration is safe to
        // re-run against an environment where an earlier partial run
        // already inserted some of these rows.
        foreach (array_chunk($data, 100) as $chunk) {
            DB::table('zones')->upsert($chunk, ['country', 'city', 'name'], ['zone_type', 'is_active', 'updated_at']);
        }
    }

    public function down(): void
    {
        // Intentionally a no-op: rolling back would delete zones that may
        // already be referenced by price_list_entries/shipment_offers via
        // FK, which would fail anyway. Drop the whole zones table instead
        // via 2026_08_27_000001's down() if a full rollback is needed.
    }
};
