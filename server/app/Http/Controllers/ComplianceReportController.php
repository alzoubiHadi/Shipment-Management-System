<?php

namespace App\Http\Controllers;

use App\Models\ComplianceReport;
use App\Models\Driver;
use App\Models\User;
use App\Notifications\AppPushNotification;
use Illuminate\Http\Request;

/**
 * UC-25 (report a driver compliance/safety violation) and UC-26 (driver
 * appeals a report that was upheld against them). See the
 * create_compliance_reports_table migration for the full design notes:
 * traffic/cargo_damage/complaint/other escalate through the normal
 * open -> under_review -> upheld/dismissed flow with a Super Admin picking
 * the resulting action; criminal/smuggling/forgery freeze the driver
 * (compliance_status = 'suspended') immediately, before any review, since
 * those categories are too serious to leave a driver active in the
 * meantime.
 */
class ComplianceReportController extends Controller
{
    /**
     * A company or any admin can file a report against a driver.
     */
    public function store(Request $request, Driver $driver)
    {
        $user = $request->user();

        if (! in_array($user->type, ['company', 'super_admin', 'admin', 'sub_admin'], true)) {
            return response()->json(['message' => 'You are not authorized to file a compliance report'], 403);
        }

        $validated = $request->validate([
            'category' => ['required', 'string', 'in:' . implode(',', ComplianceReport::CATEGORIES)],
            'description' => ['required', 'string', 'max:2000'],
            'evidence_file' => ['nullable', 'file', 'max:10240'],
        ]);

        $evidencePath = $request->hasFile('evidence_file')
            ? $request->file('evidence_file')->store('compliance_evidence', 'public')
            : null;

        $isImmediateFreeze = in_array($validated['category'], ComplianceReport::IMMEDIATE_FREEZE_CATEGORIES, true);

        $report = ComplianceReport::create([
            'driver_id' => $driver->id,
            'reported_by_user_id' => $user->id,
            'category' => $validated['category'],
            'description' => $validated['description'],
            'evidence_file_path' => $evidencePath,
            'status' => $isImmediateFreeze ? 'under_review' : 'open',
        ]);

        if ($isImmediateFreeze) {
            $driver->update(['compliance_status' => 'suspended']);
        }

        $this->notifySuperAdmins($report, $driver);

        return response()->json([
            'message' => $isImmediateFreeze
                ? 'Report submitted — this driver has been frozen pending Super Admin review'
                : 'Report submitted for review',
            'report' => $report,
        ], 201);
    }

    /**
     * Super Admin: every report, optionally filtered by status
     * (?status=open|under_review|upheld|dismissed).
     */
    public function index(Request $request)
    {
        $query = ComplianceReport::with(['driver', 'reportedBy', 'resolvedBy'])->latest();

        if ($request->filled('status')) {
            $query->where('status', $request->string('status'));
        }

        return response()->json([
            'message' => 'Compliance reports retrieved successfully',
            'reports' => $query->get(),
        ], 200);
    }

    /**
     * Driver app: their own report history, so they know what's open
     * against them and whether they can appeal.
     */
    public function myReports(Request $request)
    {
        $driver = Driver::where('user_id', $request->user()->id)->first();

        if (! $driver) {
            return response()->json(['message' => 'Driver not found'], 404);
        }

        return response()->json([
            'message' => 'Compliance reports retrieved successfully',
            'reports' => $driver->complianceReports()->latest()->get(),
        ], 200);
    }

    /**
     * Super Admin decision on an open/under-review report: dismiss it
     * (no action, driver stays as-is — and if it was an immediate-freeze
     * category, this is what lifts the freeze), or uphold it with a
     * resulting_action that updates the driver's compliance_status.
     */
    public function resolve(Request $request, ComplianceReport $report)
    {
        if (! $request->user()->isSuperAdmin()) {
            return response()->json(['message' => 'Only the Super Admin can resolve compliance reports'], 403);
        }

        if (! in_array($report->status, ['open', 'under_review'], true)) {
            return response()->json(['message' => 'This report has already been resolved'], 409);
        }

        $validated = $request->validate([
            'decision' => ['required', 'string', 'in:dismiss,uphold'],
            'resulting_action' => ['required_if:decision,uphold', 'nullable', 'string', 'in:warning,suspension,ban'],
        ]);

        $driver = $report->driver;

        if ($validated['decision'] === 'dismiss') {
            $report->update([
                'status' => 'dismissed',
                'resulting_action' => 'none',
                'resolved_by_user_id' => $request->user()->id,
                'resolved_at' => now(),
            ]);

            // Lifts an immediate-freeze suspension if nothing else is
            // currently holding this driver back.
            if ($driver && $driver->compliance_status === 'suspended') {
                $driver->update(['compliance_status' => 'active']);
            }
        } else {
            $action = $validated['resulting_action'];

            $report->update([
                'status' => 'upheld',
                'resulting_action' => $action,
                'resolved_by_user_id' => $request->user()->id,
                'resolved_at' => now(),
            ]);

            if ($driver) {
                $driver->update([
                    'compliance_status' => match ($action) {
                        'warning' => 'warning',
                        'suspension' => 'suspended',
                        'ban' => 'banned',
                        default => $driver->compliance_status,
                    },
                ]);

                $driver->user?->notify(new AppPushNotification(
                    'compliance_report_upheld',
                    'Compliance report upheld',
                    sprintf('A compliance report against you was upheld: %s. You may appeal this decision.', $action),
                    ['report_id' => $report->id],
                ));
            }
        }

        return response()->json([
            'message' => 'Report resolved',
            'report' => $report->fresh(),
        ], 200);
    }

    /**
     * UC-26: the driver appeals a report that was upheld against them.
     * Only one active appeal per report — appeal_status must still be
     * 'none' (i.e. they haven't already appealed).
     */
    public function appeal(Request $request, ComplianceReport $report)
    {
        $driver = Driver::where('user_id', $request->user()->id)->first();

        if (! $driver || $report->driver_id !== $driver->id) {
            return response()->json(['message' => 'This is not your report'], 403);
        }

        if ($report->status !== 'upheld') {
            return response()->json(['message' => 'Only an upheld report can be appealed'], 409);
        }

        if ($report->appeal_status !== 'none') {
            return response()->json(['message' => 'You have already appealed this report'], 409);
        }

        $validated = $request->validate([
            'appeal_text' => ['required', 'string', 'max:2000'],
        ]);

        $report->update([
            'appeal_text' => $validated['appeal_text'],
            'appeal_status' => 'pending',
        ]);

        $this->notifySuperAdmins($report, $driver, appeal: true);

        return response()->json([
            'message' => 'Appeal submitted — a Super Admin will review it',
            'report' => $report->fresh(),
        ], 200);
    }

    /**
     * Super Admin decision on a pending appeal. Accepting reverts the
     * driver's compliance_status back to 'active' — the report itself
     * stays 'upheld' in history, but its effect is undone.
     */
    public function resolveAppeal(Request $request, ComplianceReport $report)
    {
        if (! $request->user()->isSuperAdmin()) {
            return response()->json(['message' => 'Only the Super Admin can resolve appeals'], 403);
        }

        if ($report->appeal_status !== 'pending') {
            return response()->json(['message' => 'This report has no pending appeal'], 409);
        }

        $validated = $request->validate([
            'decision' => ['required', 'string', 'in:accept,reject'],
        ]);

        $accepted = $validated['decision'] === 'accept';

        $report->update([
            'appeal_status' => $accepted ? 'accepted' : 'rejected',
        ]);

        $driver = $report->driver;

        if ($accepted && $driver) {
            $driver->update(['compliance_status' => 'active']);
        }

        $driver?->user?->notify(new AppPushNotification(
            'compliance_appeal_resolved',
            $accepted ? 'Your appeal was accepted' : 'Your appeal was rejected',
            $accepted
                ? 'Your compliance appeal was accepted — the decision against you has been reversed.'
                : 'Your compliance appeal was reviewed and rejected. The original decision stands.',
            ['report_id' => $report->id],
        ));

        return response()->json([
            'message' => 'Appeal resolved',
            'report' => $report->fresh(),
        ], 200);
    }

    private function notifySuperAdmins(ComplianceReport $report, Driver $driver, bool $appeal = false): void
    {
        $superAdmins = User::where('type', 'super_admin')->orWhere('type', 'admin')->get();

        foreach ($superAdmins as $admin) {
            $admin->notify(new AppPushNotification(
                $appeal ? 'compliance_appeal_submitted' : 'compliance_report_submitted',
                $appeal ? 'Driver appeal submitted' : 'New compliance report',
                $appeal
                    ? sprintf('%s appealed a compliance decision.', $driver->name)
                    : sprintf('A %s report was filed against driver %s.', $report->category, $driver->name),
                ['report_id' => $report->id],
            ));
        }
    }
}
