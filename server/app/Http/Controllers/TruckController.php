<?php

namespace App\Http\Controllers;

use App\Models\Driver;
use App\Models\Truck;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class TruckController extends Controller
{
    public function index()
    {
        $trucks = Truck::with('defaultDriver')->get();

        return response()->json([
            'message' => 'Trucks retrieved successfully',
            'trucks' => $trucks,
        ], 200);
    }

    public function index_trashed()
    {
        $trucks = Truck::onlyTrashed()->get();

        return response()->json([
            'message' => 'Trashed trucks retrieved successfully',
            'trucks' => $trucks,
        ], 200);
    }

    public function create(Request $request)
    {
        try {
            $validated = $request->validate([
                'truck_number' => ['required', 'string', 'unique:trucks,truck_number'],
                'truck_type' => ['required', 'string'],
                'max_load' => ['nullable', 'numeric'],
                'length' => ['nullable', 'numeric'],
                'width' => ['nullable', 'numeric'],
                'height' => ['nullable', 'numeric'],
                'has_refrigeration' => ['boolean'],
                'permit_type' => ['nullable', 'string'],
                'permit_expiry' => ['nullable', 'date'],
                'insurance_expiry' => ['nullable', 'date'],
                'license_expiry' => ['nullable', 'date'],
                'default_driver_id' => ['nullable', 'exists:drivers,id'],
            ]);
        } catch (ValidationException $e) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $e->errors(),
            ], 422);
        }

        $truck = Truck::create($validated);

        return response()->json([
            'message' => 'Truck created successfully',
            'truck' => $truck,
        ], 201);
    }

    public function update(Request $request, Truck $truck)
    {
        $truck->update($request->only([
            'truck_number', 'truck_type', 'max_load', 'length', 'width', 'height',
            'has_refrigeration', 'permit_type', 'permit_expiry', 'insurance_expiry',
            'license_expiry', 'default_driver_id', 'is_active',
        ]));

        return response()->json([
            'message' => 'Truck updated successfully',
            'truck' => $truck,
        ], 200);
    }

    public function destroy(Truck $truck)
    {
        $truck->delete();

        return response()->json([
            'message' => 'Truck deleted successfully',
        ], 200);
    }

    public function restore($id)
    {
        $truck = Truck::withTrashed()->findOrFail($id);
        $truck->restore();

        return response()->json([
            'message' => 'Truck restored successfully',
        ], 200);
    }

    /**
     * A driver only knows their own user_id (that's what's stored in the
     * app after login) — not the internal drivers.id or any truck id. So
     * these two endpoints resolve everything from the user_id, the same
     * pattern already used for /driver/{driver_id}/shipments.
     */
    public function myTrucks($driver_user_id)
    {
        $driver = Driver::where('user_id', $driver_user_id)->first();

        if (! $driver) {
            return response()->json(['message' => 'Driver not found'], 404);
        }

        $trucks = Truck::where('default_driver_id', $driver->id)->get();

        return response()->json([
            'message' => 'Trucks retrieved successfully',
            'trucks' => $trucks,
        ], 200);
    }

    public function addMyTruck(Request $request, $driver_user_id)
    {
        $driver = Driver::where('user_id', $driver_user_id)->first();

        if (! $driver) {
            return response()->json(['message' => 'Driver not found'], 404);
        }

        try {
            $validated = $request->validate([
                'truck_number' => ['required', 'string', 'unique:trucks,truck_number'],
                'truck_type' => ['required', 'string'],
                'has_refrigeration' => ['boolean'],
                'max_load' => ['nullable', 'numeric'],
            ]);
        } catch (ValidationException $e) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $e->errors(),
            ], 422);
        }

        $validated['default_driver_id'] = $driver->id;

        $truck = Truck::create($validated);

        return response()->json([
            'message' => 'Truck added successfully',
            'truck' => $truck,
        ], 201);
    }
}
