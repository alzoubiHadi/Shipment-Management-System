<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Baseline fallback zones (2026-08-28) — every country in
     * DriverDestination::DESTINATIONS gets at least its top-level
     * governorates/provinces/emirates seeded as its own zone (city = name =
     * the governorate), so the Company Create-Shipment Country -> City ->
     * Zone cascade (AddShipmentOfferPage) can never dead-end on a country
     * with no pickable city.
     *
     * This closed two real gaps found in 2026_08_27_000002's historical-data
     * import:
     *   - KUWAIT and BAHRAIN each had exactly one zone row with city=null,
     *     so `_citiesFor(country)` (which filters out null/empty cities)
     *     returned an empty list — the city step had nothing to pick and the
     *     admin could never finish creating a Kuwait/Bahrain shipment.
     *   - LEBANON, EGYPT, and YEMEN had zero zone rows at all, so they never
     *     even appeared as a pickable country.
     *
     * Added additively for every one of the 11 countries (not just the
     * broken ones) so the fallback is consistent everywhere, not just a
     * patch for the two that happened to break first. zone_type =
     * 'Governorate' distinguishes these from the real historical
     * city/area-level zones; nothing in the app branches on zone_type
     * (see Zone.php's docblock), so this is purely additive/informational.
     */
    public function up(): void
    {
        $governoratesByCountry = [
            'UAE' => [
                'Abu Dhabi', 'Dubai', 'Sharjah', 'Ajman',
                'Umm Al Quwain', 'Ras Al Khaimah', 'Fujairah',
            ],
            'KSA' => [
                'Riyadh', 'Makkah', 'Madinah', 'Qassim', 'Eastern Province',
                'Asir', 'Tabuk', 'Hail', 'Northern Borders', 'Jazan',
                'Najran', 'Al Bahah', 'Al Jouf',
            ],
            'OMAN' => [
                'Muscat', 'Dhofar', 'Musandam', 'Al Buraimi', 'Ad Dakhiliyah',
                'Al Batinah North', 'Al Batinah South', 'Ash Sharqiyah North',
                'Ash Sharqiyah South', 'Ad Dhahirah', 'Al Wusta',
            ],
            'KUWAIT' => [
                'Al Asimah', 'Hawalli', 'Farwaniya',
                'Mubarak Al-Kabeer', 'Ahmadi', 'Jahra',
            ],
            'BAHRAIN' => ['Capital', 'Muharraq', 'Northern', 'Southern'],
            'JORDAN' => [
                'Amman', 'Irbid', 'Zarqa', 'Balqa', 'Madaba', 'Karak',
                'Tafilah', "Ma'an", 'Aqaba', 'Jerash', 'Ajloun', 'Mafraq',
            ],
            'SYRIA' => [
                'Damascus', 'Rif Dimashq', 'Aleppo', 'Homs', 'Hama',
                'Latakia', 'Idlib', "Daraa", 'As-Suwayda', 'Quneitra',
                'Deir ez-Zor', 'Raqqa', 'Hasakah', 'Tartus',
            ],
            'IRAQ' => [
                'Baghdad', 'Basra', 'Nineveh', 'Erbil', 'Sulaymaniyah',
                'Duhok', 'Kirkuk', 'Anbar', 'Babil', 'Karbala', 'Najaf',
                'Wasit', 'Diyala', 'Saladin', 'Qadisiyyah', 'Muthanna',
                'Dhi Qar', 'Maysan',
            ],
            'LEBANON' => [
                'Beirut', 'Mount Lebanon', 'North Lebanon', 'Akkar',
                'Beqaa', 'Baalbek-Hermel', 'South Lebanon', 'Nabatieh',
            ],
            'EGYPT' => [
                'Cairo', 'Alexandria', 'Giza', 'Qalyubia', 'Port Said',
                'Suez', 'Dakahlia', 'Sharqia', 'Gharbia', 'Monufia',
                'Beheira', 'Kafr El Sheikh', 'Damietta', 'Ismailia',
                'Faiyum', 'Beni Suef', 'Minya', 'Assiut', 'Sohag', 'Qena',
                'Luxor', 'Aswan', 'Red Sea', 'New Valley', 'Matrouh',
                'North Sinai', 'South Sinai',
            ],
            'YEMEN' => [
                "Sana'a", "Sana'a City", 'Aden', 'Taiz', 'Hodeidah', 'Ibb',
                'Dhamar', 'Hadhramaut', 'Al Bayda', 'Al Jawf', 'Al Mahwit',
                'Amran', 'Dhale', 'Hajjah', 'Lahij', 'Mahrah', 'Marib',
                'Raymah', 'Saada', 'Shabwah', 'Abyan', 'Socotra',
            ],
        ];

        $now = now();
        $rows = [];
        foreach ($governoratesByCountry as $country => $governorates) {
            foreach ($governorates as $governorate) {
                $rows[] = [
                    'country' => $country,
                    'city' => $governorate,
                    'name' => $governorate,
                    'zone_type' => 'Governorate',
                    'is_active' => true,
                    'created_at' => $now,
                    'updated_at' => $now,
                ];
            }
        }

        // Same chunked-upsert pattern as 2026_08_27_000002 — safe to re-run,
        // and additive (unique on country+city+name) so it never touches the
        // real historical zones already seeded for these same countries.
        foreach (array_chunk($rows, 100) as $chunk) {
            DB::table('zones')->upsert($chunk, ['country', 'city', 'name'], ['zone_type', 'is_active', 'updated_at']);
        }
    }

    public function down(): void
    {
        // Intentionally a no-op — same rationale as
        // 2026_08_27_000002_import_zones_from_pricing_data.php's down():
        // these rows may already be referenced by price_list_entries/
        // shipment_offers by the time a rollback is attempted.
    }
};
