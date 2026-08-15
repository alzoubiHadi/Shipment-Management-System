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

    public static function all(): array
    {
        return array_keys(self::CITY_TO_COUNTRY);
    }

    public static function countryFor(string $destination): ?string
    {
        return self::CITY_TO_COUNTRY[$destination] ?? null;
    }
}
