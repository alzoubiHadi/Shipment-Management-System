<?php

namespace App\Http\Controllers;

use App\Models\Company;
use App\Models\Driver;
use App\Models\Shipment;
use Illuminate\Http\Request;

class ShipmentController extends Controller
{
    //
    public function assignDriver(Request $request)
    {
        $shipment = Shipment::findOrFail($request->shipmentId);
        $driver = Driver::findOrFail($request->driverId);

        $shipment->update([
            'driver_id' => $driver->id,
            'status' => 1, // assigned
        ]);

        return response()->json([
            'message' => 'Driver assigned to shipment successfully',
            'shipment' => $shipment,
        ], 200);
    }
    public function refuse(Request $request)
    {
        $shipment = Shipment::findOrFail($request->shipment_id);
        $shipment->update([
            'status' => 0, // refused
        ]);

        return response()->json([
            'message' => 'Shipment refused successfully',
            'shipment' => $shipment,
        ], 200);
    }
    public function index()
    {
        // List all shipments
        $shipments = Shipment::all();
        return response()->json([
            'message' => 'shipments Displayed successfully',
            'shipments' => $shipments,
        ], 200);
    }
    public function delete(Shipment $shipment)
    {        // Soft delete a shipment
        $shipment->delete();
        return response()->json([
            'message' => 'Shipment deleted successfully',
        ], 200);
    }
    public function restore($id)
    {
        // Restore a soft-deleted shipment
        $shipment = Shipment::withTrashed()->findOrFail($id);
        $shipment->restore();
        return response()->json([
            'message' => 'Shipment restored successfully',
            'shipment' => $shipment,
        ], 200);
    }
    public function create(Request $request)
    {
        $user_id = auth()->user()->id;

        $company = Company::where('user_id', $user_id)->first();

        if (!$company) {
            return response()->json([
                'message' => 'Company not found'
            ], 404);
        }

        $trackingNumber = $request->tracking_number ?? uniqid('TRK');

        $exists = Shipment::where('tracking_number', $trackingNumber)->exists();

        if ($exists) {
            return response()->json([
                'message' => 'Tracking number already exists',
                'tracking_number' => $trackingNumber,
            ], 205);
        }

        $shipment = Shipment::create([
            'company_id' => $company->id,
            'origin' => $request->origin,
            'destination' => $request->destination,
            'weight' => $request->weight,
            'description' => $request->description,
            'tracking_number' => $trackingNumber,
            'status' => 0,
        ]);

        return response()->json([
            'message' => 'Shipment created successfully',
            'shipment' => $shipment,
        ], 201);
    }
    public function update(Request $request, Shipment $shipment)
    {


        $shipment->update([
            'driver_id' => $request->driver_id ?? $shipment->driver_id,
            'status' => $request->status ?? $shipment->status,
            'pickup_time' => $request->pickup_time ?? $shipment->pickup_time,
            'delivered_at' => $request->delivered_at ?? $shipment->delivered_at,
        ]);

        return response()->json([
            'message' => 'Shipment updated successfully',
            'shipment' => $shipment,
        ], 200);
    }
    public function trackmyshipment($tracking_number)
    {
        $shipment = Shipment::where('tracking_number', $tracking_number)->first();

        if (!$shipment) {
            return response()->json([
                'message' => 'Shipment not found',
            ], 404);
        }

        return response()->json([
            'message' => 'Shipment tracked successfully',
            'shipment' => $shipment,
        ], 200);
    }
    public function drivergetShipments($driver_id)
    {
        $driver_sid = Driver::where('user_id', $driver_id)->first()->id;
        $shipments = Shipment::where('driver_id', $driver_sid)->get();

        return response()->json([
            'message' => 'Shipments retrieved successfully',
            'shipments' => $shipments,
        ], 200);
    }
    public function companygetShipments($company_id)
    {
        $company_sid = Company::where('user_id', $company_id)->first()->id;
        $shipments = Shipment::where('company_id', $company_sid)->get();
        return response()->json([
            'message' => 'Shipments retrieved successfully',
            'shipments' => $shipments,
        ], 200);
    }
    /**
     * Driver app: move the shipment forward one step in the 7-stage
     * tracking timeline (1 heading to pickup ... 6 unloaded). Stage 7
     * (delivered) is handled by deliver() below since it requires a
     * proof-of-delivery signature.
     */
    public function advanceStage(Request $request, Shipment $shipment)
    {
        $driver = Driver::where('user_id', auth()->user()->id)->first();

        if (! $driver || $shipment->driver_id != $driver->id) {
            return response()->json([
                'message' => 'You are not assigned to this shipment',
            ], 403);
        }

        $nextStage = $shipment->current_stage + 1;

        if ($nextStage > 6) {
            return response()->json([
                'message' => 'Use the delivery endpoint to complete the final stage',
            ], 422);
        }

        $shipment->update([
            'current_stage' => $nextStage,
            Shipment::STAGE_COLUMNS[$nextStage] => now(),
        ]);

        return response()->json([
            'message' => 'Shipment stage updated successfully',
            'shipment' => $shipment,
        ], 200);
    }

    /**
     * Driver app: final stage. Captures the proof-of-delivery signature and
     * recipient name, marks the shipment delivered, and frees the driver
     * back up for new jobs.
     */
    public function deliver(Request $request, Shipment $shipment)
    {
        $driver = Driver::where('user_id', auth()->user()->id)->first();

        if (! $driver || $shipment->driver_id != $driver->id) {
            return response()->json([
                'message' => 'You are not assigned to this shipment',
            ], 403);
        }

        if ($shipment->current_stage < 6) {
            return response()->json([
                'message' => 'Complete unloading before capturing the delivery signature',
            ], 422);
        }

        $validated = $request->validate([
            'pod_signature' => ['required', 'string'],
            'pod_recipient_name' => ['required', 'string'],
        ]);

        $shipment->update([
            'current_stage' => 7,
            'status' => 3, // delivered
            'delivered_at' => now(),
            'pod_signature' => $validated['pod_signature'],
            'pod_recipient_name' => $validated['pod_recipient_name'],
        ]);

        $driver->update(['status' => 'available']);

        return response()->json([
            'message' => 'Shipment delivered successfully',
            'shipment' => $shipment,
        ], 200);
    }

    public function updateshipmentstatus(Request $request)
    {
        $shipment = Shipment::findOrFail($request->shipment_id);
        $newStatus = $request->status ?? $shipment->status;

        // Cancelling a shipment requires a reason (missing documents,
        // client declined, etc.) so the admin/company can see why later.
        if ((int) $newStatus === 4 && empty($request->cancellation_reason)) {
            return response()->json([
                'message' => 'A cancellation reason is required to cancel a shipment',
            ], 422);
        }

        $shipment->update([
            'status' => $newStatus,
            'cancellation_reason' => (int) $newStatus === 4
                ? $request->cancellation_reason
                : $shipment->cancellation_reason,
        ]);

        // Free the driver back up once the job is finished (delivered=3, cancelled=4)
        if (in_array((int) $shipment->status, [3, 4]) && $shipment->driver_id) {
            $driver = Driver::find($shipment->driver_id);
            $driver?->update(['status' => 'available']);
        }

        if ((int) $shipment->status === 3) {
            $shipment->update(['delivered_at' => now()]);
        }

        return response()->json([
            'message' => 'Shipment status updated successfully',
            'shipment' => $shipment,
        ], 200);
    }
}
