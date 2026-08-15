<?php

namespace App\Services;

use App\Models\PlatformSetting;
use App\Models\PriceListEntry;

/**
 * UC-12: automatic price calculation from the central price_list_entries
 * table (destination x truck_type -> base_price). UC-13's manual-pricing
 * fallback is handled by the caller (ShipmentOfferController) when this
 * returns null — there is simply no matching row.
 */
class PricingService
{
    /**
     * @return array{base_price: float, margin_percent: float, price_to_driver: float}|null
     */
    public function computeAutoPrice(string $destination, string $truckType): ?array
    {
        $entry = PriceListEntry::where('destination', $destination)
            ->where('truck_type', $truckType)
            ->first();

        if (! $entry) {
            return null;
        }

        $marginPercent = (float) PlatformSetting::get('profit_margin_percent', '20');
        $basePrice = (float) $entry->base_price;

        // Driver-visible price = base price minus the platform's margin.
        $priceToDriver = round($basePrice - ($basePrice * $marginPercent / 100), 2);

        return [
            'base_price' => $basePrice,
            'margin_percent' => $marginPercent,
            'price_to_driver' => $priceToDriver,
        ];
    }
}
