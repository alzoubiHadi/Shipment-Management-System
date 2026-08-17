<?php

namespace App\Http\Controllers;

use App\Models\ActivityLog;
use App\Models\Company;
use App\Models\PaymentOrder;
use App\Notifications\AppPushNotification;
use App\Services\LedgerService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

/**
 * UC-28/UC-29: company top-up requests, reviewed by Finance Admin. Only
 * approve() ever touches companies.balance — submitting or rejecting never
 * does.
 */
class PaymentOrderController extends Controller
{
    /**
     * Company: submit a top-up request with a bank-transfer receipt.
     */
    public function create(Request $request)
    {
        $company = Company::where('user_id', $request->user()->id)->first();

        if (! $company) {
            return response()->json(['message' => 'Company not found'], 404);
        }

        $validated = $request->validate([
            'amount' => ['required', 'numeric', 'min:0.01'],
            'receipt_file' => ['required', 'file', 'max:10240'],
        ]);

        // Privacy fix (2026-08-25, financial audit): this is a bank-transfer
        // receipt — potentially a bank name, account/reference number, the
        // company's legal name. It used to go on the 'public' disk, meaning
        // anyone with the URL (predictable folder + generated filename)
        // could view it with no authentication at all. Now stored on the
        // private 'local' disk (see config/filesystems.php) and only
        // reachable via downloadReceipt() below, which checks the caller is
        // either this order's own company or holds the 'finance' permission.
        $validated['receipt_file_path'] = $request->file('receipt_file')->store('payment_receipts', 'local');
        $validated['company_id'] = $company->id;
        unset($validated['receipt_file']);

        $order = PaymentOrder::create($validated);

        $this->notifyFinanceAdmins($order);

        return response()->json([
            'message' => 'Payment order submitted — awaiting Finance Admin review',
            'order' => $order,
        ], 201);
    }

    /**
     * Company: their own payment order history.
     */
    public function myOrders(Request $request)
    {
        $company = Company::where('user_id', $request->user()->id)->first();

        if (! $company) {
            return response()->json(['message' => 'Company not found'], 404);
        }

        return response()->json([
            'message' => 'Payment orders retrieved successfully',
            'orders' => PaymentOrder::where('company_id', $company->id)
                ->orderByDesc('created_at')
                ->get(),
        ], 200);
    }

    /**
     * Finance Admin: every payment order, newest first.
     */
    public function index()
    {
        return response()->json([
            'message' => 'Payment orders retrieved successfully',
            'orders' => PaymentOrder::with('company')->orderByDesc('created_at')->get(),
        ], 200);
    }

    /**
     * Finance Admin: approve — the ONLY action that credits the company's
     * balance.
     */
    public function approve(Request $request, PaymentOrder $order)
    {
        // Atomicity fix (2026-08-25, financial audit): status update and
        // the Ledger credit used to be two separate, non-transactional
        // steps — an exception between them left the order marked
        // 'approved' with the company's balance never actually raised, and
        // two concurrent approve() calls could both read status=='pending'
        // and both credit the company twice for one top-up. Fix: lock the
        // PaymentOrder row first, re-check status only once that lock is
        // held, and do the status flip + Ledger credit inside the same
        // transaction as that lock.
        try {
            DB::transaction(function () use ($order, $request) {
                $lockedOrder = PaymentOrder::where('id', $order->id)->lockForUpdate()->firstOrFail();

                if ($lockedOrder->status !== 'pending') {
                    throw new \RuntimeException('This payment order has already been reviewed');
                }

                $lockedOrder->update([
                    'status' => 'approved',
                    'reviewed_by_user_id' => $request->user()->id,
                    'reviewed_at' => now(),
                ]);

                // LedgerService locks the company row and writes the
                // FinancialTransaction + balance update atomically, inside
                // this same outer transaction.
                app(LedgerService::class)->record(
                    $lockedOrder->company,
                    'COMPANY_DEPOSIT',
                    (float) $lockedOrder->amount,
                    $lockedOrder,
                    "Approved top-up of {$lockedOrder->amount} AED",
                );
            });
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 409);
        }

        $order = $order->fresh();
        $company = $order->company;

        ActivityLog::record(
            'payment_order.approved',
            $order,
            "Approved top-up of {$order->amount} AED for company '{$company->name}'",
            ['amount' => $order->amount, 'company_id' => $company->id]
        );

        $company->user?->notify(new AppPushNotification(
            'payment_order_approved',
            'Balance top-up approved',
            sprintf('Your top-up of %s AED has been approved and added to your balance.', $order->amount),
            ['payment_order_id' => $order->id],
        ));

        return response()->json([
            'message' => 'Payment order approved — company balance updated',
            'order' => $order,
        ], 200);
    }

    /**
     * Finance Admin: reject with a reason — balance untouched.
     */
    public function reject(Request $request, PaymentOrder $order)
    {
        if ($order->status !== 'pending') {
            return response()->json(['message' => 'This payment order has already been reviewed'], 409);
        }

        $validated = $request->validate([
            'rejection_reason' => ['required', 'string'],
        ]);

        $order->update([
            'status' => 'rejected',
            'reviewed_by_user_id' => $request->user()->id,
            'reviewed_at' => now(),
            'rejection_reason' => $validated['rejection_reason'],
        ]);
        ActivityLog::record(
            'payment_order.rejected',
            $order,
            "Rejected top-up of {$order->amount} AED for company '{$order->company->name}'",
            ['reason' => $validated['rejection_reason']]
        );

        $order->company->user?->notify(new AppPushNotification(
            'payment_order_rejected',
            'Balance top-up rejected',
            sprintf('Your top-up request of %s AED was rejected: %s', $order->amount, $validated['rejection_reason']),
            ['payment_order_id' => $order->id],
        ));

        return response()->json([
            'message' => 'Payment order rejected',
            'order' => $order->fresh(),
        ], 200);
    }

    /**
     * Streams the bank-transfer receipt from the private 'local' disk —
     * only the company that submitted it, or a Finance Admin/permission
     * holder, may view it. See the privacy note on create() above.
     */
    public function downloadReceipt(Request $request, PaymentOrder $order)
    {
        $company = Company::where('user_id', $request->user()->id)->first();
        $isOwner = $company && $order->company_id === $company->id;

        if (! $isOwner && ! $request->user()->hasPermission('finance')) {
            return response()->json(['message' => 'You are not authorized to view this receipt'], 403);
        }

        if (! $order->receipt_file_path || ! Storage::disk('local')->exists($order->receipt_file_path)) {
            return response()->json(['message' => 'Receipt not found'], 404);
        }

        return Storage::disk('local')->response($order->receipt_file_path);
    }

    private function notifyFinanceAdmins(PaymentOrder $order): void
    {
        $financeAdmins = \App\Models\User::where('type', 'super_admin')
            ->orWhere('type', 'admin')
            ->orWhere(function ($q) {
                $q->where('type', 'sub_admin')->whereHas('permissions', fn ($p) => $p->where('key', 'finance'));
            })
            ->get();

        foreach ($financeAdmins as $admin) {
            $admin->notify(new AppPushNotification(
                'payment_order_submitted',
                'New top-up request',
                sprintf('A company submitted a top-up request of %s AED.', $order->amount),
                ['payment_order_id' => $order->id],
            ));
        }
    }
}
