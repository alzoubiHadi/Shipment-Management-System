<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Admin Shipments redesign (2026-08-24): the Cancellation Report screen
     * needs "who cancelled" and "exactly when", not just the free-text
     * cancellation_reason that already existed. Mirrors the existing
     * company_confirmed_by_user_id/company_confirmed_at pattern on
     * shipments (2026_08_15_000110). Nullable on both — a cancellation
     * triggered by an automated process (e.g. no eligible driver found)
     * legitimately has no acting user.
     */
    public function up(): void
    {
        Schema::table('shipments', function (Blueprint $table) {
            $table->foreignId('cancelled_by_user_id')->nullable()->constrained('users')->nullOnDelete()->after('cancellation_reason');
            $table->timestamp('cancelled_at')->nullable()->after('cancelled_by_user_id');
        });

        Schema::table('shipment_offers', function (Blueprint $table) {
            $table->foreignId('cancelled_by_user_id')->nullable()->constrained('users')->nullOnDelete()->after('cancellation_reason');
            $table->timestamp('cancelled_at')->nullable()->after('cancelled_by_user_id');
        });
    }

    public function down(): void
    {
        Schema::table('shipments', function (Blueprint $table) {
            $table->dropConstrainedForeignId('cancelled_by_user_id');
            $table->dropColumn('cancelled_at');
        });

        Schema::table('shipment_offers', function (Blueprint $table) {
            $table->dropConstrainedForeignId('cancelled_by_user_id');
            $table->dropColumn('cancelled_at');
        });
    }
};
