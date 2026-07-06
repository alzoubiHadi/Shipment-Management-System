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
}
