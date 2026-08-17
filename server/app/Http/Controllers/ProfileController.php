<?php

namespace App\Http\Controllers;

use App\Models\ActivityLog;
use App\Models\Company;
use App\Models\Driver;
use App\Models\DriverDestination;
use App\Models\ProfileEditRequest;
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
     * DriverController::uploadDocument(): the file is stored immediately,
     * but it only becomes the company's license_file_path once an admin
     * approves it.
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
            ]);
        } catch (ValidationException $e) {
            return response()->json(['message' => 'Validation failed', 'errors' => $e->errors()], 422);
        }

        $path = $request->file('license_file')->store('company_licenses', 'public');

        // While the admin has explicitly asked for changes, applying
        // directly is safe — resubmit() is what triggers a fresh admin
        // review, so a second gate here would be redundant.
        if ($user->company->approval_status === 'changes_required') {
            $oldPath = $user->company->license_file_path;
            $user->company->update(['license_file_path' => $path]);
            if ($oldPath) {
                Storage::disk('public')->delete($oldPath);
            }

            return response()->json([
                'message' => 'Trade license updated',
                'license_file_path' => $path,
            ], 200);
        }

        $editRequest = ProfileEditRequest::create([
            'user_id' => $user->id,
            'category' => 'company_license',
            'payload' => ['file_path' => $path],
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
        ], 201);
    }

    // ── Admin review ─────────────────────────────────────────────────────

    public function adminIndex(Request $request)
    {
        $status = $request->query('status', 'pending');

        $query = ProfileEditRequest::with('user:id,name,email,type')->orderByDesc('created_at');
        if ($status !== 'all') {
            $query->where('status', $status);
        }

        return response()->json([
            'message' => 'Edit requests retrieved successfully',
            'requests' => $query->get(),
        ], 200);
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

        // The submitted file was never linked anywhere — safe to remove.
        $filePath = $profileEditRequest->payload['file_path'] ?? null;
        if ($filePath) {
            Storage::disk('public')->delete($filePath);
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

    /** Exact same apply logic DriverController::uploadDocument() used to run inline before it became review-gated. */
    private function applyDocument(ProfileEditRequest $editRequest): void
    {
        $driver = Driver::where('user_id', $editRequest->user_id)->first();
        if (! $driver) {
            return;
        }

        $payload = $editRequest->payload;

        $driver->documents()->where('type', $payload['type'])->update(['is_current' => false]);

        $driver->documents()->create([
            'type' => $payload['type'],
            'file_path' => $payload['file_path'],
            'expiry_date' => $payload['expiry_date'] ?? null,
            'is_current' => true,
            'uploaded_by_user_id' => $editRequest->user_id,
        ]);

        $legacyColumn = match ($payload['type']) {
            'license' => 'license_expiry',
            'passport' => 'passport_expiry',
            'residency' => 'residency_expiry',
            default => null,
        };

        if ($legacyColumn) {
            $driver->update([$legacyColumn => $payload['expiry_date'] ?? null]);
        }
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

    private function applyCompanyLicense(ProfileEditRequest $editRequest): void
    {
        $company = Company::where('user_id', $editRequest->user_id)->first();
        if (! $company) {
            return;
        }

        $oldPath = $company->license_file_path;
        $company->update(['license_file_path' => $editRequest->payload['file_path']]);

        if ($oldPath) {
            Storage::disk('public')->delete($oldPath);
        }
    }
}
