<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * New-registration-design batch (2026-08-19): a 4th approval_status
     * value, 'changes_required' — distinct from 'rejected' (permanently
     * terminal) and from 'pending' (never yet reviewed). An admin uses it
     * to send a driver/company's application back with specific feedback;
     * the owner can then edit their own registration data directly (see
     * DriverController::updateDriverInfo()/CompanyController::
     * updateCompanyInfo(), and the document/destination upload endpoints,
     * all newly gated to skip the ProfileEditRequest approval queue while
     * status is 'changes_required' since resubmission itself triggers a
     * fresh admin review) and resubmit, which flips the status back to
     * 'pending'.
     *
     * `enum()` on Postgres compiles to a CHECK constraint, not a native pg
     * enum type, so widening the allowed values means dropping and
     * re-adding that constraint. There's no PHP/artisan runtime available
     * in this environment to introspect the exact auto-generated
     * constraint name ahead of time, so this looks it up dynamically via
     * information_schema rather than hardcoding a guessed name — safer
     * than assuming Laravel's default "{table}_{column}_check" convention
     * held exactly as expected.
     */
    public function up(): void
    {
        $this->widen('drivers');
        $this->widen('companies');
    }

    public function down(): void
    {
        // Deliberately a no-op: narrowing back to 3 values would fail
        // outright if any row is currently 'changes_required', and this
        // feature is meant to stay: down() migrations are for schema
        // mistakes, not for reverting a shipped product decision.
    }

    private function widen(string $table): void
    {
        // 2026-08-27 (test suite fix): the raw PL/pgSQL block below is
        // Postgres-only syntax. The automated test suite runs against an
        // in-memory SQLite database (see phpunit.xml's DB_CONNECTION
        // override), which doesn't understand "DO $$ ... END $$;" at
        // all — every RefreshDatabase-based feature test was failing at
        // migration time with "near DO: syntax error" before this guard
        // existed (first actually run 2026-08-27; this migration predates
        // that). Laravel 11+ can rebuild a SQLite table's CHECK
        // constraint natively via change(), no doctrine/dbal required —
        // production (Postgres/Neon) keeps using the exact block that
        // was already verified working there.
        if (DB::connection()->getDriverName() !== 'pgsql') {
            Schema::table($table, function (Blueprint $blueprint) {
                $blueprint->enum('approval_status', ['pending', 'approved', 'rejected', 'changes_required'])
                    ->default('approved')
                    ->change();
            });

            return;
        }

        DB::statement(<<<SQL
            DO \$\$
            DECLARE
                cname text;
            BEGIN
                SELECT tc.constraint_name INTO cname
                FROM information_schema.table_constraints tc
                JOIN information_schema.check_constraints cc
                    ON tc.constraint_name = cc.constraint_name
                WHERE tc.table_name = '{$table}'
                    AND tc.constraint_type = 'CHECK'
                    AND cc.check_clause LIKE '%approval_status%'
                LIMIT 1;

                IF cname IS NOT NULL THEN
                    EXECUTE 'ALTER TABLE {$table} DROP CONSTRAINT ' || quote_ident(cname);
                END IF;
            END \$\$;
        SQL);

        DB::statement(
            "ALTER TABLE {$table} ADD CONSTRAINT {$table}_approval_status_check " .
            "CHECK (approval_status IN ('pending', 'approved', 'rejected', 'changes_required'))"
        );
    }
};
