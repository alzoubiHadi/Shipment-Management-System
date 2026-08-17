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

            // Money math fix (2026-08-25, financial audit): balances are
            // decimal(14,2) in the database, and 'balance' already casts to
            // a decimal:2 STRING on the model for exactly this reason — a
            // PHP float is an IEEE 754 binary double and cannot represent
            // every 2-decimal amount exactly, and every DRIVER_EARNING/
            // SHIPMENT_CHARGE/etc this account ever receives keeps adding
            // onto the same running balance, so any per-entry epsilon error
            // would compound over the account's lifetime. bcadd() does the
            // addition as exact string decimal arithmetic instead.
            $balanceBeforeStr = (string) $locked->balance;
            $amountStr = number_format($amount, 2, '.', '');
            $balanceAfterStr = bcadd($balanceBeforeStr, $amountStr, 2);

            // Drivers can never go negative — a payout can only ever be for
            // an amount already validated against their available balance,
            // so hitting this means a race condition slipped through.
            if ($accountType === FinancialTransaction::ACCOUNT_DRIVER && bccomp($balanceAfterStr, '-0.01', 2) < 0) {
                throw new RuntimeException('This would take the driver balance negative — aborting.');
            }

            $transaction = FinancialTransaction::create([
                'account_type' => $accountType,
                'account_id' => $locked->id,
                'transaction_type' => $type,
                'amount' => $amountStr,
                'currency' => 'AED',
                'balance_before' => $balanceBeforeStr,
                'balance_after' => $balanceAfterStr,
                'reference_type' => $reference ? class_basename($reference) : null,
                'reference_id' => $reference?->id,
                'status' => FinancialTransaction::STATUS_POSTED,
                'description' => $description,
                'created_by' => $createdByUserId ?? auth()->id(),
                'created_at' => now(),
            ]);

            $locked->update(['balance' => $balanceAfterStr]);

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
        $balanceBeforeStr = (string) $account->balance;
        $amountStr = number_format($amount, 2, '.', '');

        return FinancialTransaction::create([
            'account_type' => $accountType,
            'account_id' => $account->id,
            'transaction_type' => 'ADJUSTMENT',
            'amount' => $amountStr,
            'currency' => 'AED',
            // Provisional preview only — recomputed for real at approval
            // time in case other transactions land on this account first.
            'balance_before' => $balanceBeforeStr,
            'balance_after' => bcadd($balanceBeforeStr, $amountStr, 2),
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
     *
     * Concurrency fix (2026-08-25, financial audit): the pending/status
     * check used to run BEFORE the transaction opened, against a possibly
     * stale in-memory $adjustment. Two Super Admin clicks (or two concurrent
     * requests) could both read status=='pending', both pass the check, and
     * both then apply +amount to the balance for what the Ledger shows as a
     * single adjustment row — a real double-credit with no matching audit
     * trail. The fix: lock the FinancialTransaction row itself FIRST, and
     * only re-check its status once that lock is held. The two calls now
     * serialize on this lock; the second one to get it sees status=='posted'
     * already and aborts cleanly instead of re-applying the amount.
     */
    public function approveAdjustment(FinancialTransaction $adjustment, int $approvedByUserId): FinancialTransaction
    {
        return DB::transaction(function () use ($adjustment, $approvedByUserId) {
            $lockedAdjustment = FinancialTransaction::where('id', $adjustment->id)->lockForUpdate()->firstOrFail();

            if ($lockedAdjustment->transaction_type !== 'ADJUSTMENT' || $lockedAdjustment->status !== FinancialTransaction::STATUS_PENDING) {
                throw new RuntimeException('This is not a pending adjustment.');
            }

            $accountClass = $lockedAdjustment->account_type === FinancialTransaction::ACCOUNT_COMPANY ? Company::class : Driver::class;
            $lockedAccount = $accountClass::lockForUpdate()->findOrFail($lockedAdjustment->account_id);

            // Exact string decimal arithmetic — see the note in record()
            // above for why plain float + is unsafe here.
            $balanceBeforeStr = (string) $lockedAccount->balance;
            $balanceAfterStr = bcadd($balanceBeforeStr, (string) $lockedAdjustment->amount, 2);

            $lockedAdjustment->update([
                'balance_before' => $balanceBeforeStr,
                'balance_after' => $balanceAfterStr,
                'status' => FinancialTransaction::STATUS_POSTED,
                'approved_by' => $approvedByUserId,
                'approved_at' => now(),
            ]);

            $lockedAccount->update(['balance' => $balanceAfterStr]);

            return $lockedAdjustment;
        });
    }

    /**
     * Same lock-then-recheck pattern as approveAdjustment() above — a
     * concurrent reject doesn't move money, but without the lock it could
     * silently overwrite approved_by/approved_at set by a reject or approve
     * that already ran, corrupting the audit trail of who actually decided.
     */
    public function rejectAdjustment(FinancialTransaction $adjustment, int $rejectedByUserId): FinancialTransaction
    {
        return DB::transaction(function () use ($adjustment, $rejectedByUserId) {
            $lockedAdjustment = FinancialTransaction::where('id', $adjustment->id)->lockForUpdate()->firstOrFail();

            if ($lockedAdjustment->transaction_type !== 'ADJUSTMENT' || $lockedAdjustment->status !== FinancialTransaction::STATUS_PENDING) {
                throw new RuntimeException('This is not a pending adjustment.');
            }

            $lockedAdjustment->update([
                'status' => FinancialTransaction::STATUS_REJECTED,
                'approved_by' => $rejectedByUserId,
                'approved_at' => now(),
            ]);

            return $lockedAdjustment;
        });
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
