<?php

namespace App\Http\Controllers;

use App\Models\ActivityLog;
use App\Models\Permission;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * Super Admin only: creates and manages composable sub-admin accounts
 * (UC-6). A single sub-admin account can hold several permission groups at
 * once (e.g. finance + trainer). Super Admin itself is not represented by
 * any row here — see User::isSuperAdmin().
 */
class AdminController extends Controller
{
    public function permissions()
    {
        return response()->json([
            'message' => 'Permissions retrieved successfully',
            'permissions' => Permission::all(),
        ], 200);
    }

    /**
     * List every sub-admin account with the permission groups they hold.
     */
    public function index()
    {
        $admins = User::where('type', 'sub_admin')
            ->with('permissions')
            ->orderByDesc('created_at')
            ->get();

        return response()->json([
            'message' => 'Sub-admins retrieved successfully',
            'admins' => $admins,
        ], 200);
    }

    /**
     * Create a sub-admin account with a one-time temporary password. The
     * plain-text password is returned ONCE in this response only — it is
     * hashed before storage and can never be retrieved again, so the
     * Super Admin must relay it to the new sub-admin now. must_change_password
     * forces them to set a real password on first login (UC-7).
     */
    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'permissions' => ['required', 'array', 'min:1'],
            'permissions.*' => ['string', 'exists:permissions,key'],
        ]);

        $temporaryPassword = Str::password(12);

        $user = User::create([
            'name' => $validated['name'],
            'email' => $validated['email'],
            'type' => 'sub_admin',
            'password' => Hash::make($temporaryPassword),
            'must_change_password' => true,
            // Admin-created accounts skip the self-registration OTP step —
            // the Super Admin already vouches for this person directly.
            'email_verified_at' => now(),
        ]);

        $permissionIds = Permission::whereIn('key', $validated['permissions'])->pluck('id');
        $user->permissions()->sync($permissionIds);
        ActivityLog::record(
            'admin.sub_admin_created',
            $user,
            "Created sub-admin '{$user->name}' with permissions: " . implode(', ', $validated['permissions']),
            ['permissions' => $validated['permissions']]
        );

        return response()->json([
            'message' => 'Sub-admin created successfully. Share this temporary password with them now — it will not be shown again.',
            'admin' => $user->load('permissions'),
            'temporary_password' => $temporaryPassword,
        ], 201);
    }

    /**
     * Replace the full set of permission groups held by a sub-admin
     * (composable — pass every group they should hold, not just one to add).
     */
    public function updatePermissions(Request $request, User $admin)
    {
        if ($admin->type !== 'sub_admin') {
            return response()->json(['message' => 'This user is not a sub-admin account.'], 422);
        }

        $validated = $request->validate([
            'permissions' => ['required', 'array'],
            'permissions.*' => ['string', 'exists:permissions,key'],
        ]);

        $permissionIds = Permission::whereIn('key', $validated['permissions'])->pluck('id');
        $admin->permissions()->sync($permissionIds);
        ActivityLog::record(
            'admin.permissions_updated',
            $admin,
            "Updated permissions for sub-admin '{$admin->name}' to: " . implode(', ', $validated['permissions']),
            ['permissions' => $validated['permissions']]
        );

        return response()->json([
            'message' => 'Permissions updated successfully',
            'admin' => $admin->load('permissions'),
        ], 200);
    }

    /**
     * Super Admin issues a fresh one-time temporary password for a
     * sub-admin (e.g. they're locked out) — forces must_change_password
     * again on next login.
     */
    public function resetPassword(User $admin)
    {
        if ($admin->type !== 'sub_admin') {
            return response()->json(['message' => 'This user is not a sub-admin account.'], 422);
        }

        $temporaryPassword = Str::password(12);

        $admin->update([
            'password' => Hash::make($temporaryPassword),
            'must_change_password' => true,
        ]);
        ActivityLog::record('admin.password_reset', $admin, "Issued a new temporary password for sub-admin '{$admin->name}'");

        return response()->json([
            'message' => 'Temporary password issued. Share it with the sub-admin now — it will not be shown again.',
            'temporary_password' => $temporaryPassword,
        ], 200);
    }

    public function destroy(User $admin)
    {
        if ($admin->type !== 'sub_admin') {
            return response()->json(['message' => 'This user is not a sub-admin account.'], 422);
        }

        ActivityLog::record('admin.sub_admin_deleted', $admin, "Deleted sub-admin account '{$admin->name}'");
        $admin->delete();

        return response()->json(['message' => 'Sub-admin account deleted successfully'], 200);
    }
}
