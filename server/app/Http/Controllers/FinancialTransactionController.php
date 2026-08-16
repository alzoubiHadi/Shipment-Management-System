<?php

namespace App\Http\Controllers;

use App\Models\Company;
use App\Models\Driver;
use App\Models\FinancialTransaction;
use Illuminate\Http\Request;

/**
 * Read-only access to the Ledger. Never write here — see LedgerService for
 * the only sanctioned way a FinancialTransaction gets created.
 */
class FinancialTransactionController extends Controller
{
    /**
     * The logged-in company's or driver's own statement — every posted
     * transaction, newest first. Pending/rejected ADJUSTMENT proposals are
     * intentionally excluded here (those are an internal Finance Admin /
     * Super Admin workflow, not something to surface as a real line item
     * on the account holder's own statement until they're posted).
     */
    public function myTransactions(Request $request)
    {
        $user = $request->user();

        if ($user->type === 'company') {
            $company = Company::where('user_id', $user->id)->first();
            if (! $company) {
                return response()->json(['message' => 'Company not found'], 404);
            }
            $accountType = 'company';
            $accountId = $company->id;
        } elseif ($user->type === 'driver') {
            $driver = Driver::where('user_id', $user->id)->first();
            if (! $driver) {
                return response()->json(['message' => 'Driver not found'], 404);
            }
            $accountType = 'driver';
            $accountId = $driver->id;
        } else {
            return response()->json(['message' => 'This account has no financial statement'], 422);
        }

        $transactions = FinancialTransaction::where('account_type', $accountType)
            ->where('account_id', $accountId)
            ->where('status', FinancialTransaction::STATUS_POSTED)
            ->orderByDesc('created_at')
            ->get();

        return response()->json([
            'message' => 'Transactions retrieved successfully',
            'transactions' => $transactions,
        ], 200);
    }

    /**
     * Finance Admin: any account's statement, e.g. from a company/driver
     * detail screen — ?account_type=company&account_id=5
     */
    public function index(Request $request)
    {
        $validated = $request->validate([
            'account_type' => ['required', 'in:company,driver'],
            'account_id' => ['required', 'integer'],
        ]);

        $transactions = FinancialTransaction::where('account_type', $validated['account_type'])
            ->where('account_id', $validated['account_id'])
            ->orderByDesc('created_at')
            ->get();

        return response()->json([
            'message' => 'Transactions retrieved successfully',
            'transactions' => $transactions,
        ], 200);
    }
}
