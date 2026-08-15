<?php

namespace App\Http\Controllers;

use App\Models\Company;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;


class CompanyController extends Controller
{
    //
    public function update_profile(Request $request, Company $company)
    {
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
     * Super Admin final approval of a self-registered company (UC-5),
     * mirroring DriverController::approve().
     */
    public function approve(Company $company)
    {
        $company->update([
            'approval_status' => 'approved',
            'rejection_reason' => null,
        ]);

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
            'approval_status' => 'pending',
            'rejection_reason' => $validated['message'],
        ]);

        return response()->json([
            'message' => 'Application returned to the company for completion',
            'company' => $company,
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

        return response()->json([
            'message' => 'Company account re-activated',
            'company' => $company,
        ], 200);
    }
}
