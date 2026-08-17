<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Financial audit (2026-08-25) — defense-in-depth against the double-credit
 * / double-debit races fixed the same day in LedgerService, PayoutRequestController,
 * and ShipmentController (row-lock + re-check the status before writing).
 *
 * Those app-level fixes are what actually close the races. This index is a
 * second, independent guarantee at the database level: for any transaction
 * type that is meant to happen at most ONCE for a given business record
 * (a payout confirmed, a delivery paid out, a top-up approved, ...), the
 * database itself now physically refuses a second FinancialTransaction row
 * with the same (transaction_type, reference_type, reference_id) — even if
 * a future code change accidentally reintroduces a race, or two app server
 * instances somehow race past the row lock. ADJUSTMENT rows have no
 * reference_id (they reference themselves, locked directly by id in
 * LedgerService), so they're naturally excluded by the WHERE clause below.
 *
 * Uses a raw partial unique index (Postgres — this project's DB) since
 * Laravel's schema builder has no first-class support for a WHERE clause
 * on a unique index.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::statement(
            'CREATE UNIQUE INDEX financial_transactions_type_reference_unique ' .
            'ON financial_transactions (transaction_type, reference_type, reference_id) ' .
            'WHERE reference_id IS NOT NULL'
        );
    }

    public function down(): void
    {
        DB::statement('DROP INDEX IF EXISTS financial_transactions_type_reference_unique');
    }
};
