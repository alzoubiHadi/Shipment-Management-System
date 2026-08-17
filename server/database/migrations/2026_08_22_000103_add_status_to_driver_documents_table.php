<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Unified Approvals / document-expiry feature (2026-08-22): a real,
     * stored lifecycle status per document row — 'valid', 'expiring_soon',
     * 'expired', 'under_review', 'rejected', 'superseded' — instead of
     * deriving these purely from is_current + expiry_date at read time.
     * A renewal upload now creates its new row IMMEDIATELY as
     * 'under_review' (is_current stays false until an admin approves it,
     * so the OLD row keeps counting for eligibility/matching while the
     * renewal is pending — see DriverController::uploadDocument() and
     * ProfileController::applyDocument()).
     *
     * Backfill: every existing is_current=true row becomes 'valid'/
     * 'expiring_soon'/'expired' based on today's date vs expiry_date (a
     * null expiry_date — 'other'/'driver_photo' types mostly — is just
     * 'valid', there's nothing to expire); every existing is_current=false
     * row becomes 'superseded' (we can't know in hindsight whether it was
     * replaced before or after it actually expired, and 'superseded' is a
     * reasonable default either way for historical rows).
     */
    public function up(): void
    {
        Schema::table('driver_documents', function (Blueprint $table) {
            $table->string('status')->default('valid')->after('is_current');
            $table->index('status');
        });

        $today = now()->toDateString();
        $expiringSoonCutoff = now()->addDays(30)->toDateString();

        DB::table('driver_documents')->where('is_current', false)->update(['status' => 'superseded']);

        DB::table('driver_documents')
            ->where('is_current', true)
            ->whereNotNull('expiry_date')
            ->where('expiry_date', '<', $today)
            ->update(['status' => 'expired']);

        DB::table('driver_documents')
            ->where('is_current', true)
            ->whereNotNull('expiry_date')
            ->where('expiry_date', '>=', $today)
            ->where('expiry_date', '<=', $expiringSoonCutoff)
            ->update(['status' => 'expiring_soon']);
    }

    public function down(): void
    {
        Schema::table('driver_documents', function (Blueprint $table) {
            $table->dropIndex(['status']);
            $table->dropColumn('status');
        });
    }
};
