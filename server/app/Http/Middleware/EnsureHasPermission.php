<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Route-level guard for the composable admin permission system (UC-6).
 * Usage: Route::middleware('permission:finance')->group(...).
 * Super Admin (User::isSuperAdmin()) always passes, regardless of the
 * permission key requested. A sub-admin passes only if they hold that
 * specific permission group — and a single sub-admin account can hold
 * several groups at once, so this can gate different routes with
 * different keys on the very same account.
 */
class EnsureHasPermission
{
    public function handle(Request $request, Closure $next, string $permissionKey): Response
    {
        $user = $request->user();

        if (! $user || ! $user->hasPermission($permissionKey)) {
            return response()->json([
                'message' => "This action requires the '{$permissionKey}' permission.",
            ], 403);
        }

        return $next($request);
    }
}
