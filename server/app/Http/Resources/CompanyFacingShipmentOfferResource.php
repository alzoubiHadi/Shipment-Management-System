<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Financial audit (2026-08-25): counterpart to
 * DriverFacingShipmentOfferResource — a company should see what it's being
 * charged (price_to_client), never what the driver is paid
 * (price_to_driver) or the platform's margin
 * (platform_margin_percent_snapshot). Used by
 * ShipmentOfferController::myOffers().
 */
class CompanyFacingShipmentOfferResource extends JsonResource
{
    public function toArray($request): array
    {
        return [
            'id' => $this->id,
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
            // What this company is charged — the only price figure they're
            // allowed to see. price_to_driver and
            // platform_margin_percent_snapshot are deliberately omitted.
            'price_to_client' => $this->price_to_client,
            'pricing_mode' => $this->pricing_mode,
            'status' => $this->status,
            'financial_status' => $this->financial_status,
            'cancellation_reason' => $this->cancellation_reason,
            'cancelled_at' => $this->cancelled_at,
            'accepted_at' => $this->accepted_at,
            'expires_at' => $this->expires_at,
            'created_at' => $this->created_at,
        ];
    }
}
