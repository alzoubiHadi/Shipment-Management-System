<?php

namespace App\Http\Controllers;

use App\Models\ActivityLog;
use App\Models\Company;
use App\Models\CompanyDocument;
use App\Models\Driver;
use App\Models\DriverDestination;
use App\Models\DriverDocument;
use App\Models\ProfileEditRequest;
use App\Models\TruckDocument;
use App\Models\User;
use App\Notifications\AppPushNotification;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

/**
 * Self-service "tap your name" profile page, shared by every role.
 *
 * Contact info (name/phone/email) and the avatar are NOT considered
 * material to eligibility, so they're applied immediately. Anything that
 * feeds matching/approval eligibility (a driver's documents or work
 * destinations, a company's trade license) goes through
 * ProfileEditRequest instead — see DriverController::uploadDocument()/
 * syncDestinations() for where drivers submit those, and approve()/
 * reject() below for where an admin actually applies them.
 */
class ProfileController extends Controller
{
    public function show(Request $request)
    {
        $user = $request->user();

        $extra = [];
        if ($user->type === 'driver' && $user->driver) {
            $driver = $user->driver;
            $truck = \App\Models\Truck::where('default_driver_id', $driver->id)->first();

            $extra = [
                'phone' => $driver->phone,
                'approval_status' => $driver->approval_status,
                // Needed so a resumed session (app cold-start with a saved
                // token — see SplashPage's session check) can route an
                // unapproved driver to DriverApprovalStatusPage with the
                // same detail LoggingInScreen shows right after a fresh
                // login, instead of a generic status with no explanation.
                'rejection_reason' => $driver->rejection_reason,
                'document_issues' => $driver->document_issues,
                // Full driver profile fields — needed by the self-service
                // "Changes Required" edit screen (updateDriverInfo()) so it
                // can pre-fill the form instead of starting blank.
                'nationality' => $driver->nationality,
                'age' => $driver->age,
                'driver_license' => $driver->driver_license,
                'license_expiry' => optional($driver->license_expiry)->format('Y-m-d'),
                'passport_expiry' => optional($driver->passport_expiry)->format('Y-m-d'),
                'residency_expiry' => optional($driver->residency_expiry)->format('Y-m-d'),
                'blood_type' => $driver->blood_type,
                'health_conditions' => $driver->health_conditions,
                // Bank Details section (Profile screen, driver Phase 5) —
                // finance-team reference for manual payouts only, nothing
                // automated reads these yet.
                'bank_name' => $driver->bank_name,
                'bank_account_holder' => $driver->bank_account_holder,
                'bank_iban' => $driver->bank_iban,
                'truck' => $truck ? [
                    'truck_number' => $truck->truck_number,
                    'truck_type' => $truck->truck_type,
                    'permit_type' => $truck->permit_type,
                    'permit_expiry' => optional($truck->permit_expiry)->format('Y-m-d'),
                    'license_expiry' => optional($truck->license_expiry)->format('Y-m-d'),
                    'insurance_expiry' => optional($truck->insurance_expiry)->format('Y-m-d'),
                    'technical_inspection_expiry' => optional($truck->technical_inspection_expiry)->format('Y-m-d'),
                ] : null,
            ];
        } elseif ($user->type === 'company' && $user->company) {
            $extra = [
                'phone' => $user->company->phone,
                'address' => $user->company->address,
                'license_file_path' => $user->company->license_file_path,
                'approval_status' => $user->company->approval_status,
                'rejection_reason' => $user->company->rejection_reason,
                // Company Profile screen (2026-08-17 redesign) shows an
                // Active/Suspended badge — wasn't previously returned here.
                'account_status' => $user->company->account_status,
            ];
        }

        return response()->json([
            'message' => 'Profile retrieved successfully',
            'user' => array_merge([
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'type' => $user->type,
                'avatar_path' => $user->avatar_path,
            ], $extra),
        ], 200);
    }

    /**
     * Name / phone / email — applied straight away for every role, and
     * kept in sync with the mirrored columns on drivers/companies (see
     * UserController::register() for where those were first written).
     */
    public function updateBasic(Request $request)
    {
        $user = $request->user();

        try {
            $validated = $request->validate([
                'name' => ['sometimes', 'string', 'max:255'],
                'phone' => ['sometimes', 'nullable', 'string', 'max:30'],
                'email' => ['sometimes', 'email', Rule::unique('users', 'email')->ignore($user->id)],
            ]);
        } catch (ValidationException $e) {
            return response()->json(['message' => 'Validation failed', 'errors' => $e->errors()], 422);
        }

        DB::transaction(function () use ($user, $validated) {
            $userChanges = array_intersect_key($validated, array_flip(['name', 'email']));
            if ($userChanges) {
                $user->update($userChanges);
            }

            if ($user->type === 'driver' && $user->driver) {
                $driverChanges = array_intersect_key($validated, array_flip(['name', 'phone']));
                if ($driverChanges) {
                    $user->driver->update($driverChanges);
                }
            } elseif ($user->type === 'company' && $user->company) {
                $companyChanges = array_intersect_key($validated, array_flip(['name', 'phone', 'email']));
                if ($companyChanges) {
                    $user->company->update($companyChanges);
                }
            }
        });

        return response()->json([
            'message' => 'Profile updated',
            'user' => $user->fresh(),
        ], 200);
    }

    /**
     * Driver's payout bank details — same "applies immediately" treatment
     * as updateBasic(): not material to matching/approval eligibility, so
     * no admin review needed.
     */
    public function updateBankDetails(Request $request)
    {
        $user = $request->user();
        if ($user->type !== 'driver' || ! $user->driver) {
            return response()->json(['message' => 'Only a driver account has bank details'], 403);
        }

        try {
            $validated = $request->validate([
                'bank_name' => ['sometimes', 'nullable', 'string', 'max:255'],
                'bank_account_holder' => ['sometimes', 'nullable', 'string', 'max:255'],
                'bank_iban' => ['sometimes', 'nullable', 'string', 'max:64'],
            ]);
        } catch (ValidationException $e) {
            return response()->json(['message' => 'Validation failed', 'errors' => $e->errors()], 422);
        }

        $user->driver->update($validated);

        return response()->json([
            'message' => 'Bank details updated',
        ], 200);
    }

    public function uploadAvatar(Request $request)
    {
        try {
            $validated = $request->validate([
                'avatar' => ['required', 'file', 'image', 'max:5120'], // 5MB
            ]);
        } catch (ValidationException $e) {
            return response()->json(['message' => 'Validation failed', 'errors' => $e->errors()], 422);
        }

        $user = $request->user();
        $path = $request->file('avatar')->store('avatars', 'public');

        if ($user->avatar_path) {
            Storage::disk('public')->delete($user->avatar_path);
        }

        $user->update(['avatar_path' => $path]);

        return response()->json([
            'message' => 'Avatar updated',
            'avatar_path' => $path,
        ], 200);
    }

    /** The requester's own edit-request history (newest first). */
    public function myEditRequests(Request $request)
    {
        $requests = ProfileEditRequest::where('user_id', $request->user()->id)
            ->orderByDesc('created_at')
            ->get();

        return response()->json([
            'message' => 'Edit requests retrieved successfully',
            'requests' => $requests,
        ], 200);
    }

    /**
     * Company self-service trade-license renewal — mirrors
     * DriverController::uploadDocument(). Unified Approvals /
     * document-expiry feature (2026-08-22): now also collects an
     * expiry_date (previously not tracked at all — companies had no
     * license_expiry column) and creates a real CompanyDocument row
     * immediately as status='under_review'; the company's current
     * license_file_path/license_expiry are left untouched until an admin
     * decides — see applyCompanyLicense() below.
     */
    public function submitCompanyLicense(Request $request)
    {
        $user = $request->user();
        if ($user->type !== 'company' || ! $user->company) {
            return response()->json(['message' => 'Only a company account can renew a trade license'], 403);
        }

        try {
            $validated = $request->validate([
                'license_file' => ['required', 'file', 'max:10240'],
                'expiry_date' => ['required', 'date'],
            ]);
        } catch (ValidationException $e) {
            return response()->json(['message' => 'Validation failed', 'errors' => $e->errors()], 422);
        }

        $path = $request->file('license_file')->store('company_licenses', 'public');

        // While the admin has explicitly asked for changes, applying
        // directly is safe — resubmit() is what triggers a fresh admin
        // review, so a second gate here would be redundant.
        if ($user->company->approval_status === 'changes_required') {
            $company = $user->company;
            $oldPath = $company->license_file_path;

            $company->documents()->update(['is_current' => false, 'status' => 'superseded']);
            $company->documents()->create([
                'type' => 'trade_license',
                'file_path' => $path,
                'expiry_date' => $validated['expiry_date'],
                'is_current' => true,
                'status' => 'valid',
                'uploaded_by_user_id' => $user->id,
            ]);
            $company->update(['license_file_path' => $path, 'license_expiry' => $validated['expiry_date']]);
            $company->recomputeComplianceStatus();

            if ($oldPath) {
                Storage::disk('public')->delete($oldPath);
            }

            return response()->json([
                'message' => 'Trade license updated',
                'license_file_path' => $path,
            ], 200);
        }

        $document = $user->company->documents()->create([
            'type' => 'trade_license',
            'file_path' => $path,
            'expiry_date' => $validated['expiry_date'],
            'is_current' => false,
            'status' => 'under_review',
            'uploaded_by_user_id' => $user->id,
        ]);

        $editRequest = ProfileEditRequest::create([
            'user_id' => $user->id,
            'category' => 'company_license',
            'payload' => [
                'document_id' => $document->id,
                'file_path' => $path,
                'expiry_date' => $validated['expiry_date'],
            ],
            'status' => 'pending',
        ]);

        foreach (User::whereIn('type', ['admin', 'super_admin', 'sub_admin'])->get() as $admin) {
            $admin->notify(new AppPushNotification(
                'profile_edit_pending',
                'Company trade license awaiting review',
                sprintf('%s submitted a renewed trade license for review.', $user->company->name),
                ['request_id' => $editRequest->id],
            ));
        }

        return response()->json([
            'message' => 'Trade license submitted for admin review — it will apply once approved.',
            'edit_request' => $editRequest,
            'document' => $document,
        ], 201);
    }

    // ── Admin review ─────────────────────────────────────────────────────

    /**
     * $category (optional, comma-separated) narrows to specific
     * ProfileEditRequest categories — used by the admin Approvals screen's
     * "Document Renewals" tab (2026-08-22) to fetch only
     * document/truck_document/company_license, excluding 'destinations'.
     *
     * For those three document categories, each request also gets an
     * `old_document` key attached (queried live, not stored on the
     * request) so the admin review screen can show "Old Document / Expiry
     * Date / Status" next to the newly-submitted one without a second
     * round-trip per request.
     */
    public function adminIndex(Request $request)
    {
        $status = $request->query('status', 'pending');

        $query = ProfileEditRequest::with('user:id,name,email,type')->orderByDesc('created_at');
        if ($status !== 'all') {
            $query->where('status', $status);
        }

        if ($category = $request->query('category')) {
            $query->whereIn('category', explode(',', $category));
        }

        $requests = $query->get();

        $requests->each(function (ProfileEditRequest $r) {
            if (in_array($r->category, ['document', 'truck_document', 'company_license'], true)) {
                $r->old_document = $this->findOldDocumentFor($r);
            }
        });

        return response()->json([
            'message' => 'Edit requests retrieved successfully',
            'requests' => $requests,
        ], 200);
    }

    /** See adminIndex()'s docblock. Returns null when there's no prior current document (e.g. this is the driver's very first upload of that type). */
    private function findOldDocumentFor(ProfileEditRequest $editRequest): ?array
    {
        $payload = $editRequest->payload;
        $newDocumentId = $payload['document_id'] ?? null;
        $type = $payload['type'] ?? 'trade_license';

        $ownerQuery = match ($editRequest->category) {
            'document' => Driver::where('user_id', $editRequest->user_id)->first()?->documents(),
            'truck_document' => Driver::where('user_id', $editRequest->user_id)->first()?->truck?->documents(),
            'company_license' => Company::where('user_id', $editRequest->user_id)->first()?->documents(),
            default => null,
        };

        if (! $ownerQuery) {
            return null;
        }

        $old = $ownerQuery->where('type', $type)
            ->where('is_current', true)
            ->when($newDocumentId, fn ($q) => $q->where('id', '!=', $newDocumentId))
            ->first();

        if (! $old) {
            return null;
        }

        return [
            'file_path' => $old->file_path,
            'expiry_date' => optional($old->expiry_date)->format('Y-m-d'),
            'status' => $old->status,
        ];
    }

    public function approve(Request $request, ProfileEditRequest $profileEditRequest)
    {
        if (! $request->user()->hasPermission('finance') && ! $request->user()->isSuperAdmin()) {
            return response()->json(['message' => 'You do not have permission to review profile edits'], 403);
        }

        if ($profileEditRequest->status !== 'pending') {
            return response()->json(['message' => 'This request was already reviewed'], 409);
        }

        DB::transaction(function () use ($profileEditRequest, $request) {
            match ($profileEditRequest->category) {
                'document' => $this->applyDocument($profileEditRequest),
                'destinations' => $this->applyDestinations($profileEditRequest),
                'company_license' => $this->applyCompanyLicense($profileEditRequest),
                'truck_document' => $this->applyTruckDocument($profileEditRequest),
                default => null,
            };

            $profileEditRequest->update([
                'status' => 'approved',
                'reviewed_by' => $request->user()->id,
                'reviewed_at' => now(),
            ]);
        });

        ActivityLog::record(
            'profile_edit.approved',
            $profileEditRequest,
            "Approved a {$profileEditRequest->category} edit for user #{$profileEditRequest->user_id}",
            ['category' => $profileEditRequest->category, 'target_user_id' => $profileEditRequest->user_id],
        );

        $profileEditRequest->user?->notify(new AppPushNotification(
            'profile_edit_resolved',
            'Your profile update was approved',
            'An admin approved your submitted change — it is now applied to your profile.',
            ['request_id' => $profileEditRequest->id],
        ));

        return response()->json(['message' => 'Edit request approved and applied'], 200);
    }

    public function reject(Request $request, ProfileEditRequest $profileEditRequest)
    {
        if (! $request->user()->hasPermission('finance') && ! $request->user()->isSuperAdmin()) {
            return response()->json(['message' => 'You do not have permission to review profile edits'], 403);
        }

        if ($profileEditRequest->status !== 'pending') {
            return response()->json(['message' => 'This request was already reviewed'], 409);
        }

        $validated = $request->validate(['reason' => ['nullable', 'string', 'max:500']]);

        // Unified Approvals / document-expiry feature (2026-08-22): for the
        // three document categories, a real driver_documents/
        // truck_documents/company_documents row was already created at
        // submission time (status='under_review') — reject it in place
        // (status='rejected', is_current stays false) rather than deleting
        // the file, per the append-only "never delete a row" convention.
        // 'destinations' has no associated document row, so this is a
        // no-op for that category.
        $documentId = $profileEditRequest->payload['document_id'] ?? null;
        if ($documentId) {
            $documentModel = match ($profileEditRequest->category) {
                'document' => DriverDocument::class,
                'truck_document' => TruckDocument::class,
                'company_license' => CompanyDocument::class,
                default => null,
            };
            if ($documentModel) {
                $documentModel::where('id', $documentId)->update(['status' => 'rejected']);
            }
        }

        $profileEditRequest->update([
            'status' => 'rejected',
            'admin_note' => $validated['reason'] ?? null,
            'reviewed_by' => $request->user()->id,
            'reviewed_at' => now(),
        ]);

        ActivityLog::record(
            'profile_edit.rejected',
            $profileEditRequest,
            "Rejected a {$profileEditRequest->category} edit for user #{$profileEditRequest->user_id}",
            ['category' => $profileEditRequest->category, 'target_user_id' => $profileEditRequest->user_id],
        );

        $profileEditRequest->user?->notify(new AppPushNotification(
            'profile_edit_resolved',
            'Your profile update was declined',
            $validated['reason']
                ? "An admin declined your submitted change: {$validated['reason']}"
                : 'An admin declined your submitted change.',
            ['request_id' => $profileEditRequest->id],
        ));

        return response()->json(['message' => 'Edit request rejected'], 200);
    }

    /**
     * Unified Approvals / document-expiry feature (2026-08-22): the new
     * row already exists (created at submission time by
     * DriverController::uploadDocument(), status='under_review') — this
     * just flips the decision: old current row -> is_current=false,
     * status = 'expired' (if it genuinely was) or 'superseded' otherwise;
     * new row -> is_current=true, status='valid'. Then re-syncs the legacy
     * column and re-evaluates the driver's OVERALL compliance (this
     * document might not be the only expired one — see
     * Driver::recomputeComplianceStatus()).
     */
    private function applyDocument(ProfileEditRequest $editRequest): void
    {
        $driver = Driver::where('user_id', $editRequest->user_id)->first();
        if (! $driver) {
            return;
        }

        $payload = $editRequest->payload;
        $newDocument = isset($payload['document_id'])
            ? $driver->documents()->find($payload['document_id'])
            : null;

        $oldCurrent = $driver->documents()
            ->where('type', $payload['type'])
            ->where('is_current', true)
            ->when($newDocument, fn ($q) => $q->where('id', '!=', $newDocument->id))
            ->first();

        if ($oldCurrent) {
            $oldCurrent->update([
                'is_current' => false,
                'status' => $oldCurrent->isExpired() ? 'expired' : 'superseded',
            ]);
        }

        if ($newDocument) {
            $newDocument->update(['is_current' => true, 'status' => 'valid']);
        } else {
            // Fallback for any pre-migration payload without a document_id.
            $driver->documents()->create([
                'type' => $payload['type'],
                'file_path' => $payload['file_path'],
                'expiry_date' => $payload['expiry_date'] ?? null,
                'is_current' => true,
                'status' => 'valid',
                'uploaded_by_user_id' => $editRequest->user_id,
            ]);
        }

        $legacyColumn = match ($payload['type']) {
            'license' => 'license_expiry',
            'passport' => 'passport_expiry',
            'residency' => 'residency_expiry',
            default => null,
        };

        if ($legacyColumn) {
            $driver->update([$legacyColumn => $payload['expiry_date'] ?? null]);
        }

        $driver->recomputeComplianceStatus();
    }

    /**
     * Same pattern as applyDocument(), for a truck's license/insurance/
     * technical_inspection renewal. Syncs the matching column on the
     * `trucks` row itself (the denormalized "current value", same role
     * drivers.license_expiry etc. play) and re-evaluates the OWNING
     * DRIVER's compliance (a truck has no compliance_status of its own —
     * see Driver::recomputeComplianceStatus(), which already checks the
     * linked truck's expiries too).
     */
    private function applyTruckDocument(ProfileEditRequest $editRequest): void
    {
        $driver = Driver::where('user_id', $editRequest->user_id)->first();
        if (! $driver) {
            return;
        }

        $truck = $driver->truck;
        if (! $truck) {
            return;
        }

        $payload = $editRequest->payload;
        $newDocument = isset($payload['document_id'])
            ? $truck->documents()->find($payload['document_id'])
            : null;

        $oldCurrent = $truck->documents()
            ->where('type', $payload['type'])
            ->where('is_current', true)
            ->when($newDocument, fn ($q) => $q->where('id', '!=', $newDocument->id))
            ->first();

        if ($oldCurrent) {
            $oldCurrent->update([
                'is_current' => false,
                'status' => $oldCurrent->isExpired() ? 'expired' : 'superseded',
            ]);
        }

        if ($newDocument) {
            $newDocument->update(['is_current' => true, 'status' => 'valid']);
        } else {
            $truck->documents()->create([
                'type' => $payload['type'],
                'file_path' => $payload['file_path'],
                'expiry_date' => $payload['expiry_date'] ?? null,
                'is_current' => true,
                'status' => 'valid',
                'uploaded_by_user_id' => $editRequest->user_id,
            ]);
        }

        $truckColumn = match ($payload['type']) {
            'license' => 'license_expiry',
            'insurance' => 'insurance_expiry',
            'technical_inspection' => 'technical_inspection_expiry',
            default => null,
        };

        if ($truckColumn) {
            $truck->update([$truckColumn => $payload['expiry_date'] ?? null]);
        }

        $driver->recomputeComplianceStatus();
    }

    /** Exact same apply logic DriverController::syncDestinations() used to run inline before it became review-gated. */
    private function applyDestinations(ProfileEditRequest $editRequest): void
    {
        $driver = Driver::where('user_id', $editRequest->user_id)->first();
        if (! $driver) {
            return;
        }

        $driver->destinations()->delete();
        foreach ($editRequest->payload['destinations'] ?? [] as $destination) {
            $driver->destinations()->create(['destination' => $destination]);
        }
    }

    /** Same pattern as applyDocument(), for the company's trade license. */
    private function applyCompanyLicense(ProfileEditRequest $editRequest): void
    {
        $company = Company::where('user_id', $editRequest->user_id)->first();
        if (! $company) {
            return;
        }

        $payload = $editRequest->payload;
        $newDocument = isset($payload['document_id'])
            ? $company->documents()->find($payload['document_id'])
            : null;

        $oldCurrent = $company->documents()
            ->where('type', 'trade_license')
            ->where('is_current', true)
            ->when($newDocument, fn ($q) => $q->where('id', '!=', $newDocument->id))
            ->first();

        if ($oldCurrent) {
            $oldCurrent->update([
                'is_current' => false,
                'status' => $oldCurrent->isExpired() ? 'expired' : 'superseded',
            ]);
        }

        if ($newDocument) {
            $newDocument->update(['is_current' => true, 'status' => 'valid']);
        } else {
            $company->documents()->create([
                'type' => 'trade_license',
                'file_path' => $payload['file_path'],
                'expiry_date' => $payload['expiry_date'] ?? null,
                'is_current' => true,
                'status' => 'valid',
                'uploaded_by_user_id' => $editRequest->user_id,
            ]);
        }

        $company->update([
            'license_file_path' => $payload['file_path'],
            'license_expiry' => $payload['expiry_date'] ?? null,
        ]);

        $company->recomputeComplianceStatus();
    }
}
