<?php

namespace App\Http\Controllers;

use App\Models\ActivityLog;
use App\Models\Company;
use App\Models\CompanyDocument;
use App\Models\Driver;
use App\Models\DriverDestination;
use App\Models\DriverDocument;
use App\Models\Permission;
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
    /** ProfileEditRequest categories that represent a document renewal (as opposed to 'destinations'). */
    const RENEWAL_CATEGORIES = ['document', 'truck_document', 'company_license'];

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
                // Compliance/Approval separation feature (2026-08-23): the
                // Trade License card now shows Status + Days Remaining, same
                // pattern as the driver My Documents screen — needs the
                // license's own expiry_date and compliance_status, neither
                // of which was returned here before.
                'license_expiry' => optional($user->company->license_expiry)->format('Y-m-d'),
                'compliance_status' => $user->company->compliance_status,
            ];
        } elseif ($user->isSuperAdmin() || $user->isSubAdmin()) {
            // Needed so UserProfilePage can show permission badges and
            // AdminDrawer can hide menu items the admin has no access to —
            // previously this response only carried 'type', not permissions.
            $extra = [
                'permissions' => $user->isSuperAdmin()
                    // Super Admin never has permission_user rows (implicit
                    // access to everything — see User::hasPermission()), so
                    // return the full catalog instead of an empty list.
                    ? Permission::pluck('key')
                    : $user->permissions()->pluck('key'),
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

        // Case-insensitivity fix (2026-08-25) — see User::setEmailAttribute().
        if ($request->filled('email')) {
            $request->merge(['email' => User::normalizeEmail($request->input('email'))]);
        }

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

        $company = $user->company;
        $currentDoc = $company->documents()->where('type', 'trade_license')->where('is_current', true)->first();

        // While the admin has explicitly asked for changes, applying
        // directly is safe — resubmit() is what triggers a fresh admin
        // review, so a second gate here would be redundant.
        if ($company->approval_status === 'changes_required') {
            $oldPath = $company->license_file_path;

            $company->documents()->update(['is_current' => false, 'status' => 'superseded']);
            $company->documents()->create([
                'type' => 'trade_license',
                'file_path' => $path,
                'expiry_date' => $validated['expiry_date'],
                'is_current' => true,
                'previous_document_id' => $currentDoc?->id,
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

        // Compliance/Approval separation feature (2026-08-23): same
        // resubmission detection as DriverController::uploadDocument().
        $isResubmission = $company->documents()->where('type', 'trade_license')->where('status', 'changes_required')->exists();
        if ($isResubmission) {
            $company->documents()->where('type', 'trade_license')->where('status', 'changes_required')->update(['status' => 'superseded']);
        }

        $document = $company->documents()->create([
            'type' => 'trade_license',
            'file_path' => $path,
            'expiry_date' => $validated['expiry_date'],
            'is_current' => false,
            'previous_document_id' => $currentDoc?->id,
            'status' => 'pending_review',
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

        $company->recomputeComplianceStatus();

        $user->notify(new AppPushNotification(
            'renewal_submitted',
            'Renewal submitted',
            'Your trade license renewal was submitted and is now pending admin review.',
            ['document_id' => $document->id],
        ));

        foreach (User::whereIn('type', ['admin', 'super_admin', 'sub_admin'])->get() as $admin) {
            $admin->notify(new AppPushNotification(
                $isResubmission ? 'renewal_resubmitted' : 'new_document_renewal',
                $isResubmission ? 'Trade license renewal resubmitted' : 'Company trade license awaiting review',
                sprintf('%s %s a renewed trade license for review.', $company->name, $isResubmission ? 're-submitted' : 'submitted'),
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
    /**
     * Which permission key gates reviewing a given edit-request category.
     * 'document' (driver document renewals) -> trainer, 'truck_document'
     * -> technical_check, per the user's confirmed scope ("نقطة المدرب
     * والفحص الفني فقط فحص مستندات" — trainer/technical_check are
     * document-review-only roles). 'company_license' and 'destinations'
     * stay under finance as before — they were never part of the
     * trainer/technical_check scope.
     */
    private function reviewPermissionFor(string $category): string
    {
        return match ($category) {
            'document' => 'trainer',
            'truck_document' => 'technical_check',
            default => 'finance',
        };
    }

    public function adminIndex(Request $request)
    {
        $user = $request->user();

        // Route no longer gates this with a single permission:finance
        // middleware (see routes/api.php) — a trainer or technical_check
        // admin needs to reach this endpoint too, just scoped to only the
        // categories their permission actually covers.
        $allowedCategories = array_values(array_filter(
            ['document', 'truck_document', 'company_license', 'destinations'],
            fn ($category) => $user->isSuperAdmin() || $user->hasPermission($this->reviewPermissionFor($category)),
        ));

        if (empty($allowedCategories)) {
            return response()->json(['message' => 'You do not have permission to review profile edits'], 403);
        }

        $status = $request->query('status', 'pending');

        $query = ProfileEditRequest::with('user:id,name,email,type')->orderByDesc('created_at');
        if ($status !== 'all') {
            $query->where('status', $status);
        }

        // Intersect whatever the client asked for with what this admin is
        // actually allowed to see, instead of trusting the client-supplied
        // category list outright — a trainer-only admin must never receive
        // company_license rows even if the app requested them.
        $requestedCategories = $request->query('category')
            ? explode(',', $request->query('category'))
            : $allowedCategories;
        $query->whereIn('category', array_intersect($requestedCategories, $allowedCategories));

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
        $requiredPermission = $this->reviewPermissionFor($profileEditRequest->category);
        if (! $request->user()->hasPermission($requiredPermission) && ! $request->user()->isSuperAdmin()) {
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

        $isDocumentRenewal = in_array($profileEditRequest->category, self::RENEWAL_CATEGORIES, true);

        $profileEditRequest->user?->notify(new AppPushNotification(
            $isDocumentRenewal ? 'renewal_approved' : 'profile_edit_resolved',
            $isDocumentRenewal ? 'Renewal approved' : 'Your profile update was approved',
            $isDocumentRenewal
                ? 'An admin approved your document renewal — it is now your current document on file.'
                : 'An admin approved your submitted change — it is now applied to your profile.',
            ['request_id' => $profileEditRequest->id],
        ));

        return response()->json(['message' => 'Edit request approved and applied'], 200);
    }

    public function reject(Request $request, ProfileEditRequest $profileEditRequest)
    {
        $requiredPermission = $this->reviewPermissionFor($profileEditRequest->category);
        if (! $request->user()->hasPermission($requiredPermission) && ! $request->user()->isSuperAdmin()) {
            return response()->json(['message' => 'You do not have permission to review profile edits'], 403);
        }

        if ($profileEditRequest->status !== 'pending') {
            return response()->json(['message' => 'This request was already reviewed'], 409);
        }

        $validated = $request->validate(['reason' => ['nullable', 'string', 'max:500']]);

        // Compliance/Approval separation feature (2026-08-23): for the
        // three document categories, a real driver_documents/
        // truck_documents/company_documents row was already created at
        // submission time (status='pending_review') — moving it to
        // 'changes_required' in place (is_current stays false) rather than
        // deleting the file, per the append-only "never delete a row"
        // convention. Per spec, the account stays operationally inactive
        // (compliance_status recomputes back to 'action_required' — see
        // ComplianceService::effectiveState()) until the owner resubmits.
        // 'destinations' has no associated document row, so this is a
        // no-op for that category.
        $documentId = $profileEditRequest->payload['document_id'] ?? null;
        $isDocumentRenewal = in_array($profileEditRequest->category, self::RENEWAL_CATEGORIES, true);
        if ($documentId && $isDocumentRenewal) {
            $documentModel = match ($profileEditRequest->category) {
                'document' => DriverDocument::class,
                'truck_document' => TruckDocument::class,
                'company_license' => CompanyDocument::class,
                default => null,
            };
            if ($documentModel) {
                $documentModel::where('id', $documentId)->update(['status' => 'changes_required']);
            }

            // Re-evaluate compliance now, not just on the next daily run —
            // a 'pending_review' document reverting to 'changes_required'
            // means the account is (still) 'action_required'. Both
            // 'document' and 'truck_document' resolve to the same Driver
            // via user_id (a truck document renewal is submitted by its
            // owning driver — see TruckController::uploadMyTruckDocument()).
            match ($profileEditRequest->category) {
                'document', 'truck_document' => Driver::where('user_id', $profileEditRequest->user_id)->first()?->recomputeComplianceStatus(),
                'company_license' => Company::where('user_id', $profileEditRequest->user_id)->first()?->recomputeComplianceStatus(),
                default => null,
            };
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
            $isDocumentRenewal ? 'renewal_changes_required' : 'profile_edit_resolved',
            $isDocumentRenewal ? 'Changes required on your renewal' : 'Your profile update was declined',
            $validated['reason']
                ? "An admin requested changes on your submission: {$validated['reason']}"
                : 'An admin requested changes on your submitted document — please re-upload it.',
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
