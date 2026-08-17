<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Compliance/Approval separation feature (2026-08-23): two changes to
     * driver_documents/truck_documents/company_documents, applied
     * identically to all three tables.
     *
     * 1. Rename the two renewal-pipeline status values to match the
     *    literal lifecycle now specified: 'under_review' -> 'pending_review',
     *    'rejected' -> 'changes_required'. ('valid'/'expiring_soon'/
     *    'expired'/'superseded' are unchanged.) These are plain string
     *    columns with no CHECK constraint (see 2026_08_22_000103's
     *    docblock), so this is a pure data UPDATE, no constraint surgery.
     *
     * 2. Add a nullable previous_document_id (self-referencing, no FK
     *    constraint — these are append-only history tables and a hard FK
     *    would complicate the "never delete a row" convention) populated at
     *    submission time by the upload endpoints, so the admin review
     *    screen's "old vs new" pairing is an explicit stored link instead
     *    of the previous heuristic re-query (adminIndex()'s
     *    findOldDocumentFor(), still kept as a fallback for any
     *    pre-migration row where this is null).
     */
    public function up(): void
    {
        foreach (['driver_documents', 'truck_documents', 'company_documents'] as $table) {
            DB::table($table)->where('status', 'under_review')->update(['status' => 'pending_review']);
            DB::table($table)->where('status', 'rejected')->update(['status' => 'changes_required']);

            Schema::table($table, function (Blueprint $t) {
                $t->unsignedBigInteger('previous_document_id')->nullable()->after('is_current');
            });
        }
    }

    public function down(): void
    {
        foreach (['driver_documents', 'truck_documents', 'company_documents'] as $table) {
            Schema::table($table, function (Blueprint $t) {
                $t->dropColumn('previous_document_id');
            });

            DB::table($table)->where('status', 'pending_review')->update(['status' => 'under_review']);
            DB::table($table)->where('status', 'changes_required')->update(['status' => 'rejected']);
        }
    }
};
