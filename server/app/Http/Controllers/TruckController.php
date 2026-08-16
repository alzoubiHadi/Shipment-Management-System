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

    public function truckTypes()
    {
        return response()->json([
            'message' => 'Truck types retrieved successfully',
            'truck_types' => Truck::TRUCK_TYPES,
        ], 200);
    }

    public function create(Request $request)
    {
        try {
            $validated = $request->validate([
                'truck_number' => ['required', 'string', 'unique:trucks,truck_number'],
                'truck_type' => ['required', 'string', 'in:' . implode(',', Truck::TRUCK_TYPES)],
                'max_load' => ['nullable', 'numeric'],
                'length' => ['nullable', 'numeric'],
                'width' => ['nullable', 'numeric'],
                'height' => ['nullable', 'numeric'],
                'has_refrigeration' => ['boolean'],
                'permit_type' => ['nullable', 'string'],
                'permit_expiry' => ['nullable', 'date'],
                'insurance_expiry' => ['nullable', 'date'],
                'license_expiry' => ['nullable', 'date'],
                // Required per spec. The only "add truck" screen in the
                // Flutter app is AddTruckPage.dart, which always sends this
                // (it calls addMyTruck() below, not this admin endpoint —
                // this create() method has no current Flutter caller, but
                // is kept consistent with addMyTruck's validation in case
                // an admin-side truck management screen is added later).
                'license_file' => ['required', 'file', 'max:10240'],
                'default_driver_id' => ['nullable', 'exists:drivers,id'],
            ]);
        } catch (ValidationException $e) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $e->errors(),
            ], 422);
        }

        if ($request->hasFile('license_file')) {
            $validated['license_file_path'] = $request->file('license_file')->store('truck_licenses', 'public');
        }
        unset($validated['license_file']);

        $truck = Truck::create($validated);

        return response()->json([
            'message' => 'Truck created successfully',
            'truck' => $truck,
        ], 201);
    }

    public function update(Request $request, Truck $truck)
    {
        $validated = $request->only([
            'truck_number', 'truck_type', 'max_load', 'length', 'width', 'height',
            'has_refrigeration', 'permit_type', 'permit_expiry', 'insurance_expiry',
            'license_expiry', 'default_driver_id', 'is_active',
        ]);

        if (isset($validated['truck_type']) && ! in_array($validated['truck_type'], Truck::TRUCK_TYPES, true)) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => ['truck_type' => ['Invalid truck type']],
            ], 422);
        }

        if ($request->hasFile('license_file')) {
            $validated['license_file_path'] = $request->file('license_file')->store('truck_licenses', 'public');
        }

        $truck->update($validated);

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
                'truck_type' => ['required', 'string', 'in:' . implode(',', Truck::TRUCK_TYPES)],
                'has_refrigeration' => ['boolean'],
                'max_load' => ['nullable', 'numeric'],
                // Required here (unlike the admin create() endpoint below):
                // the Flutter AddTruckPage now always sends one.
                'license_file' => ['required', 'file', 'max:10240'],
            ]);
        } catch (ValidationException $e) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $e->errors(),
            ], 422);
        }

        $validated['default_driver_id'] = $driver->id;

        if ($request->hasFile('license_file')) {
            $validated['license_file_path'] = $request->file('license_file')->store('truck_licenses', 'public');
        }
        unset($validated['license_file']);

        $truck = Truck::create($validated);

        return response()->json([
            'message' => 'Truck added successfully',
            'truck' => $truck,
        ], 201);
    }
}
