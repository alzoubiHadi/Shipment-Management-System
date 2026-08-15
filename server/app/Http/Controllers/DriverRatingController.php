<?php

namespace App\Http\Controllers;

use App\Models\Company;
use App\Models\Driver;
use App\Models\DriverRating;
use App\Models\Shipment;
use Illuminate\Http\Request;

/**
 * UC-23 (company rates a driver after a confirmed delivery) and UC-24
 * (Super Admin rates a driver directly, independent of any one shipment).
 * Every rating recomputes Driver::rating via Driver::recalculateRating().
 */
class DriverRatingController extends Controller
{
    public function rateByCompany(Request $request, Shipment $shipment)
    {
        $company = Company::where('user_id', $request->user()->id)->first();

        if (! $company || $shipment->company_id !== $company->id) {
            return response()->json(['message' => 'This is not your shipment'], 403);
        }

        if ($shipment->delivery_status !== 'confirmed') {
            return response()->json([
                'message' => 'You can only rate a driver after confirming delivery',
            ], 409);
        }

        if (! $shipment->driver_id) {
            return response()->json(['message' => 'This shipment has no assigned driver'], 422);
        }

        if (DriverRating::where('shipment_id', $shipment->id)->exists()) {
            return response()->json(['message' => 'You already rated this delivery'], 409);
        }

        $validated = $request->validate([
            'score' => ['required', 'integer', 'between:1,5'],
            'comment' => ['nullable', 'string', 'max:1000'],
        ]);

        $rating = DriverRating::create([
            'driver_id' => $shipment->driver_id,
            'shipment_id' => $shipment->id,
            'rated_by_user_id' => $request->user()->id,
            'source' => 'company',
            'score' => $validated['score'],
            'comment' => $validated['comment'] ?? null,
        ]);

        $driver = Driver::find($shipment->driver_id);
        $driver?->recalculateRating();

        return response()->json([
            'message' => 'Thanks — your rating has been recorded',
            'rating' => $rating,
            'driver_rating' => $driver?->fresh()->rating,
        ], 201);
    }

    /**
     * UC-24: Super Admin evaluates a driver directly — e.g. a periodic
     * review or a one-off adjustment — with no shipment attached.
     */
    public function rateBySuperAdmin(Request $request, Driver $driver)
    {
        if (! $request->user()->isSuperAdmin()) {
            return response()->json(['message' => 'Only the Super Admin can do this'], 403);
        }

        $validated = $request->validate([
            'score' => ['required', 'integer', 'between:1,5'],
            'comment' => ['nullable', 'string', 'max:1000'],
        ]);

        $rating = DriverRating::create([
            'driver_id' => $driver->id,
            'shipment_id' => null,
            'rated_by_user_id' => $request->user()->id,
            'source' => 'super_admin',
            'score' => $validated['score'],
            'comment' => $validated['comment'] ?? null,
        ]);

        $driver->recalculateRating();

        return response()->json([
            'message' => 'Rating recorded',
            'rating' => $rating,
            'driver_rating' => $driver->fresh()->rating,
        ], 201);
    }

    /**
     * Rating history for one driver — used by the driver's own profile,
     * the admin driver-detail view, and the company (read-only, to see
     * what they previously rated).
     */
    public function driverRatings(Driver $driver)
    {
        return response()->json([
            'message' => 'Ratings retrieved successfully',
            'ratings' => $driver->ratings()->with(['ratedBy', 'shipment'])->latest()->get(),
            'current_rating' => $driver->rating,
        ], 200);
    }
}
