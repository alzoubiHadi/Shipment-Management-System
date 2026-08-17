<?php

namespace App\Http\Controllers;

use App\Models\ActivityLog;
use App\Models\Driver;
use App\Models\PayoutRequest;
use App\Models\User;
use App\Notifications\AppPushNotification;
use App\Services\LedgerService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

/**
 * UC-30/31/32: driver withdrawal requests. No payment gateway — Finance
 * Admin transfers manually outside the app and attaches a receipt
 * (markPaid), and the driver's own confirmation (confirmReceipt) is the
 * ONLY thing that ever decrements drivers.balance or lifts the "no new
 * jobs while a payout is pending" lock (Driver::hasPendingPayout()).
 */
class PayoutRequestController extends Controller
{
    /**
     * Driver: request a withdrawal. Blocked while a previous request is
     * still mid-flight (UC-30 pre-condition), and can never exceed the
     * driver's current balance.
     */
    public function create(Request $request)
    {
        $driver = Driver::where('user_id', $request->user()->id)->first();

        if (! $driver) {
            return response()->json(['message' => 'Driver not found'], 404);
        }

        $validated = $request->validate([
            'amount' => ['required', 'numeric', 'min:0.01'],
        ]);

        // Concurrency fix (2026-08-25, financial audit): hasPendingPayout()
        // and the balance check used to run against an unlocked $driver
        // before any transaction opened. Two payout requests fired close
        // together could both see "no pending payout" and "amount <=
        // balance" and both get created — Finance Admin could then
        // transfer BOTH amounts manually outside the app even though the
        // driver only ever had one balance to cover them. Fix: lock the
        // driver row first and re-run both checks only once that lock is
        // held; a second concurrent request now serializes behind the
        // first and sees the just-created pending payout.
        try {
            $payout = DB::transaction(function () use ($driver, $validated) {
                $lockedDriver = Driver::where('id', $driver->id)->lockForUpdate()->firstOrFail();

                if ($lockedDriver->hasPendingPayout()) {
                    throw new \RuntimeException('You already have a payout request in progress');
                }

                if ((float) $validated['amount'] > (float) $lockedDriver->balance) {
                    throw new \RuntimeException('Requested amount exceeds your current balance');
                }

                return PayoutRequest::create([
                    'driver_id' => $lockedDriver->id,
                    'amount' => $validated['amount'],
                    'status' => 'pending',
                ]);
            });
        } catch (\RuntimeException $e) {
            $status = $e->getMessage() === 'You already have a payout request in progress' ? 409 : 422;
            return response()->json(['message' => $e->getMessage()], $status);
        }

        $this->notifyFinanceAdmins($payout);

        return response()->json([
            'message' => 'Payout requested — awaiting Finance Admin review',
            'payout' => $payout,
        ], 201);
    }

    /**
     * Driver: cancel their own request before Finance Admin has acted.
     */
    public function cancel(Request $request, PayoutRequest $payout)
    {
        $driver = Driver::where('user_id', $request->user()->id)->first();

        if (! $driver || $payout->driver_id !== $driver->id) {
            return response()->json(['message' => 'This is not your payout request'], 403);
        }

        if ($payout->status !== 'pending') {
            return response()->json(['message' => 'Only a pending request can be cancelled'], 409);
        }

        $payout->update(['status' => 'rejected', 'rejection_reason' => 'Cancelled by driver']);

        return response()->json([
            'message' => 'Payout request cancelled',
            'payout' => $payout->fresh(),
        ], 200);
    }

    /**
     * Driver: their own payout history.
     */
    public function myRequests(Request $request)
    {
        $driver = Driver::where('user_id', $request->user()->id)->first();

        if (! $driver) {
            return response()->json(['message' => 'Driver not found'], 404);
        }

        return response()->json([
            'message' => 'Payout requests retrieved successfully',
            'payouts' => $driver->payoutRequests()->orderByDesc('created_at')->get(),
        ], 200);
    }

    /**
     * Finance Admin: every payout request, newest first.
     */
    public function index()
    {
        return response()->json([
            'message' => 'Payout requests retrieved successfully',
            'payouts' => PayoutRequest::with('driver')->orderByDesc('created_at')->get(),
        ], 200);
    }

    /**
     * Finance Admin (UC-31): records that the transfer was made outside
     * the app and attaches proof — does NOT touch the driver's balance yet.
     */
    public function markPaid(Request $request, PayoutRequest $payout)
    {
        if ($payout->status !== 'pending') {
            return response()->json(['message' => 'This payout request is not pending'], 409);
        }

        $validated = $request->validate([
            'transfer_receipt_file' => ['required', 'file', 'max:10240'],
        ]);

        // Privacy fix (2026-08-25, financial audit): same issue and fix as
        // PaymentOrderController::create()'s receipt — this proof of an
        // outgoing bank transfer moves to the private 'local' disk, only
        // reachable via downloadReceipt() below (this driver, or a Finance
        // Admin/permission holder).
        $payout->update([
            'transfer_receipt_file_path' => $request->file('transfer_receipt_file')->store('payout_receipts', 'local'),
            'paid_by_user_id' => $request->user()->id,
            'paid_at' => now(),
            'status' => 'paid',
        ]);
        ActivityLog::record(
            'payout.marked_paid',
            $payout,
            "Recorded transfer of {$payout->amount} AED for driver '{$payout->driver->name}'",
            ['amount' => $payout->amount]
        );

        $payout->driver->user?->notify(new AppPushNotification(
            'payout_paid',
            'Payout sent — please confirm receipt',
            sprintf('%s AED was transferred to you. Please review and confirm receipt in the app.', $payout->amount),
            ['payout_request_id' => $payout->id],
        ));

        return response()->json([
            'message' => 'Transfer recorded — awaiting driver confirmation',
            'payout' => $payout->fresh(),
        ], 200);
    }

    /**
     * Finance Admin: reject a still-pending request with a reason.
     */
    public function reject(Request $request, PayoutRequest $payout)
    {
        if ($payout->status !== 'pending') {
            return response()->json(['message' => 'Only a pending request can be rejected'], 409);
        }

        $validated = $request->validate([
            'rejection_reason' => ['required', 'string'],
        ]);

        $payout->update([
            'status' => 'rejected',
            'rejection_reason' => $validated['rejection_reason'],
        ]);
        ActivityLog::record(
            'payout.rejected',
            $payout,
            "Rejected payout of {$payout->amount} AED for driver '{$payout->driver->name}'",
            ['reason' => $validated['rejection_reason']]
        );

        $payout->driver->user?->notify(new AppPushNotification(
            'payout_rejected',
            'Payout request rejected',
            sprintf('Your payout request of %s AED was rejected: %s', $payout->amount, $validated['rejection_reason']),
            ['payout_request_id' => $payout->id],
        ));

        return response()->json([
            'message' => 'Payout request rejected',
            'payout' => $payout->fresh(),
        ], 200);
    }

    /**
     * Driver (UC-32): confirms the transfer actually arrived. This is the
     * ONLY action that decrements drivers.balance and lifts the
     * new-job-acceptance lock.
     */
    public function confirmReceipt(Request $request, PayoutRequest $payout)
    {
        $driver = Driver::where('user_id', $request->user()->id)->first();

        if (! $driver || $payout->driver_id !== $driver->id) {
            return response()->json(['message' => 'This is not your payout request'], 403);
        }

        // Concurrency fix (2026-08-25, financial audit): the status !=
        // 'paid' check used to run BEFORE the transaction opened. Two
        // near-simultaneous confirm taps could both read status=='paid',
        // both then pass, and both post a DRIVER_PAYOUT debit for the same
        // payout — double-decrementing the driver's balance for one real
        // transfer. Fix: lock the PayoutRequest row FIRST, re-check its
        // status only once that lock is held, THEN lock the driver and
        // record the ledger entry. The second concurrent call now
        // serializes behind the first and sees status=='confirmed' already.
        try {
            DB::transaction(function () use ($payout, $driver) {
                $lockedPayout = PayoutRequest::where('id', $payout->id)->lockForUpdate()->firstOrFail();

                if ($lockedPayout->status !== 'paid') {
                    throw new \RuntimeException('This payout is not awaiting your confirmation');
                }

                $lockedDriver = Driver::lockForUpdate()->findOrFail($driver->id);
                app(LedgerService::class)->record(
                    $lockedDriver,
                    'DRIVER_PAYOUT',
                    -(float) $lockedPayout->amount,
                    $lockedPayout,
                    "Payout #{$lockedPayout->id} confirmed received",
                );

                $lockedPayout->update([
                    'status' => 'confirmed',
                    'confirmed_at' => now(),
                ]);
            });
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 409);
        }

        ActivityLog::record(
            'payout.confirmed',
            $payout,
            "Driver '{$driver->name}' confirmed receipt of payout #{$payout->id} ({$payout->amount} AED)",
            ['amount' => $payout->amount]
        );

        return response()->json([
            'message' => 'Receipt confirmed — your balance has been updated',
            'payout' => $payout->fresh(),
        ], 200);
    }

    /**
     * Driver (UC-32 alternative flow): reports the money never actually
     * arrived — routes to CRM/Super Admin instead of silently sitting
     * there. Balance stays untouched and the new-job lock stays in place
     * until resolveDispute() below settles it.
     */
    public function disputeReceipt(Request $request, PayoutRequest $payout)
    {
        $driver = Driver::where('user_id', $request->user()->id)->first();

        if (! $driver || $payout->driver_id !== $driver->id) {
            return response()->json(['message' => 'This is not your payout request'], 403);
        }

        if ($payout->status !== 'paid') {
            return response()->json(['message' => 'This payout is not awaiting your confirmation'], 409);
        }

        $validated = $request->validate([
            'dispute_reason' => ['required', 'string'],
        ]);

        $payout->update([
            'status' => 'disputed',
            'dispute_reason' => $validated['dispute_reason'],
        ]);

        $this->notifyFinanceAdmins($payout, disputed: true);

        return response()->json([
            'message' => 'Reported — an admin will review this payout',
            'payout' => $payout->fresh(),
        ], 200);
    }

    /**
     * Super Admin / CRM/Finance Admin: settles a disputed payout.
     * 'confirm' means the money did arrive after all (same effect as the
     * driver confirming themselves); 'retry' reopens it as 'pending' so
     * Finance Admin can attempt the transfer again.
     */
    public function resolveDispute(Request $request, PayoutRequest $payout)
    {
        if (! $request->user()->isSuperAdmin() && ! $request->user()->hasPermission('finance')) {
            return response()->json(['message' => 'You are not authorized to resolve payout disputes'], 403);
        }

        $validated = $request->validate([
            'resolution' => ['required', 'in:confirm,retry'],
        ]);

        // Same lock-then-recheck pattern as confirmReceipt() above — closes
        // the identical double-decrement race for the dispute-resolution
        // path (two admins resolving the same disputed payout at once).
        try {
            DB::transaction(function () use ($payout, $validated) {
                $lockedPayout = PayoutRequest::where('id', $payout->id)->lockForUpdate()->firstOrFail();

                if ($lockedPayout->status !== 'disputed') {
                    throw new \RuntimeException('This payout is not currently disputed');
                }

                if ($validated['resolution'] === 'confirm') {
                    $driver = Driver::lockForUpdate()->findOrFail($lockedPayout->driver_id);
                    app(LedgerService::class)->record(
                        $driver,
                        'DRIVER_PAYOUT',
                        -(float) $lockedPayout->amount,
                        $lockedPayout,
                        "Payout #{$lockedPayout->id} confirmed via dispute resolution",
                    );

                    $lockedPayout->update(['status' => 'confirmed', 'confirmed_at' => now()]);
                } else {
                    $lockedPayout->update(['status' => 'pending']);
                }
            });
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 409);
        }
        ActivityLog::record(
            'payout.dispute_resolved',
            $payout,
            "Resolved payout dispute for driver '{$payout->driver->name}' as '{$validated['resolution']}'",
            ['resolution' => $validated['resolution']]
        );

        $payout->driver->user?->notify(new AppPushNotification(
            'payout_dispute_resolved',
            'Payout dispute resolved',
            $validated['resolution'] === 'confirm'
                ? sprintf('Your dispute for %s AED was resolved — balance updated.', $payout->amount)
                : 'Your dispute was reviewed — Finance Admin will retry the transfer.',
            ['payout_request_id' => $payout->id],
        ));

        return response()->json([
            'message' => 'Dispute resolved',
            'payout' => $payout->fresh(),
        ], 200);
    }

    /**
     * Streams the transfer receipt from the private 'local' disk — only
     * this payout's own driver, or a Finance Admin/permission holder, may
     * view it. See the privacy note on markPaid() above.
     */
    public function downloadReceipt(Request $request, PayoutRequest $payout)
    {
        $driver = Driver::where('user_id', $request->user()->id)->first();
        $isOwner = $driver && $payout->driver_id === $driver->id;

        if (! $isOwner && ! $request->user()->hasPermission('finance')) {
            return response()->json(['message' => 'You are not authorized to view this receipt'], 403);
        }

        if (! $payout->transfer_receipt_file_path || ! Storage::disk('local')->exists($payout->transfer_receipt_file_path)) {
            return response()->json(['message' => 'Receipt not found'], 404);
        }

        return Storage::disk('local')->response($payout->transfer_receipt_file_path);
    }

    private function notifyFinanceAdmins(PayoutRequest $payout, bool $disputed = false): void
    {
        $financeAdmins = User::where('type', 'super_admin')
            ->orWhere('type', 'admin')
            ->orWhere(function ($q) {
                $q->where('type', 'sub_admin')->whereHas('permissions', fn ($p) => $p->where('key', 'finance'));
            })
            ->get();

        foreach ($financeAdmins as $admin) {
            $admin->notify(new AppPushNotification(
                $disputed ? 'payout_disputed' : 'payout_requested',
                $disputed ? 'Payout dispute needs review' : 'New payout request',
                $disputed
                    ? sprintf('Driver disputed payout #%d: %s', $payout->id, $payout->dispute_reason)
                    : sprintf('A driver requested a payout of %s AED.', $payout->amount),
                ['payout_request_id' => $payout->id],
            ));
        }
    }
}
