<?php

namespace App\Http\Controllers;

use App\Models\ActivityLog;
use App\Models\Company;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;


class CompanyController extends Controller
{
    /**
     * Company app: its own record, including balance/credit_limit — used
     * by the Flutter balance page. No separate "my company" data existed
     * anywhere else (the company's own token never exposes company.id
     * directly, only user.id).
     */
    public function myCompany(Request $request)
    {
        $company = Company::where('user_id', $request->user()->id)->first();

        if (! $company) {
            return response()->json(['message' => 'Company not found'], 404);
        }

        return response()->json([
            'message' => 'Company retrieved successfully',
            'company' => $company,
        ], 200);
    }

    //
    public function update_profile(Request $request, Company $company)
    {
        // Case-insensitivity fix (2026-08-25) — see Company::setEmailAttribute().
        if ($request->filled('email')) {
            $request->merge(['email' => User::normalizeEmail($request->input('email'))]);
        }

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:companies,email,' . $company->id],
            'address' => ['required', 'string', 'max:255'],
            'phone' => ['required', 'string', 'max:20'],
        ]);

        $company->update($validated);

        return response()->json([
            'message' => 'Profile updated successfully',
            'company' => $company,
        ], 200);
    }
    public function index()
    {
        $companies = Company::all();
      
        return response()->json([
            'message' => 'Companies retrieved successfully',
            'companies' => $companies,

        ], 200);
    }
    public function index_trashed()
    {
        $companies_trashed = Company::onlyTrashed()->get();
        return response()->json([
            'message' => 'Companies onlyTrashed retrieved successfully',
            'companies' => $companies_trashed,

        ], 200);
    }
    public function create(Request $request)
    {
        // Case-insensitivity fix (2026-08-25) — see User::setEmailAttribute().
        if ($request->filled('email')) {
            $request->merge(['email' => User::normalizeEmail($request->input('email'))]);
        }

        try {
            $validated = $request->validate([
                'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            ]);
                    $user = User::create([
            'name' => $request->name,
            'email' => $request->email,
            'password' => bcrypt($request->password), // Default password, should be changed by the user
            'type' => 'company'
        ]);
                $company = Company::create([
            'name' => $request->name,
            'email' => $request->email,
            'address' => $request->address,
            'phone' => $request->phone,
            'user_id' => $user->id,
        ]);
        
        return response()->json([
            'message' => 'Company created successfully',
            'company' => $company,
        ], 201);
        } catch (ValidationException $e) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $e->errors(),
            ], 422);
        }
    }
    public function destroy(Company $company)
    {
        ActivityLog::record('company.deleted', $company, "Deleted company '{$company->name}'");
        $company->delete();
        $company->user()->delete(); // Also delete the associated user
        return response()->json([
            'message' => 'Company deleted successfully',
        ], 200);
    }
    public function restore( $id)
    {
        $company = Company::withTrashed()->findOrFail($id);
        $company->restore();
        $company->user()->restore(); // Also restore the associated user
        return response()->json([
            'message' => 'Company restored successfully',
        ], 200);
    }

    public function update(Request $request,Company $company){
        $company->update([
            'name' => $request->name,
            'email' => $request->email,
            'address' => $request->address,
            'phone' => $request->phone,
        ]);

        return response()->json([
            'message' => 'Company updated successfully',
            'company' => $company,
        ], 200);
    }

    /**
     * Finance Admin: sets how far below zero (companies.balance) this
     * company is allowed to go when creating a shipment offer
     * (Company::canAffordOffer(), UC-11/UC-29). Every company starts at
     * credit_limit = 0, so this must be set at least once before a
     * company can create any priced offer at all — there's no dedicated
     * UC for it in the spec, but UC-29's special requirement ("the
     * company's credit limit is applied when calculating the new
     * balance") only makes sense if something can actually set it above
     * zero first.
     */
    public function setCreditLimit(Request $request, Company $company)
    {
        $validated = $request->validate([
            'credit_limit' => ['required', 'numeric', 'min:0'],
        ]);

        $oldLimit = $company->credit_limit;
        $company->update(['credit_limit' => $validated['credit_limit']]);
        ActivityLog::record(
            'company.credit_limit_changed',
            $company,
            "Changed credit limit for '{$company->name}' from {$oldLimit} to {$validated['credit_limit']}",
            ['old' => $oldLimit, 'new' => $validated['credit_limit']]
        );

        return response()->json([
            'message' => 'Credit limit updated successfully',
            'company' => $company->fresh(),
        ], 200);
    }

    /**
     * Super Admin final approval of a self-registered company (UC-5),
     * mirroring DriverController::approve().
     */
    public function approve(Company $company)
    {
        $company->update([
            'approval_status' => 'approved',
            'rejection_reason' => null,
        ]);
        ActivityLog::record('company.approved', $company, "Approved company '{$company->name}'");

        return response()->json([
            'message' => 'Company approved successfully',
            'company' => $company,
        ], 200);
    }

    /**
     * Super Admin outright rejects a self-registered company.
     */
    public function reject(Request $request, Company $company)
    {
        $validated = $request->validate([
            'reason' => ['nullable', 'string', 'max:255'],
        ]);

        $company->update([
            'approval_status' => 'rejected',
            'rejection_reason' => $validated['reason'] ?? null,
        ]);
        ActivityLog::record(
            'company.rejected',
            $company,
            "Rejected company '{$company->name}'",
            ['reason' => $validated['reason'] ?? null]
        );

        return response()->json([
            'message' => 'Company rejected',
            'company' => $company,
        ], 200);
    }

    /**
     * UC-5 alt flow: return the application to the company so they can
     * complete missing information, instead of an outright rejection.
     * approval_status stays 'pending' — only the message changes, reusing
     * the same rejection_reason column (see the Phase 1 migration note).
     */
    public function returnForCompletion(Request $request, Company $company)
    {
        $validated = $request->validate([
            'message' => ['required', 'string', 'max:500'],
        ]);

        $company->update([
            'approval_status' => 'changes_required',
            'rejection_reason' => $validated['message'],
        ]);

        return response()->json([
            'message' => 'Application returned to the company for changes',
            'company' => $company,
        ], 200);
    }

    /**
     * Company's own fix-up submission (2026-08-19), only reachable while
     * approval_status === 'changes_required' — mirrors
     * DriverController::updateDriverInfo().
     */
    public function updateCompanyInfo(Request $request)
    {
        $company = Company::where('user_id', $request->user()->id)->first();

        if (! $company) {
            return response()->json(['message' => 'Company not found'], 404);
        }

        if ($company->approval_status !== 'changes_required') {
            return response()->json([
                'message' => 'You can only edit your registration while an admin has requested changes',
            ], 409);
        }

        $validated = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'address' => ['sometimes', 'nullable', 'string', 'max:500'],
            'phone' => ['sometimes', 'nullable', 'string', 'max:30'],
        ]);

        $company->update($validated);

        return response()->json([
            'message' => 'Company information updated',
            'company' => $company->fresh(),
        ], 200);
    }

    /**
     * Flips 'changes_required' back to 'pending' — mirrors
     * DriverController::resubmit().
     */
    public function resubmit(Request $request)
    {
        $company = Company::where('user_id', $request->user()->id)->first();

        if (! $company) {
            return response()->json(['message' => 'Company not found'], 404);
        }

        if ($company->approval_status !== 'changes_required') {
            return response()->json([
                'message' => 'Your application is not currently awaiting changes',
            ], 409);
        }

        $company->update(['approval_status' => 'pending']);

        return response()->json([
            'message' => 'Application resubmitted for review',
            'company' => $company->fresh(),
        ], 200);
    }

    /**
     * Admin temporarily suspends a company account for a rules violation
     * (separate from the one-time approval workflow — an already-approved
     * company can still be suspended later).
     */
    public function suspend(Request $request, Company $company)
    {
        $validated = $request->validate([
            'reason' => ['required', 'string', 'max:500'],
        ]);

        $company->update([
            'account_status' => 'suspended',
            'suspension_reason' => $validated['reason'],
        ]);
        ActivityLog::record(
            'company.suspended',
            $company,
            "Suspended company '{$company->name}'",
            ['reason' => $validated['reason']]
        );

        return response()->json([
            'message' => 'Company account suspended',
            'company' => $company,
        ], 200);
    }

    public function activate(Company $company)
    {
        $company->update([
            'account_status' => 'active',
            'suspension_reason' => null,
        ]);
        ActivityLog::record('company.activated', $company, "Re-activated company '{$company->name}'");

        return response()->json([
            'message' => 'Company account re-activated',
            'company' => $company,
        ], 200);
    }
}
