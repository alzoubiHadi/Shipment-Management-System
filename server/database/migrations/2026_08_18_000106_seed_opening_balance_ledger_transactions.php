<?php

use App\Models\Company;
use App\Models\Driver;
use App\Models\FinancialTransaction;
use Illuminate\Database\Migrations\Migration;

return new class extends Migration
{
    /**
     * One-time data migration: the Ledger (financial_transactions) starts
     * empty even though companies/drivers already have real balances from
     * before this system existed (top-ups approved, shipments delivered,
     * payouts confirmed — all done via raw increment/decrement with no
     * Ledger row). This writes one OPENING_BALANCE entry per non-zero
     * account so the Ledger becomes a consistent starting point going
     * forward, WITHOUT changing any actual balance — balance_before is set
     * to 0 and balance_after to the current balance, purely as a
     * historical marker.
     *
     * Safe to run more than once: it only inserts a row for an account
     * that doesn't already have an OPENING_BALANCE entry.
     */
    public function up(): void
    {
        $now = now();

        Company::query()->where('balance', '<>', 0)->each(function (Company $company) use ($now) {
            $exists = FinancialTransaction::where('account_type', 'company')
                ->where('account_id', $company->id)
                ->where('transaction_type', 'OPENING_BALANCE')
                ->exists();

            if ($exists) {
                return;
            }

            FinancialTransaction::create([
                'account_type' => 'company',
                'account_id' => $company->id,
                'transaction_type' => 'OPENING_BALANCE',
                'amount' => $company->balance,
                'currency' => 'AED',
                'balance_before' => 0,
                'balance_after' => $company->balance,
                'status' => 'posted',
                'description' => 'Opening balance recorded at Ledger system launch',
                'created_at' => $now,
            ]);
        });

        Driver::query()->where('balance', '<>', 0)->each(function (Driver $driver) use ($now) {
            $exists = FinancialTransaction::where('account_type', 'driver')
                ->where('account_id', $driver->id)
                ->where('transaction_type', 'OPENING_BALANCE')
                ->exists();

            if ($exists) {
                return;
            }

            FinancialTransaction::create([
                'account_type' => 'driver',
                'account_id' => $driver->id,
                'transaction_type' => 'OPENING_BALANCE',
                'amount' => $driver->balance,
                'currency' => 'AED',
                'balance_before' => 0,
                'balance_after' => $driver->balance,
                'status' => 'posted',
                'description' => 'Opening balance recorded at Ledger system launch',
                'created_at' => $now,
            ]);
        });
    }

    public function down(): void
    {
        FinancialTransaction::where('transaction_type', 'OPENING_BALANCE')->delete();
    }
};
