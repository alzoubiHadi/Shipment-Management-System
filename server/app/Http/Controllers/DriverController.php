<?php

namespace App\Http\Controllers;

use App\Models\Driver;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class DriverController extends Controller
{
    public function index()
    {
        // Drivers don't have their own email column — it lives on the
        // linked users row — so attach it here for the edit-driver form.
        $drivers = Driver::with('user')->get()->map(function (Driver $driver) {
            $driver->email = $driver->user?->email;
            return $driver;
        });

        return response()->json([
            'message' => 'Drivers retrieved successfully',
            'drivers' => $drivers,

        ], 200);
    }
    public function index_trashed()
    {

        $drivers_trashed = Driver::onlyTrashed()->get();
        return response()->json([
            'message' => 'Drivers Trashed retrieved successfully',
            'drivers' => $drivers_trashed,

        ], 200);
    }
    public function create(Request $request)
    {

        try {
            $validated = $request->validate([
                'email' => ['required', 'email', 'max:255', 'unique:users,email'],
                'license_expiry' => 'required|date',
            ]);
            $user = User::create([
                'name' => $request->name,
                'email' => $request->email,
                'password' => bcrypt($request->password), // Default password, should be changed by the user
                'type' => 'driver'
            ]);
            $driver = Driver::create([
                'name' => $request->name,
                'phone' => $request->phone,
                'truck_number' => $request->truck_number,
                'truck_type' => $request->truck_type,
                'nationality' => $request->nationality,
                'age' => $request->age,
                'driver_license' => $request->driver_license,
                'license_expiry' => $request->license_expiry,
                'user_id' => $user->id,
                'status' => $request->status ?? 'available',
                // A driver added directly by the admin is already vetted at
                // creation time (unlike self-registration), so it's
                // approved by default.
                'approval_status' => $request->approval_status ?? 'approved',
                'residency_expiry' => $request->residency_expiry,
                'passport_expiry' => $request->passport_expiry,
                'blood_type' => $request->blood_type,
            ]);

            return response()->json([
                'message' => 'Driver created successfully',
                'driver' => $driver,
            ], 201);
        } catch (ValidationException $e) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $e->errors(),
            ], 422);
        }
    }
    public function destroy(Driver $driver)
    {
        $driver->delete();
        $driver->user()->delete(); // Also delete the associated user
        return response()->json([
            'message' => 'Driver deleted successfully',
        ], 200);
    }
public function restore( $id)
{
    $driver=Driver::withTrashed()->findOrFail($id);
    $driver->restore();
    $driver->user()->restore();

    return response()->json([
        'message' => 'Driver restored successfully',
    ]);
}




    public function update(Request $request, Driver $driver)
    {
        // Exclude the driver's own linked user row from the uniqueness
        // check, otherwise saving the driver's unchanged email back fails
        // validation because it's already "taken" — by themselves.
        $emailUniqueRule = $driver->user_id
            ? 'unique:users,email,' . $driver->user_id
            : 'unique:users,email';

        $validated = $request->validate([
            'email' => ['required', 'email', 'max:255', $emailUniqueRule],
            'license_expiry' => 'required|date',
        ]);

        $driver->update([
            'name' => $request->name,
            'phone' => $request->phone,
            'truck_number' => $request->truck_number,
            'truck_type' => $request->truck_type,
            'nationality' => $request->nationality,
            'age' => $request->age,
            'driver_license' => $request->driver_license,
            'license_expiry' => $request->license_expiry,
            'residency_expiry' => $request->residency_expiry ?? $driver->residency_expiry,
            'passport_expiry' => $request->passport_expiry ?? $driver->passport_expiry,
            'blood_type' => $request->blood_type ?? $driver->blood_type,
        ]);

        // The email itself lives on the linked user account, not the
        // driver row, so it has to be saved there explicitly.
        if ($driver->user_id) {
            $driver->user()->update(['email' => $validated['email']]);
        }
        $driver->email = $validated['email'];

        return response()->json([
            'message' => 'Driver updated successfully',
            'driver' => $driver,
        ], 200);
    }

    /**
     * Update only the driver's availability status
     * (available / busy / unavailable).
     */
    public function updateStatus(Request $request, Driver $driver)
    {
        $validated = $request->validate([
            'status' => ['required', 'in:available,busy,unavailable'],
        ]);

        $driver->update(['status' => $validated['status']]);

        return response()->json([
            'message' => 'Driver status updated successfully',
            'driver' => $driver,
        ], 200);
    }

    /**
     * Admin approves a self-registered driver, allowing them to be matched
     * with shipments. Also runs the document check so the admin gets an
     * immediate error if approving a driver whose documents are missing or
     * expired, instead of silently approving someone who still can't
     * actually be assigned any job.
     */
    public function approve(Driver $driver)
    {
        $issues = $driver->documentIssues();

        if (! empty($issues)) {
            return response()->json([
                'message' => 'Cannot approve: this driver has unresolved document issues.',
                'document_issues' => $issues,
            ], 422);
        }

        $driver->update([
            'approval_status' => 'approved',
            'rejection_reason' => null,
        ]);

        return response()->json([
            'message' => 'Driver approved successfully',
            'driver' => $driver,
        ], 200);
    }

    /**
     * Admin rejects a self-registered driver, optionally with a reason
     * shown to the driver in the app.
     */
    public function reject(Request $request, Driver $driver)
    {
        $validated = $request->validate([
            'reason' => ['nullable', 'string', 'max:255'],
        ]);

        $driver->update([
            'approval_status' => 'rejected',
            'rejection_reason' => $validated['reason'] ?? null,
        ]);

        return response()->json([
            'message' => 'Driver rejected',
            'driver' => $driver,
        ], 200);
    }

    /**
     * UC-5 alt flow: instead of outright rejecting, return the application
     * so the driver can complete missing documents/info. approval_status
     * stays 'pending' — the message goes in admin_note, which is a
     * dedicated field (unlike Company, which reuses rejection_reason for
     * this — see the Phase 1 migration notes for why: Driver already had a
     * rejection_reason column in use, so a separate admin_note column was
     * added instead of overloading it).
     */
    public function returnForCompletion(Request $request, Driver $driver)
    {
        $validated = $request->validate([
            'message' => ['required', 'string', 'max:500'],
        ]);

        $driver->update([
            'approval_status' => 'pending',
            'admin_note' => $validated['message'],
        ]);

        return response()->json([
            'message' => 'Application returned to the driver for completion',
            'driver' => $driver,
        ], 200);
    }

    /**
     * Super Admin suspends a driver directly, skipping the normal
     * compliance-report escalation (warning -> suspension), for serious
     * findings that don't need the full report/appeal workflow.
     */
    public function suspend(Request $request, Driver $driver)
    {
        $validated = $request->validate([
            'reason' => ['required', 'string', 'max:500'],
        ]);

        $driver->update([
            'compliance_status' => 'suspended',
            'admin_note' => $validated['reason'],
        ]);

        return response()->json([
            'message' => 'Driver suspended',
            'driver' => $driver,
        ], 200);
    }

    public function reactivate(Driver $driver)
    {
        $driver->update([
            'compliance_status' => 'active',
        ]);

        return response()->json([
            'message' => 'Driver reactivated',
            'driver' => $driver,
        ], 200);
    }
}
