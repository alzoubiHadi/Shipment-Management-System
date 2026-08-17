<?php

namespace App\Http\Controllers;

use App\Models\Driver;
use App\Models\ProfileEditRequest;
use App\Models\Truck;
use App\Models\TruckDocument;
use App\Models\User;
use App\Notifications\AppPushNotification;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
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

        // A driver registers with exactly one truck and may only ever have
        // one — this endpoint used to let them add unlimited extra trucks,
        // which contradicted that. To register a *different* truck, the
        // existing one must be removed first (admin-assisted, not exposed
        // here on purpose).
        if (Truck::where('default_driver_id', $driver->id)->exists()) {
            return response()->json([
                'message' => 'You already have a registered truck. Contact an admin to replace it.',
            ], 422);
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

    /**
     * Driver's own fix-up submission (2026-08-19) for their existing truck,
     * only reachable while their approval_status === 'changes_required' —
     * same gating rationale as DriverController::updateDriverInfo().
     * Every field is optional so the driver can send just what changed.
     */
    public function updateMyTruck(Request $request, $driver_user_id)
    {
        $driver = Driver::where('user_id', $driver_user_id)->first();

        if (! $driver) {
            return response()->json(['message' => 'Driver not found'], 404);
        }

        if ($driver->approval_status !== 'changes_required') {
            return response()->json([
                'message' => 'You can only edit your truck while an admin has requested changes',
            ], 409);
        }

        $truck = Truck::where('default_driver_id', $driver->id)->first();
        if (! $truck) {
            return response()->json(['message' => 'You do not have a registered truck yet'], 404);
        }

        try {
            $validated = $request->validate([
                'truck_number' => ['sometimes', 'string', 'unique:trucks,truck_number,' . $truck->id],
                'truck_type' => ['sometimes', 'string', 'in:' . implode(',', Truck::TRUCK_TYPES)],
                'max_load' => ['sometimes', 'nullable', 'numeric'],
                'permit_type' => ['sometimes', 'nullable', 'string'],
                'permit_expiry' => ['sometimes', 'nullable', 'date'],
                'insurance_expiry' => ['sometimes', 'nullable', 'date'],
                'license_expiry' => ['sometimes', 'nullable', 'date'],
                'technical_inspection_expiry' => ['sometimes', 'nullable', 'date'],
                'license_file' => ['sometimes', 'file', 'max:10240'],
                'insurance_file' => ['sometimes', 'file', 'max:10240'],
                'technical_inspection_file' => ['sometimes', 'file', 'max:10240'],
            ]);
        } catch (ValidationException $e) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $e->errors(),
            ], 422);
        }

        foreach ([
            'license_file' => ['license_file_path', 'truck_licenses'],
            'insurance_file' => ['insurance_file_path', 'truck_insurance'],
            'technical_inspection_file' => ['technical_inspection_file_path', 'truck_inspections'],
        ] as $inputKey => [$column, $folder]) {
            if ($request->hasFile($inputKey)) {
                $oldPath = $truck->{$column};
                $validated[$column] = $request->file($inputKey)->store($folder, 'public');
                if ($oldPath) {
                    Storage::disk('public')->delete($oldPath);
                }
            }
            unset($validated[$inputKey]);
        }

        $truck->update($validated);

        return response()->json([
            'message' => 'Truck updated',
            'truck' => $truck->fresh(),
        ], 200);
    }

    // ── Truck documents (Unified Approvals / document-expiry feature, 2026-08-22) ──

    /** History of this driver's truck's document renewals — same pattern as DriverController::documents(). */
    public function myTruckDocuments($driver_user_id)
    {
        $driver = Driver::where('user_id', $driver_user_id)->first();
        if (! $driver) {
            return response()->json(['message' => 'Driver not found'], 404);
        }

        $truck = Truck::where('default_driver_id', $driver->id)->first();
        if (! $truck) {
            return response()->json(['message' => 'You do not have a registered truck yet'], 404);
        }

        return response()->json([
            'message' => 'Truck documents retrieved successfully',
            'documents' => $truck->documents()->orderByDesc('created_at')->get(),
        ], 200);
    }

    /**
     * A driver renewing their truck's license/insurance/technical
     * inspection — previously there was no workflow for this at all
     * outside the changes_required edit window (see updateMyTruck()
     * above). Mirrors DriverController::uploadDocument() exactly: the new
     * row is created immediately as status='under_review', is_current
     * stays false so the truck's existing (still is_current=true) document
     * keeps counting for Truck::isRoadworthy()/suitabilityIssue() until an
     * admin decides — see ProfileController::applyTruckDocument().
     */
    public function uploadMyTruckDocument(Request $request, $driver_user_id)
    {
        $driver = Driver::where('user_id', $driver_user_id)->first();
        if (! $driver) {
            return response()->json(['message' => 'Driver not found'], 404);
        }

        $truck = Truck::where('default_driver_id', $driver->id)->first();
        if (! $truck) {
            return response()->json(['message' => 'You do not have a registered truck yet'], 404);
        }

        try {
            $validated = $request->validate([
                'type' => ['required', 'string', 'in:' . implode(',', TruckDocument::TYPES)],
                'file' => ['required', 'file', 'max:10240'],
                'expiry_date' => ['nullable', 'date'],
            ]);
        } catch (ValidationException $e) {
            return response()->json(['message' => 'Validation failed', 'errors' => $e->errors()], 422);
        }

        $folder = match ($validated['type']) {
            'insurance' => 'truck_insurance',
            'technical_inspection' => 'truck_inspections',
            default => 'truck_licenses',
        };
        $path = $request->file('file')->store($folder, 'public');

        $currentDoc = $truck->documents()->where('type', $validated['type'])->where('is_current', true)->first();

        // Compliance/Approval separation feature (2026-08-23): same
        // resubmission detection as DriverController::uploadDocument().
        $isResubmission = $truck->documents()->where('type', $validated['type'])->where('status', 'changes_required')->exists();
        if ($isResubmission) {
            $truck->documents()->where('type', $validated['type'])->where('status', 'changes_required')->update(['status' => 'superseded']);
        }

        $document = $truck->documents()->create([
            'type' => $validated['type'],
            'file_path' => $path,
            'expiry_date' => $validated['expiry_date'] ?? null,
            'is_current' => false,
            'previous_document_id' => $currentDoc?->id,
            'status' => 'pending_review',
            'uploaded_by_user_id' => $driver_user_id,
        ]);

        $editRequest = ProfileEditRequest::create([
            'user_id' => $driver_user_id,
            'category' => 'truck_document',
            'payload' => [
                'document_id' => $document->id,
                'type' => $validated['type'],
                'file_path' => $path,
                'expiry_date' => $validated['expiry_date'] ?? null,
            ],
            'status' => 'pending',
        ]);

        $driver->recomputeComplianceStatus();

        $driver->user?->notify(new AppPushNotification(
            'renewal_submitted',
            'Renewal submitted',
            sprintf('Your truck %s renewal was submitted and is now pending admin review.', str_replace('_', ' ', $validated['type'])),
            ['document_id' => $document->id],
        ));

        foreach (User::whereIn('type', ['admin', 'super_admin', 'sub_admin'])->get() as $admin) {
            $admin->notify(new AppPushNotification(
                $isResubmission ? 'renewal_resubmitted' : 'new_document_renewal',
                $isResubmission ? 'Truck document renewal resubmitted' : 'Truck document awaiting review',
                sprintf('%s %s a truck %s renewal for review.', $driver->name, $isResubmission ? 're-submitted' : 'submitted', str_replace('_', ' ', $validated['type'])),
                ['request_id' => $editRequest->id],
            ));
        }

        return response()->json([
            'message' => 'Document submitted for admin review — it will apply once approved.',
            'edit_request' => $editRequest,
            'document' => $document,
        ], 201);
    }
}
