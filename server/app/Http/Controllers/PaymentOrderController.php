<?php

namespace App\Http\Controllers;

use App\Models\ActivityLog;
use App\Models\Company;
use App\Models\PaymentOrder;
use App\Notifications\AppPushNotification;
use App\Services\LedgerService;
use Illuminate\Http\Request;

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

        $validated['receipt_file_path'] = $request->file('receipt_file')->store('payment_receipts', 'public');
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
        if ($order->status !== 'pending') {
            return response()->json(['message' => 'This payment order has already been reviewed'], 409);
        }

        $order->update([
            'status' => 'approved',
            'reviewed_by_user_id' => $request->user()->id,
            'reviewed_at' => now(),
        ]);

        $company = $order->company;
        // LedgerService locks the row and writes the FinancialTransaction +
        // balance update atomically — this used to be a bare increment()
        // with no lock and no ledger row at all.
        app(LedgerService::class)->record(
            $company,
            'COMPANY_DEPOSIT',
            (float) $order->amount,
            $order,
            "Approved top-up of {$order->amount} AED",
        );
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
            'order' => $order->fresh(),
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
