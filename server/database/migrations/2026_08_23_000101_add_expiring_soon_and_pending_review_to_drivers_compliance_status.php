<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Compliance/Approval separation feature (2026-08-23): compliance_status
     * grows two more values — 'expiring_soon' and 'pending_review' — on top
     * of the existing 'active'/'warning'/'suspended'/'banned'/'action_required'.
     * These two are set/cleared exclusively by ComplianceService::recalculate()
     * (see app/Services/ComplianceService.php); approval_status is never
     * touched by any of this, per the explicit requirement that Account
     * Approval and Compliance are fully independent axes.
     *
     * Same widen-a-Postgres-CHECK-constraint approach as
     * 2026_08_22_000101_add_action_required_to_drivers_compliance_status.php.
     */
    public function up(): void
    {
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
            "CHECK (compliance_status IN ('active', 'warning', 'suspended', 'banned', 'action_required', 'expiring_soon', 'pending_review'))"
        );
    }

    public function down(): void
    {
        // Deliberately a no-op — same reasoning as the migrations this one
        // follows: narrowing back would fail outright with any row already
        // 'expiring_soon'/'pending_review', and this is a shipped decision,
        // not a schema mistake to revert.
    }
};
