<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Unified Approvals / document-expiry feature (2026-08-22): a 5th
     * compliance_status value, 'action_required' — distinct from the
     * existing misconduct-driven values ('warning', 'suspended', 'banned',
     * set only by ComplianceReport resolution / DriverController::suspend()).
     * 'action_required' is set ONLY by Driver::recomputeComplianceStatus()
     * when a critical document (license/passport/residency, or the
     * driver's linked truck's license/insurance/technical inspection) is
     * expired. approval_status is left untouched — the driver stays
     * 'approved', can still log in and see their own account, but
     * MatchingService::eligibleDriversQuery() already excludes anyone
     * whose compliance_status !== 'active', so this alone blocks new job
     * matching without any separate "job_eligibility" column.
     *
     * Same widen-a-Postgres-CHECK-constraint approach as
     * 2026_08_19_000112_add_changes_required_to_approval_status.php — see
     * that migration's docblock for why this looks the constraint name up
     * dynamically instead of assuming the default naming convention.
     */
    public function up(): void
    {
        // 2026-08-27 (test suite fix): see 2026_08_19_000112's docblock —
        // same Postgres-only DO $$ block, same SQLite guard needed so the
        // in-memory test database (phpunit.xml) can run this migration.
        if (DB::connection()->getDriverName() !== 'pgsql') {
            Schema::table('drivers', function (Blueprint $blueprint) {
                $blueprint->enum('compliance_status', ['active', 'warning', 'suspended', 'banned', 'action_required'])
                    ->default('active')
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
                WHERE tc.table_name = 'drivers'
                    AND tc.constraint_type = 'CHECK'
                    AND cc.check_clause LIKE '%compliance_status%'
                LIMIT 1;

                IF cname IS NOT NULL THEN
                    EXECUTE 'ALTER TABLE drivers DROP CONSTRAINT ' || quote_ident(cname);
                END IF;
            END \$\$;
        SQL);

        DB::statement(
            "ALTER TABLE drivers ADD CONSTRAINT drivers_compliance_status_check " .
            "CHECK (compliance_status IN ('active', 'warning', 'suspended', 'banned', 'action_required'))"
        );
    }

    public function down(): void
    {
        // Deliberately a no-op — see 2026_08_19_000112's docblock for the
        // same reasoning: narrowing back would fail outright with any row
        // already 'action_required', and this is a shipped decision, not a
        // schema mistake to revert.
    }
};
