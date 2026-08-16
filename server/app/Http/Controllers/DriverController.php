<?php

namespace App\Http\Controllers;

use App\Models\ActivityLog;
use App\Models\Driver;
use App\Models\DriverDestination;
use App\Models\DriverDocument;
use App\Models\ProfileEditRequest;
use App\Models\User;
use App\Notifications\AppPushNotification;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
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
        ActivityLog::record('driver.deleted', $driver, "Deleted driver '{$driver->name}'");
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
            // Sensitive medical data — never returned in company-facing
            // responses (see CompanyFacingDriverResource). Admin and the
            // driver themselves may read/write it here.
            'health_conditions' => $request->health_conditions ?? $driver->health_conditions,
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
        ActivityLog::record('driver.approved', $driver, "Approved driver '{$driver->name}'");

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
        ActivityLog::record(
            'driver.rejected',
            $driver,
            "Rejected driver '{$driver->name}'",
            ['reason' => $validated['reason'] ?? null]
        );

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
        ActivityLog::record(
            'driver.suspended',
            $driver,
            "Suspended driver '{$driver->name}'",
            ['reason' => $validated['reason']]
        );

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
        ActivityLog::record('driver.reactivated', $driver, "Reactivated driver '{$driver->name}'");

        return response()->json([
            'message' => 'Driver reactivated',
            'driver' => $driver,
        ], 200);
    }

    // ── Documents (UC-8: append-only, never delete) ──────────────────────────

    /**
     * A driver only knows their own user_id (that's what's stored in the
     * app after login) — not the internal drivers.id — so this resolves
     * the same way /driver/{driver_user_id}/trucks does. Admins reviewing
     * a specific driver's file also have that driver's user_id available
     * from the drivers list response.
     */
    public function documents($driver_user_id)
    {
        $driver = Driver::where('user_id', $driver_user_id)->first();

        if (! $driver) {
            return response()->json(['message' => 'Driver not found'], 404);
        }

        return response()->json([
            'message' => 'Documents retrieved successfully',
            'documents' => $driver->documents()->orderByDesc('created_at')->get(),
        ], 200);
    }

    /**
     * A driver renewing/uploading their own document is a change that's
     * material to eligibility (it directly feeds Driver::isEligibleForNewJob
     * / documentIssues), so it is NEVER applied straight away here — it's
     * stored as a pending ProfileEditRequest and only actually written into
     * driver_documents (see the exact apply logic in
     * ProfileController::applyDocument()) once an admin approves it. The
     * uploaded file itself is stored immediately (so nothing is lost while
     * it waits for review), just not yet linked as the driver's current
     * document.
     */
    public function uploadDocument(Request $request, $driver_user_id)
    {
        $driver = Driver::where('user_id', $driver_user_id)->first();

        if (! $driver) {
            return response()->json(['message' => 'Driver not found'], 404);
        }

        try {
            $validated = $request->validate([
                'type' => ['required', 'string', 'in:' . implode(',', DriverDocument::TYPES)],
                'file' => ['required', 'file', 'max:10240'], // 10MB
                'expiry_date' => ['nullable', 'date'],
            ]);
        } catch (ValidationException $e) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $e->errors(),
            ], 422);
        }

        $path = $request->file('file')->store('driver_documents', 'public');

        $editRequest = ProfileEditRequest::create([
            'user_id' => $driver_user_id,
            'category' => 'document',
            'payload' => [
                'type' => $validated['type'],
                'file_path' => $path,
                'expiry_date' => $validated['expiry_date'] ?? null,
            ],
            'status' => 'pending',
        ]);

        foreach (User::whereIn('type', ['admin', 'super_admin', 'sub_admin'])->get() as $admin) {
            $admin->notify(new AppPushNotification(
                'profile_edit_pending',
                'Driver document awaiting review',
                sprintf('%s submitted a %s renewal for review.', $driver->name, $validated['type']),
                ['request_id' => $editRequest->id],
            ));
        }

        return response()->json([
            'message' => 'Document submitted for admin review — it will apply once approved.',
            'edit_request' => $editRequest,
        ], 201);
    }

    // ── Destinations ───────────────────────────────────────────────────────

    public function destinationOptions()
    {
        return response()->json([
            'message' => 'Destination options retrieved successfully',
            'destinations' => DriverDestination::DESTINATIONS,
        ], 200);
    }

    public function myDestinations($driver_user_id)
    {
        $driver = Driver::where('user_id', $driver_user_id)->first();

        if (! $driver) {
            return response()->json(['message' => 'Driver not found'], 404);
        }

        return response()->json([
            'message' => 'Destinations retrieved successfully',
            'destinations' => $driver->destinations()->pluck('destination'),
        ], 200);
    }

    /**
     * Full replace of the driver's destination list (at least 1 required —
     * a driver must be reachable by the matching algorithm for something).
     * Same as uploadDocument(): the driver's own change to their coverage
     * area is material to matching eligibility, so it's queued as a
     * pending ProfileEditRequest instead of applied immediately — an admin
     * must approve it first (see ProfileController::applyDestinations()).
     */
    public function syncDestinations(Request $request, $driver_user_id)
    {
        $driver = Driver::where('user_id', $driver_user_id)->first();

        if (! $driver) {
            return response()->json(['message' => 'Driver not found'], 404);
        }

        $validated = $request->validate([
            'destinations' => ['required', 'array', 'min:1'],
            'destinations.*' => ['string', 'in:' . implode(',', array_keys(DriverDestination::DESTINATIONS))],
        ]);

        $editRequest = ProfileEditRequest::create([
            'user_id' => $driver_user_id,
            'category' => 'destinations',
            'payload' => ['destinations' => array_values(array_unique($validated['destinations']))],
            'status' => 'pending',
        ]);

        foreach (User::whereIn('type', ['admin', 'super_admin', 'sub_admin'])->get() as $admin) {
            $admin->notify(new AppPushNotification(
                'profile_edit_pending',
                'Driver destinations awaiting review',
                sprintf('%s submitted a change to their work destinations for review.', $driver->name),
                ['request_id' => $editRequest->id],
            ));
        }

        return response()->json([
            'message' => 'Destination change submitted for admin review — it will apply once approved.',
            'edit_request' => $editRequest,
        ], 200);
    }

    /**
     * UC-21/UC-14: near-live location, foreground-only per the spec (no
     * background tracking service) — the Flutter app calls this
     * periodically while it's open and the driver is 'available' or
     * 'busy'. Feeds both live tracking (company-facing, via
     * ShipmentController::trackmyshipment) and the Haversine proximity
     * term in the matching score (MatchingService::proximityScore).
     */
    public function updateLocation(Request $request, $driver_user_id)
    {
        $driver = Driver::where('user_id', $driver_user_id)->first();

        if (! $driver) {
            return response()->json(['message' => 'Driver not found'], 404);
        }

        if ($driver->user_id != $request->user()->id) {
            return response()->json(['message' => 'You can only update your own location'], 403);
        }

        $validated = $request->validate([
            'lat' => ['required', 'numeric', 'between:-90,90'],
            'lng' => ['required', 'numeric', 'between:-180,180'],
        ]);

        $driver->update([
            'last_lat' => $validated['lat'],
            'last_lng' => $validated['lng'],
            'last_location_at' => now(),
        ]);

        return response()->json(['message' => 'Location updated successfully'], 200);
    }

    /**
     * UC-10: driver toggles their own "available for work" status. Same
     * user_id-resolution pattern as updateLocation() above — the app only
     * knows the logged-in user's id, not the internal drivers.id.
     */
    public function updateMyStatus(Request $request, $driver_user_id)
    {
        $driver = Driver::where('user_id', $driver_user_id)->first();

        if (! $driver) {
            return response()->json(['message' => 'Driver not found'], 404);
        }

        if ($driver->user_id != $request->user()->id) {
            return response()->json(['message' => 'You can only update your own status'], 403);
        }

        $validated = $request->validate([
            'status' => ['required', 'in:available,busy,unavailable'],
        ]);

        $driver->update(['status' => $validated['status']]);

        return response()->json([
            'message' => 'Status updated successfully',
            'driver' => $driver,
        ], 200);
    }
}
