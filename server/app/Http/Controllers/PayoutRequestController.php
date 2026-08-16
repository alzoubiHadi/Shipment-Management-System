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

        if ($driver->hasPendingPayout()) {
            return response()->json([
                'message' => 'You already have a payout request in progress',
            ], 409);
        }

        $validated = $request->validate([
            'amount' => ['required', 'numeric', 'min:0.01'],
        ]);

        if ((float) $validated['amount'] > (float) $driver->balance) {
            return response()->json([
                'message' => 'Requested amount exceeds your current balance',
            ], 422);
        }

        $payout = PayoutRequest::create([
            'driver_id' => $driver->id,
            'amount' => $validated['amount'],
            'status' => 'pending',
        ]);

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

        $payout->update([
            'transfer_receipt_file_path' => $request->file('transfer_receipt_file')->store('payout_receipts', 'public'),
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

        if ($payout->status !== 'paid') {
            return response()->json(['message' => 'This payout is not awaiting your confirmation'], 409);
        }

        DB::transaction(function () use ($payout, $driver) {
            $driver = Driver::lockForUpdate()->findOrFail($driver->id);
            app(LedgerService::class)->record(
                $driver,
                'DRIVER_PAYOUT',
                -(float) $payout->amount,
                $payout,
                "Payout #{$payout->id} confirmed received",
            );

            $payout->update([
                'status' => 'confirmed',
                'confirmed_at' => now(),
            ]);
        });

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

        if ($payout->status !== 'disputed') {
            return response()->json(['message' => 'This payout is not currently disputed'], 409);
        }

        $validated = $request->validate([
            'resolution' => ['required', 'in:confirm,retry'],
        ]);

        DB::transaction(function () use ($payout, $validated) {
            if ($validated['resolution'] === 'confirm') {
                $driver = Driver::lockForUpdate()->findOrFail($payout->driver_id);
                app(LedgerService::class)->record(
                    $driver,
                    'DRIVER_PAYOUT',
                    -(float) $payout->amount,
                    $payout,
                    "Payout #{$payout->id} confirmed via dispute resolution",
                );

                $payout->update(['status' => 'confirmed', 'confirmed_at' => now()]);
            } else {
                $payout->update(['status' => 'pending']);
            }
        });
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
