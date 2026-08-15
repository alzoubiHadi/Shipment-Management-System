<?php

namespace App\Http\Controllers;

use App\Models\Driver;
use App\Models\Shipment;
use App\Models\ShipmentOffer;
use App\Models\Truck;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ShipmentOfferController extends Controller
{
    /**
     * Admin: create a new shipment offer. This represents an order that was
     * received outside the app (phone / email / WhatsApp) from a client
     * company, priced for whichever driver ends up accepting it.
     */
    public function create(Request $request)
    {
        try {
            $validated = $request->validate([
                'company_id' => ['required', 'exists:companies,id'],
                'origin' => ['required', 'string'],
                'destination' => ['required', 'string'],
                'weight' => ['nullable', 'numeric'],
                'description' => ['nullable', 'string'],
                'needs_permit' => ['boolean'],
                'is_hazardous' => ['boolean'],
                'is_fragile' => ['boolean'],
                // 'external' replaces the old requires_cross_border=true.
                'order_type' => ['nullable', 'in:internal,external'],
                'required_truck_type' => ['nullable', 'string', 'in:' . implode(',', Truck::TRUCK_TYPES)],
                'price_to_driver' => ['nullable', 'numeric'],
                'price_to_client' => ['nullable', 'numeric'],
            ]);
        } catch (ValidationException $e) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $e->errors(),
            ], 422);
        }

        $validated['order_type'] = $validated['order_type'] ?? 'internal';
        $validated['status'] = 'pending';

        $offer = ShipmentOffer::create($validated);

        return response()->json([
            'message' => 'Shipment offer created successfully',
            'offer' => $offer,
            'eligible_drivers_count' => $this->eligibleDriversQuery($offer)->count(),
        ], 201);
    }

    /**
     * Admin: list every offer, with how many eligible drivers currently
     * match it (helps show why an offer might be stuck unmatched).
     */
    public function index()
    {
        $offers = ShipmentOffer::with(['company', 'acceptedByDriver', 'acceptedTruck'])
            ->orderByDesc('created_at')
            ->get()
            ->map(function (ShipmentOffer $offer) {
                $offer->eligible_drivers_count = $offer->status === 'pending'
                    ? $this->eligibleDriversQuery($offer)->count()
                    : 0;

                return $offer;
            });

        return response()->json([
            'message' => 'Shipment offers retrieved successfully',
            'offers' => $offers,
        ], 200);
    }

    /**
     * Admin: preview which drivers are eligible & available for a given
     * offer right now, based on status, document validity, and (for
     * cross-border offers) the 3-month residency rule.
     */
    public function eligibleDrivers(ShipmentOffer $offer)
    {
        $drivers = $this->eligibleDriversQuery($offer)->get();

        return response()->json([
            'message' => 'Eligible drivers retrieved successfully',
            'drivers' => $drivers,
        ], 200);
    }

    /**
     * Driver app: list pending offers this specific driver currently
     * qualifies for, so the app can show "available jobs" to that driver.
     */
    public function availableForDriver($driver_id)
    {
        $driver = Driver::where('user_id', $driver_id)->first();

        if (! $driver) {
            return response()->json(['message' => 'Driver not found'], 404);
        }

        if (! $driver->isEligibleForNewJob()) {
            return response()->json([
                'message' => 'Driver is not currently eligible for new jobs',
                'offers' => [],
            ], 200);
        }

        $offers = ShipmentOffer::where('status', 'pending')
            ->where(function ($q) use ($driver) {
                $q->where('order_type', 'internal');

                if ($driver->meetsCrossBorderResidencyRule()) {
                    $q->orWhere('order_type', 'external');
                }
            })
            ->orderByDesc('created_at')
            ->get();

        return response()->json([
            'message' => 'Available offers retrieved successfully',
            'offers' => $offers,
        ], 200);
    }

    /**
     * Driver app: accept an offer with a chosen truck. Turns the offer into
     * a real Shipment, locks the offer so nobody else can take it, and marks
     * the driver as busy.
     */
    public function accept(Request $request)
    {
        $validated = $request->validate([
            'offer_id' => ['required', 'exists:shipment_offers,id'],
            // the app only knows the logged-in user's id, not the internal
            // drivers.id, so we resolve the driver from that (same pattern
            // as the trucks endpoints)
            'driver_user_id' => ['required', 'exists:users,id'],
            'truck_id' => ['required', 'exists:trucks,id'],
        ]);

        return DB::transaction(function () use ($validated) {
            $offer = ShipmentOffer::lockForUpdate()->findOrFail($validated['offer_id']);

            if ($offer->status !== 'pending') {
                return response()->json([
                    'message' => 'This offer is no longer available',
                ], 409);
            }

            $driver = Driver::where('user_id', $validated['driver_user_id'])->first();

            if (! $driver) {
                return response()->json(['message' => 'Driver not found'], 404);
            }

            $truck = Truck::findOrFail($validated['truck_id']);

            if (! $driver->isEligibleForNewJob()) {
                return response()->json([
                    'message' => 'Driver is not eligible for this job (unavailable or expired documents)',
                ], 422);
            }

            if ($offer->order_type === 'external' && ! $driver->meetsCrossBorderResidencyRule()) {
                return response()->json([
                    'message' => 'Driver residency does not meet the 3-month cross-border requirement',
                ], 422);
            }

            if (! $truck->isRoadworthy()) {
                return response()->json([
                    'message' => 'Truck is not roadworthy (inactive, expired insurance or license)',
                ], 422);
            }

            if ($offer->required_truck_type && $truck->truck_type !== $offer->required_truck_type) {
                return response()->json([
                    'message' => 'Truck type does not match what this offer requires',
                ], 422);
            }

            // Refrigeration is implied by required_truck_type = "Reefer Trailer"
            // (there is no separate cargo_type flag for it anymore) — this is
            // a defensive double-check in case a truck was mislabeled.
            if ($offer->required_truck_type === 'Reefer Trailer' && ! $truck->has_refrigeration) {
                return response()->json([
                    'message' => 'This cargo requires a refrigerated truck',
                ], 422);
            }

            $trackingNumber = 'TRK' . strtoupper(uniqid());

            $shipment = Shipment::create([
                'shipment_offer_id' => $offer->id,
                'company_id' => $offer->company_id,
                'driver_id' => $driver->id,
                'truck_id' => $truck->id,
                'tracking_number' => $trackingNumber,
                'origin' => $offer->origin,
                'destination' => $offer->destination,
                'weight' => $offer->weight,
                'description' => $offer->description,
                'needs_permit' => $offer->needs_permit,
                'is_hazardous' => $offer->is_hazardous,
                'is_fragile' => $offer->is_fragile,
                'order_type' => $offer->order_type,
                'price_to_driver' => $offer->price_to_driver,
                'price_to_client' => $offer->price_to_client,
                'status' => 1, // assigned
            ]);

            $offer->update([
                'status' => 'accepted',
                'accepted_by_driver_id' => $driver->id,
                'accepted_truck_id' => $truck->id,
                'accepted_at' => now(),
            ]);

            $driver->update(['status' => 'busy']);

            return response()->json([
                'message' => 'Offer accepted, shipment created successfully',
                'shipment' => $shipment,
            ], 201);
        });
    }

    public function cancel(Request $request, ShipmentOffer $offer)
    {
        if ($offer->status !== 'pending') {
            return response()->json([
                'message' => 'Only pending offers can be cancelled',
            ], 409);
        }

        $validated = $request->validate([
            'cancellation_reason' => ['required', 'string'],
        ]);

        $offer->update([
            'status' => 'cancelled',
            'cancellation_reason' => $validated['cancellation_reason'],
        ]);

        return response()->json([
            'message' => 'Offer cancelled successfully',
            'offer' => $offer,
        ], 200);
    }

    /**
     * Shared eligibility query used by both the admin preview and the
     * offer-creation response.
     */
    private function eligibleDriversQuery(ShipmentOffer $offer)
    {
        return Driver::where('status', 'available')
            ->where(function ($q) {
                $q->whereNull('license_expiry')->orWhere('license_expiry', '>=', now()->toDateString());
            })
            ->where(function ($q) {
                $q->whereNull('passport_expiry')->orWhere('passport_expiry', '>=', now()->toDateString());
            })
            ->where(function ($q) {
                $q->whereNull('residency_expiry')->orWhere('residency_expiry', '>=', now()->toDateString());
            })
            ->where('compliance_status', 'active')
            ->when($offer->order_type === 'external', function ($q) {
                $q->where('residency_expiry', '>=', now()->addMonths(3)->toDateString());
            });
    }
}
