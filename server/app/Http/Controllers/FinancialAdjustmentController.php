<?php

namespace App\Http\Controllers;

use App\Models\ActivityLog;
use App\Models\Company;
use App\Models\Driver;
use App\Models\FinancialTransaction;
use App\Notifications\AppPushNotification;
use App\Services\LedgerService;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/**
 * Manual balance correction, always dual-control: a Finance Admin proposes
 * it (written to the Ledger immediately as status=pending, but NOT applied
 * to the balance), and only a Super Admin approving it actually moves
 * money. Rejecting leaves the balance untouched and the pending row as a
 * permanent, visible record that it was proposed and declined.
 */
class FinancialAdjustmentController extends Controller
{
    /**
     * Finance Admin: every ADJUSTMENT ever proposed (pending, posted, and
     * rejected) — newest first, so Super Admin has one queue to review.
     */
    public function index()
    {
        $adjustments = FinancialTransaction::where('transaction_type', 'ADJUSTMENT')
            ->with(['createdBy', 'approvedBy'])
            ->orderByDesc('created_at')
            ->get();

        return response()->json([
            'message' => 'Adjustments retrieved successfully',
            'adjustments' => $adjustments->map(fn ($t) => $this->present($t)),
        ], 200);
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'account_type' => ['required', 'in:company,driver'],
            'account_id' => ['required', 'integer'],
            'amount' => ['required', 'numeric', 'not_in:0'],
            'reason' => ['required', 'string', 'max:1000'],
        ]);

        $account = $validated['account_type'] === 'company'
            ? Company::find($validated['account_id'])
            : Driver::find($validated['account_id']);

        if (! $account) {
            return response()->json(['message' => ucfirst($validated['account_type']) . ' account not found'], 404);
        }

        $adjustment = app(LedgerService::class)->proposeAdjustment(
            $account,
            (float) $validated['amount'],
            $validated['reason'],
            $request->user()->id,
        );

        ActivityLog::record(
            'finance.adjustment_proposed',
            $adjustment,
            "Proposed a {$validated['amount']} AED adjustment for {$validated['account_type']} #{$validated['account_id']}: {$validated['reason']}",
            ['amount' => $validated['amount'], 'account_type' => $validated['account_type'], 'account_id' => $validated['account_id']]
        );

        $this->notifySuperAdmins($adjustment);

        return response()->json([
            'message' => 'Adjustment proposed — awaiting Super Admin approval',
            'adjustment' => $this->present($adjustment),
        ], 201);
    }

    /**
     * Super Admin only — a Finance Admin proposing AND approving their own
     * correction would defeat the whole point of dual control.
     */
    public function approve(Request $request, FinancialTransaction $adjustment)
    {
        if (! $request->user()->isSuperAdmin()) {
            return response()->json(['message' => 'Only Super Admin can approve a manual adjustment'], 403);
        }

        try {
            $adjustment = app(LedgerService::class)->approveAdjustment($adjustment, $request->user()->id);
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 409);
        }

        ActivityLog::record(
            'finance.adjustment_approved',
            $adjustment,
            "Approved a {$adjustment->amount} AED adjustment for {$adjustment->account_type} #{$adjustment->account_id}",
            ['amount' => $adjustment->amount]
        );

        $this->notifyAccountOwner($adjustment, approved: true);

        return response()->json([
            'message' => 'Adjustment approved and applied',
            'adjustment' => $this->present($adjustment->fresh()),
        ], 200);
    }

    public function reject(Request $request, FinancialTransaction $adjustment)
    {
        if (! $request->user()->isSuperAdmin()) {
            return response()->json(['message' => 'Only Super Admin can reject a manual adjustment'], 403);
        }

        try {
            $adjustment = app(LedgerService::class)->rejectAdjustment($adjustment, $request->user()->id);
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 409);
        }

        ActivityLog::record(
            'finance.adjustment_rejected',
            $adjustment,
            "Rejected a proposed {$adjustment->amount} AED adjustment for {$adjustment->account_type} #{$adjustment->account_id}",
            ['amount' => $adjustment->amount]
        );

        return response()->json([
            'message' => 'Adjustment rejected — balance untouched',
            'adjustment' => $this->present($adjustment->fresh()),
        ], 200);
    }

    private function present(FinancialTransaction $t): array
    {
        return [
            'id' => $t->id,
            'account_type' => $t->account_type,
            'account_id' => $t->account_id,
            'account_name' => $t->account()?->name,
            'amount' => $t->amount,
            'status' => $t->status,
            'description' => $t->description,
            'created_by' => $t->createdBy?->name,
            'approved_by' => $t->approvedBy?->name,
            'approved_at' => $t->approved_at,
            'created_at' => $t->created_at,
        ];
    }

    private function notifySuperAdmins(FinancialTransaction $adjustment): void
    {
        $superAdmins = \App\Models\User::whereIn('type', ['super_admin', 'admin'])->get();

        foreach ($superAdmins as $admin) {
            $admin->notify(new AppPushNotification(
                'adjustment_proposed',
                'Manual balance adjustment pending approval',
                sprintf('A %s AED adjustment was proposed for %s #%d.', $adjustment->amount, $adjustment->account_type, $adjustment->account_id),
                ['adjustment_id' => $adjustment->id],
            ));
        }
    }

    private function notifyAccountOwner(FinancialTransaction $adjustment, bool $approved): void
    {
        $account = $adjustment->account();
        $user = $account?->user;

        $user?->notify(new AppPushNotification(
            'adjustment_resolved',
            $approved ? 'Balance adjustment applied' : 'Balance adjustment declined',
            sprintf('A manual adjustment of %s AED was %s.', $adjustment->amount, $approved ? 'approved and applied to your balance' : 'declined'),
            ['adjustment_id' => $adjustment->id],
        ));
    }
}
