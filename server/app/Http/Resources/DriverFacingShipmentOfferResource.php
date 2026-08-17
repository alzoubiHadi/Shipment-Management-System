<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Financial audit (2026-08-25): the driver-facing offer endpoints
 * (ShipmentOfferController::availableForDriver, and the offer embedded in
 * accept()'s response) used to serialize the raw ShipmentOffer model,
 * which includes price_to_client (what the company pays) and
 * platform_margin_percent_snapshot (FMS's cut). We commercially agreed a
 * driver should only ever see their own price_to_driver — never what the
 * client paid or what the platform's margin is. This is the one
 * enforcement point for that rule.
 */
class DriverFacingShipmentOfferResource extends JsonResource
{
    public function toArray($request): array
    {
        return [
            'id' => $this->id,
            // Not sensitive — DriverOfferDetailsPage shows "Posted by X".
            'company' => $this->company ? ['name' => $this->company->name] : null,
            'tracking_number' => $this->tracking_number,
            'origin' => $this->origin,
            'origin_lat' => $this->origin_lat,
            'origin_lng' => $this->origin_lng,
            'destination' => $this->destination,
            'destination_lat' => $this->destination_lat,
            'destination_lng' => $this->destination_lng,
            'weight' => $this->weight,
            'description' => $this->description,
            'needs_permit' => $this->needs_permit,
            'is_hazardous' => $this->is_hazardous,
            'is_fragile' => $this->is_fragile,
            'order_type' => $this->order_type,
            'required_truck_type' => $this->required_truck_type,
            // The driver's own pay — the only price figure they're allowed
            // to see. price_to_client and platform_margin_percent_snapshot
            // are deliberately omitted below.
            'price_to_driver' => $this->price_to_driver,
            'status' => $this->status,
            'expires_at' => $this->expires_at,
            'created_at' => $this->created_at,
        ];
    }
}
