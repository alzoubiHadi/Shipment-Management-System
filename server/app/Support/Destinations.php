<?php

namespace App\Support;

/**
 * The 15 external (cross-border) destinations from the client's price
 * matrix ("المتطلبات الجديدة.docx"), each mapped to the country used to
 * filter eligible drivers via DriverDestination::DESTINATIONS. This is the
 * fixed dropdown a company must choose from when order_type == 'external'
 * — required so ShipmentOffer::destination lines up EXACTLY with
 * PriceListEntry::destination for automatic pricing (UC-12) to find a row.
 *
 * Internal (UAE) shipments are NOT covered by this list — the client's
 * price matrix only priced external destinations, so an internal offer's
 * `destination` stays free text (any UAE city) and always falls back to
 * manual pricing (UC-13) since there's no internal rate table yet.
 */
class Destinations
{
    const CITY_TO_COUNTRY = [
        'Dammam/Khobar/Hasa' => 'saudi_arabia',
        'Riyadh' => 'saudi_arabia',
        'Jubail' => 'saudi_arabia',
        'Qaseem' => 'saudi_arabia',
        'Jeddah/Madina/Mecca/Taif' => 'saudi_arabia',
        'Kuwait' => 'kuwait',
        'Bahrain' => 'bahrain',
        'Sohar-Oman' => 'oman',
        'Muscat-Oman' => 'oman',
        'Amman-Jordan' => 'jordan',
        'Beirut-Lebanon' => 'lebanon',
        'Damascus-Syria' => 'syria',
        'Cairo-Egypt' => 'egypt',
        'Iraqi-Border' => 'iraq',
        'Sanaa-Yemen' => 'yemen',
    ];

    /**
     * Admin Shipments redesign (2026-08-24): approximate representative
     * coordinates (city/region center) for each external destination group,
     * used purely to compute a straight-line distance estimate for the Trip
     * Report / Live Tracking screens (see App\Support\Geo::haversineKm()) —
     * NOT for routing or eligibility, which stay keyed off the country name
     * via CITY_TO_COUNTRY. Internal (UAE) destinations stay free text with
     * no fixed coordinates, so distance is simply not shown for those.
     */
    const CITY_COORDS = [
        'Dammam/Khobar/Hasa' => [26.4207, 50.0888],
        'Riyadh' => [24.7136, 46.6753],
        'Jubail' => [27.0046, 49.6600],
        'Qaseem' => [26.3260, 43.9750],
        'Jeddah/Madina/Mecca/Taif' => [21.4858, 39.1925],
        'Kuwait' => [29.3759, 47.9774],
        'Bahrain' => [26.2285, 50.5860],
        'Sohar-Oman' => [24.3474, 56.7079],
        'Muscat-Oman' => [23.5880, 58.3829],
        'Amman-Jordan' => [31.9454, 35.9284],
        'Beirut-Lebanon' => [33.8938, 35.5018],
        'Damascus-Syria' => [33.5138, 36.2765],
        'Cairo-Egypt' => [30.0444, 31.2357],
        'Iraqi-Border' => [30.1300, 47.6600],
        'Sanaa-Yemen' => [15.3694, 44.1910],
    ];

    public static function all(): array
    {
        return array_keys(self::CITY_TO_COUNTRY);
    }

    public static function countryFor(string $destination): ?string
    {
        return self::CITY_TO_COUNTRY[$destination] ?? null;
    }

    /** @return array{0: float, 1: float}|null [lat, lng] or null for an internal/unrecognized destination. */
    public static function coordsFor(string $destination): ?array
    {
        return self::CITY_COORDS[$destination] ?? null;
    }
}
