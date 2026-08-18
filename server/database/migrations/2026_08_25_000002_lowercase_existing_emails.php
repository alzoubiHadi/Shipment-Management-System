<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Case-insensitivity fix (2026-08-25): User::setEmailAttribute() and
 * Company::setEmailAttribute() now lowercase every future write, but that
 * alone doesn't fix rows already sitting in the database with mixed-case
 * emails — a user who registered as "Name@Example.com" before this fix
 * would still be unable to log in typing "name@example.com" (which the
 * login/verify-otp/resend-otp endpoints now normalize to lowercase before
 * comparing) unless the stored row is backfilled too.
 */
return new class extends Migration
{
    public function up(): void
    {
        // users.email has a real DB-level UNIQUE constraint (see
        // 0001_01_01_000000_create_users_table.php). If two existing rows
        // ever differ only by case (e.g. a bug or manual DB edit before
        // this fix existed), blindly lowercasing both would collide and
        // fail this whole migration. Guard against that: skip rows
        // involved in such a collision and log them for a human to
        // resolve by hand, instead of crashing the deploy.
        $duplicateEmails = collect(DB::select(
            'SELECT LOWER(email) AS lower_email FROM users GROUP BY LOWER(email) HAVING COUNT(*) > 1'
        ))->pluck('lower_email');

        if ($duplicateEmails->isNotEmpty()) {
            Log::warning(
                'Skipping email-lowercase backfill for users rows that would collide — resolve manually.',
                ['emails' => $duplicateEmails->all()]
            );

            DB::table('users')
                ->whereRaw('LOWER(email) NOT IN (' . implode(',', array_fill(0, $duplicateEmails->count(), '?')) . ')', $duplicateEmails->all())
                ->update(['email' => DB::raw('LOWER(email)')]);
        } else {
            DB::table('users')->update(['email' => DB::raw('LOWER(email)')]);
        }

        // companies.email is only indexed, not unique at the DB level (see
        // 2026_03_03_073331_create_companies_table.php), so no collision
        // guard is needed here.
        DB::table('companies')->whereNotNull('email')->update(['email' => DB::raw('LOWER(email)')]);
    }

    public function down(): void
    {
        // Lowercasing is not reversible (the original casing is gone) —
        // nothing meaningful to roll back to.
    }
};
