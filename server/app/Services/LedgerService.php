<?php

namespace App\Services;

use App\Models\Company;
use App\Models\Driver;
use App\Models\FinancialTransaction;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * The ONLY sanctioned way to change a company's or driver's `balance`
 * column from this point forward. Every call locks the account row, writes
 * one immutable FinancialTransaction, and updates `balance` — all inside a
 * single DB transaction, so the Ledger and the cached balance column can
 * never drift apart.
 *
 * Direct `$company->increment('balance', ...)` / `->decrement(...)` calls
 * anywhere in the codebase after this point are a bug — grep for those
 * before adding new financial code.
 */
class LedgerService
{
    /**
     * Post an already-approved transaction (status=posted) and apply it to
     * the account's balance immediately. $amount is signed: positive
     * credits the account, negative debits it.
     *
     * @param  Company|Driver  $account
     * @param  Model|null  $reference  the ShipmentOffer/Shipment/PaymentOrder/PayoutRequest this entry is about
     */
    public function record(
        Model $account,
        string $type,
        float $amount,
        ?Model $reference = null,
        ?string $description = null,
        ?int $createdByUserId = null,
    ): FinancialTransaction {
        if (! in_array($type, FinancialTransaction::TYPES, true)) {
            throw new RuntimeException("Unknown ledger transaction type: {$type}");
        }

        $accountType = $this->accountTypeFor($account);
        $accountClass = get_class($account);

        return DB::transaction(function () use ($account, $accountClass, $accountType, $type, $amount, $reference, $description, $createdByUserId) {
            /** @var Company|Driver $locked */
            $locked = $accountClass::lockForUpdate()->findOrFail($account->id);

            $balanceBefore = (float) $locked->balance;
            $balanceAfter = $balanceBefore + $amount;

            // Drivers can never go negative — a payout can only ever be for
            // an amount already validated against their available balance,
            // so hitting this means a race condition slipped through.
            if ($accountType === FinancialTransaction::ACCOUNT_DRIVER && $balanceAfter < -0.01) {
                throw new RuntimeException('This would take the driver balance negative — aborting.');
            }

            $transaction = FinancialTransaction::create([
                'account_type' => $accountType,
                'account_id' => $locked->id,
                'transaction_type' => $type,
                'amount' => $amount,
                'currency' => 'AED',
                'balance_before' => $balanceBefore,
                'balance_after' => $balanceAfter,
                'reference_type' => $reference ? class_basename($reference) : null,
                'reference_id' => $reference?->id,
                'status' => FinancialTransaction::STATUS_POSTED,
                'description' => $description,
                'created_by' => $createdByUserId ?? auth()->id(),
                'created_at' => now(),
            ]);

            $locked->update(['balance' => $balanceAfter]);

            return $transaction;
        });
    }

    /**
     * Finance Admin proposes a manual correction — written to the Ledger
     * immediately so it's visible in review queues, but NOT applied to the
     * balance yet (status=pending). See approveAdjustment()/rejectAdjustment().
     */
    public function proposeAdjustment(
        Model $account,
        float $amount,
        string $description,
        int $createdByUserId,
    ): FinancialTransaction {
        $accountType = $this->accountTypeFor($account);
        $balanceBefore = (float) $account->balance;

        return FinancialTransaction::create([
            'account_type' => $accountType,
            'account_id' => $account->id,
            'transaction_type' => 'ADJUSTMENT',
            'amount' => $amount,
            'currency' => 'AED',
            // Provisional preview only — recomputed for real at approval
            // time in case other transactions land on this account first.
            'balance_before' => $balanceBefore,
            'balance_after' => $balanceBefore + $amount,
            'status' => FinancialTransaction::STATUS_PENDING,
            'description' => $description,
            'created_by' => $createdByUserId,
            'created_at' => now(),
        ]);
    }

    /**
     * Super Admin approves a pending ADJUSTMENT — only now does it actually
     * touch the balance, recomputed fresh under a row lock (the preview
     * values written at proposal time may be stale by now).
     */
    public function approveAdjustment(FinancialTransaction $adjustment, int $approvedByUserId): FinancialTransaction
    {
        if ($adjustment->transaction_type !== 'ADJUSTMENT' || $adjustment->status !== FinancialTransaction::STATUS_PENDING) {
            throw new RuntimeException('This is not a pending adjustment.');
        }

        $accountClass = $adjustment->account_type === FinancialTransaction::ACCOUNT_COMPANY ? Company::class : Driver::class;

        return DB::transaction(function () use ($adjustment, $accountClass, $approvedByUserId) {
            $locked = $accountClass::lockForUpdate()->findOrFail($adjustment->account_id);

            $balanceBefore = (float) $locked->balance;
            $balanceAfter = $balanceBefore + (float) $adjustment->amount;

            $adjustment->update([
                'balance_before' => $balanceBefore,
                'balance_after' => $balanceAfter,
                'status' => FinancialTransaction::STATUS_POSTED,
                'approved_by' => $approvedByUserId,
                'approved_at' => now(),
            ]);

            $locked->update(['balance' => $balanceAfter]);

            return $adjustment;
        });
    }

    public function rejectAdjustment(FinancialTransaction $adjustment, int $rejectedByUserId): FinancialTransaction
    {
        if ($adjustment->transaction_type !== 'ADJUSTMENT' || $adjustment->status !== FinancialTransaction::STATUS_PENDING) {
            throw new RuntimeException('This is not a pending adjustment.');
        }

        $adjustment->update([
            'status' => FinancialTransaction::STATUS_REJECTED,
            'approved_by' => $rejectedByUserId,
            'approved_at' => now(),
        ]);

        return $adjustment;
    }

    private function accountTypeFor(Model $account): string
    {
        return match (get_class($account)) {
            Company::class => FinancialTransaction::ACCOUNT_COMPANY,
            Driver::class => FinancialTransaction::ACCOUNT_DRIVER,
            default => throw new RuntimeException('Unsupported ledger account type: ' . get_class($account)),
        };
    }
}
