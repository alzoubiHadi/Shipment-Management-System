<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Whitelisted subset of Driver fields safe to show to a company. Used
 * wherever an API response would otherwise embed the full Driver model
 * inside a shipment a company can see (e.g. companygetShipments,
 * trackmyshipment). This is the one enforcement point for the privacy
 * rule: health_conditions, admin_note, balance, driver_license, and the
 * raw document history must NEVER reach a company, no matter which
 * endpoint assembles the response.
 *
 * A company only ever sees this for a driver actually assigned to one of
 * ITS shipments — there is no company-facing "list all drivers" endpoint,
 * so visibility is naturally scoped to an active/past relationship.
 */
class CompanyFacingDriverResource extends JsonResource
{
    public function toArray($request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'phone' => $this->phone,
            'nationality' => $this->nationality,
            'rating' => $this->rating,
            'last_lat' => $this->last_lat,
            'last_lng' => $this->last_lng,
            'last_location_at' => $this->last_location_at,
        ];
    }
}
