<?php

namespace App\Http\Controllers;

use App\Models\ActivityLog;
use Illuminate\Http\Request;

/**
 * NFR (Security): read-only viewer for the audit trail. Super Admin only —
 * this is intentionally not exposed via the composable permission system
 * (permission:*) since the audit log itself is part of how misuse of those
 * very permissions would be caught.
 */
class ActivityLogController extends Controller
{
    public function index(Request $request)
    {
        if (! $request->user()->isSuperAdmin()) {
            return response()->json(['message' => 'Only the Super Admin can view the audit log'], 403);
        }

        $query = ActivityLog::orderByDesc('created_at');

        if ($request->filled('action')) {
            $query->where('action', 'like', $request->string('action') . '%');
        }
        if ($request->filled('subject_type')) {
            $query->where('subject_type', $request->string('subject_type'));
        }

        return response()->json([
            'message' => 'Activity log retrieved successfully',
            'logs' => $query->limit(500)->get(),
        ], 200);
    }
}
